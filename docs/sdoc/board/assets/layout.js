export const CARD = Object.freeze({ width: 244, height: 102 });

const DEFAULTS = Object.freeze({
  card: CARD,
  depth: 1,
  margin: 60,
  maxNodes: 48,
  mergeThreshold: 3,
});
const ELK_API_URL = new URL("./vendor/elkjs/elk-api.js", import.meta.url).href;
const ELK_WORKER_URL = new URL(
  "./vendor/elkjs/elk-worker.min.js",
  import.meta.url,
).href;

let elkPromise;

async function elkEngine() {
  if (!elkPromise) {
    elkPromise = import(ELK_API_URL).then(() => {
      if (typeof globalThis.ELK !== "function") {
        throw new Error("the vendored ELK API did not register itself");
      }
      return new globalThis.ELK({ workerUrl: ELK_WORKER_URL });
    });
  }
  return elkPromise;
}

function neighborhoodRanks(centerId, incoming, outgoing, depth) {
  const distances = new Map([[centerId, 0]]);
  const ranks = new Map([[centerId, 0]]);
  let leftCount = 0;
  let rightCount = 0;
  let frontier = [centerId];

  for (let distance = 1; distance <= depth && frontier.length; distance += 1) {
    const candidates = new Map();
    for (const id of frontier) {
      const neighbors = new Set([
        ...(incoming.get(id) ?? []),
        ...(outgoing.get(id) ?? []),
      ]);
      for (const neighbor of [...neighbors].sort()) {
        if (neighbor === centerId) continue;
        const knownDistance = distances.get(neighbor);
        if (knownDistance !== undefined && knownDistance < distance) continue;
        if (knownDistance === undefined) distances.set(neighbor, distance);
        if (distances.get(neighbor) !== distance) continue;
        const sides = candidates.get(neighbor) ?? new Set();
        if (id === centerId) {
          if (incoming.get(centerId)?.includes(neighbor)) sides.add(-1);
          if (outgoing.get(centerId)?.includes(neighbor)) sides.add(1);
        } else {
          sides.add(Math.sign(ranks.get(id)) || 1);
        }
        candidates.set(neighbor, sides);
      }
    }

    frontier = [...candidates.keys()].sort();
    for (const id of frontier) {
      const sides = candidates.get(id);
      let side;
      if (sides.size === 1) side = [...sides][0];
      else side = rightCount <= leftCount ? 1 : -1;
      ranks.set(id, side * distance);
      if (side < 0) leftCount += 1;
      else rightCount += 1;
    }
  }
  return ranks;
}

function selectNeighborhood(snapshot, centerId, depth, maxNodes) {
  const allNodes = new Map(snapshot.nodes.map((node) => [node.id, node]));
  if (!allNodes.has(centerId)) {
    return {
      nodes: [],
      edges: [],
      ranks: new Map(),
      clipped: 0,
      totalNodes: 0,
    };
  }

  const ids = [...allNodes.keys()].sort();
  const incoming = new Map(ids.map((id) => [id, []]));
  const outgoing = new Map(ids.map((id) => [id, []]));
  const validEdges = snapshot.edges.filter(
    (edge) => allNodes.has(edge.source) && allNodes.has(edge.target),
  );
  for (const edge of validEdges) {
    if (edge.source === edge.target) continue;
    incoming.get(edge.target).push(edge.source);
    outgoing.get(edge.source).push(edge.target);
  }
  for (const neighbors of [...incoming.values(), ...outgoing.values()]) {
    neighbors.sort();
  }

  const ranks = neighborhoodRanks(centerId, incoming, outgoing, depth);
  const neighborhoodIds = new Set(ranks.keys());
  const candidates = snapshot.nodes.filter((node) =>
    neighborhoodIds.has(node.id),
  );
  const totalNodes = candidates.length;
  const nodes =
    candidates.length <= maxNodes
      ? candidates
      : candidates
          .map((node) => ({
            id: node.id,
            node,
            rank: ranks.get(node.id) ?? 0,
          }))
          .sort(
            (left, right) =>
              Number(right.id === centerId) - Number(left.id === centerId) ||
              Math.abs(left.rank) - Math.abs(right.rank) ||
              Number(right.rank > 0) - Number(left.rank > 0) ||
              left.node.title.localeCompare(right.node.title) ||
              left.id.localeCompare(right.id),
          )
          .slice(0, maxNodes)
          .map(({ node }) => node);
  const keptIds = new Set(nodes.map((node) => node.id));
  const edges = validEdges.filter(
    (edge) => keptIds.has(edge.source) && keptIds.has(edge.target),
  );
  return {
    nodes,
    edges,
    ranks,
    clipped: totalNodes - nodes.length,
    totalNodes,
  };
}

function roleOf(edge) {
  return edge.role || edge.type || "Relation";
}

