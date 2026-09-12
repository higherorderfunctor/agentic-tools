{runCommandLocal}:
runCommandLocal "facet-mcp" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
