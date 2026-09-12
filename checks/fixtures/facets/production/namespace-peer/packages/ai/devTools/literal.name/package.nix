{runCommandLocal}:
runCommandLocal "facet-dotted" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