function groupedEdges(edges, minimumSize) {
  const records = edges.map((edge, index) => ({
    edge,
    key: edge.id || `semantic-${index}`,
  }));
  const assigned = new Set();
  const groups = [];

  function collect(direction) {
    const candidates = new Map();
    for (const record of records) {
      if (assigned.has(record.key) || record.edge.source === record.edge.target)
        continue;
      const endpoint =
        direction === "outgoing" ? record.edge.source : record.edge.target;
      const other =
        direction === "outgoing" ? record.edge.target : record.edge.source;
      const key = `${endpoint}\u0000${roleOf(record.edge)}`;
      const group = candidates.get(key) ?? {
        direction,
        endpoint,
        others: new Set(),
        records: [],
        role: roleOf(record.edge),
      };
      group.others.add(other);
      group.records.push(record);
      candidates.set(key, group);
    }
    for (const group of [...candidates.values()].sort(
      (left, right) =>
        left.endpoint.localeCompare(right.endpoint) ||
        left.role.localeCompare(right.role),
    )) {
      if (group.records.length < minimumSize || group.others.size < minimumSize)
        continue;
      for (const record of group.records) assigned.add(record.key);
      groups.push(group);
    }
  }

  // Prefer fan-out groups. An edge is assigned to at most one junction, which
  // keeps the display graph simple and the semantic edge mapping unambiguous.
  collect("outgoing");
  collect("incoming");
  return {
    direct: records.filter((record) => !assigned.has(record.key)),
    groups,
  };
}

function normalizedLabelMeasure(measureLabel, value) {
  const measured = measureLabel?.(value) ?? {};
  const height = Math.max(1, Number(measured.height) || 16);
  return {
    baseline: Number(measured.baseline) || height * 0.78,
    height,
    width: Math.max(1, Number(measured.width) || value.length * 7.5),
  };
}

function elkInput(selection, config) {
  const scale = config.card.width / CARD.width;
  const scaled = (value) => Math.round(value * scale * 100) / 100;
  const { direct, groups } = groupedEdges(
    selection.edges,
    config.mergeThreshold,
  );
  const children = selection.nodes
    .map((node) => ({
      height: config.card.height,
      id: node.id,
      width: config.card.width,
    }))
    .sort((left, right) => left.id.localeCompare(right.id));
  const edges = [];
  const pieces = new Map();
  const labelBaselines = new Map();
  let pieceIndex = 0;
  let labelIndex = 0;

  function addPiece({ records, source, target, label = null, terminal }) {
    const id = `display-edge-${pieceIndex}`;
    pieceIndex += 1;
    const elkEdge = { id, sources: [source], targets: [target] };
    if (label) {
      const dimensions = normalizedLabelMeasure(config.measureLabel, label);
      const labelId = `display-label-${labelIndex}`;
      labelIndex += 1;
      elkEdge.labels = [
        {
          height: dimensions.height,
          id: labelId,
          layoutOptions: { "elk.edgeLabels.placement": "CENTER" },
          text: label,
          width: dimensions.width,
        },
      ];
      labelBaselines.set(labelId, dimensions.baseline);
    }
    edges.push(elkEdge);
    pieces.set(id, { records, terminal });
  }

  for (const record of direct) {
    addPiece({
      label: roleOf(record.edge),
      records: [record],
      source: record.edge.source,
      target: record.edge.target,
      terminal: true,
    });
  }

  groups.forEach((group, groupIndex) => {
    const junctionId = `__elk_role_junction_${groupIndex}`;
    children.push({ height: scaled(1), id: junctionId, width: scaled(1) });
    if (group.direction === "outgoing") {
      addPiece({
        label: group.role,
        records: group.records,
        source: group.endpoint,
        target: junctionId,
        terminal: false,
      });
      for (const record of group.records) {
        addPiece({
          records: [record],
          source: junctionId,
          target: record.edge.target,
          terminal: true,
        });
      }
    } else {
      for (const record of group.records) {
        addPiece({
          records: [record],
          source: record.edge.source,
          target: junctionId,
          terminal: false,
        });
      }
      addPiece({
        label: group.role,
        records: group.records,
        source: junctionId,
        target: group.endpoint,
        terminal: true,
      });
    }
  });

  return {
    graph: {
      children,
      edges,
      id: "bounded-neighborhood",
      layoutOptions: {
        "elk.algorithm": "layered",
        "elk.direction": "RIGHT",
        "elk.edgeRouting": "ORTHOGONAL",
        "elk.layered.considerModelOrder.strategy": "NODES_AND_EDGES",
        "elk.layered.cycleBreaking.strategy": "GREEDY_MODEL_ORDER",
        "elk.layered.edgeLabels.sideSelection": "SMART_DOWN",
        // Role junctions above are the only merge mechanism. ELK's generic
        // merge is not role-aware and could overlay differently styled roles.
        "elk.layered.mergeEdges": "false",
        "elk.layered.spacing.edgeEdgeBetweenLayers": String(scaled(18)),
        "elk.layered.spacing.edgeNodeBetweenLayers": String(scaled(24)),
        "elk.layered.spacing.nodeNodeBetweenLayers": String(scaled(116)),
        "elk.padding": `[top=${scaled(config.margin)},left=${scaled(config.margin)},bottom=${scaled(config.margin)},right=${scaled(config.margin)}]`,
        "elk.randomSeed": "1",
        "elk.spacing.edgeEdge": String(scaled(18)),
        "elk.spacing.edgeLabel": String(scaled(6)),
        "elk.spacing.edgeNode": String(scaled(24)),
        "elk.spacing.labelLabel": String(scaled(14)),
        "elk.spacing.labelNode": String(scaled(20)),
        "elk.spacing.nodeNode": String(scaled(32)),
      },
    },
    labelBaselines,
    pieces,
  };
}

