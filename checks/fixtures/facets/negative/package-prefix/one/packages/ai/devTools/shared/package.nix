{runCommandLocal}:
runCommandLocal "facet-prefix-leaf" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
