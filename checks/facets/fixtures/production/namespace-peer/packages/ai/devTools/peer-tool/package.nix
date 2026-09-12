{runCommandLocal}:
runCommandLocal "facet-peer" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