function pointsOf(elkEdge) {
  const points = [];
  for (const section of elkEdge.sections ?? []) {
    const sectionPoints = [
      section.startPoint,
      ...(section.bendPoints ?? []),
      section.endPoint,
    ].filter(Boolean);
    if (
      points.length &&
      sectionPoints.length &&
      points.at(-1).x === sectionPoints[0].x &&
      points.at(-1).y === sectionPoints[0].y
    ) {
      sectionPoints.shift();
    }
    points.push(...sectionPoints);
  }
  return points;
}

function pathOf(points) {
  return points
    .map(({ x, y }, index) => `${index === 0 ? "M" : "L"} ${x} ${y}`)
    .join(" ");
}

function fallbackLabel(points, baseline) {
  let longest = null;
  for (let index = 1; index < points.length; index += 1) {
    const start = points[index - 1];
    const end = points[index];
    if (start.y !== end.y) continue;
    const length = Math.abs(end.x - start.x);
    if (!longest || length > longest.length) longest = { end, length, start };
  }
  if (!longest) return { x: points[0]?.x ?? 0, y: points[0]?.y ?? 0 };
  return {
    x: (longest.start.x + longest.end.x) / 2,
    y: longest.start.y - Math.max(4, baseline / 3),
  };
}

function displayRoutes(output, pieces, labelBaselines, positions, ranks) {
  const routes = [];
  for (const elkEdge of output.edges ?? []) {
    const piece = pieces.get(elkEdge.id);
    if (!piece) continue;
    const points = pointsOf(elkEdge);
    if (points.length < 2) continue;
    const semanticEdges = piece.records.map(({ edge }) => edge);
    const edge = semanticEdges[0];
    const source = positions[edge.source];
    const target = positions[edge.target];
    const elkLabel = elkEdge.labels?.[0];
    const baseline = elkLabel
      ? labelBaselines.get(elkLabel.id) || elkLabel.height * 0.78
      : 0;
    const label = elkLabel
      ? {
          text: elkLabel.text || roleOf(edge),
          x: elkLabel.x + elkLabel.width / 2,
          y: elkLabel.y + baseline,
        }
      : null;
    routes.push({
      d: pathOf(points),
      edge,
      edges: semanticEdges,
      kind:
        edge.source === edge.target
          ? "self"
          : source.x === target.x
            ? "same-rank"
            : source.x < target.x
              ? "forward"
              : "backward",
      label:
        label ||
        (elkEdge.labels?.length ? fallbackLabel(points, baseline) : null),
      points,
      ranks: semanticEdges.map((semantic) => ({
        source: ranks.get(semantic.source) ?? 0,
        target: ranks.get(semantic.target) ?? 0,
      })),
      terminal: piece.terminal,
    });
  }
  return routes;
}

// Selection and clipping are completed synchronously before the bounded graph
// is serialized to ELK. The worker therefore never receives the whole canon.
export async function layoutNeighborhood(snapshot, centerId, options = {}) {
  const config = {
    ...DEFAULTS,
    ...options,
    card: { ...CARD, ...options.card },
    depth: Math.max(1, Math.floor(options.depth ?? DEFAULTS.depth)),
    maxNodes: Math.max(1, Math.floor(options.maxNodes ?? DEFAULTS.maxNodes)),
  };
  const selection = selectNeighborhood(
    snapshot,
    centerId,
    config.depth,
    config.maxNodes,
  );
  if (!selection.nodes.length) {
    return {
      bounds: { height: 0, width: 0, x: 0, y: 0 },
      centerId,
      clipped: 0,
      edges: [],
      nodes: [],
      positions: {},
      routes: [],
      totalNodes: 0,
    };
  }

  const { graph, labelBaselines, pieces } = elkInput(selection, config);
  const engine = await elkEngine();
  const output = await engine.layout(graph);
  const positions = Object.fromEntries(
    output.children
      .filter((node) => !node.id.startsWith("__elk_role_junction_"))
      .map((node) => [
        node.id,
        {
          component: 0,
          rank: selection.ranks.get(node.id) ?? 0,
          x: node.x,
          y: node.y,
        },
      ]),
  );
  return {
    bounds: {
      height: output.height,
      width: output.width,
      x: output.x || 0,
      y: output.y || 0,
    },
    centerId,
    clipped: selection.clipped,
    edges: selection.edges,
    nodes: selection.nodes,
    positions,
    routes: displayRoutes(
      output,
      pieces,
      labelBaselines,
      positions,
      selection.ranks,
    ),
    totalNodes: selection.totalNodes,
  };
}
