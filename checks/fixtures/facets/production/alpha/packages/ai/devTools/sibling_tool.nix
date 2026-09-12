{runCommandLocal}:
runCommandLocal "facet-sibling" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
