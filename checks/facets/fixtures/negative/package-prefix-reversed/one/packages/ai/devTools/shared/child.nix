{runCommandLocal}:
runCommandLocal "facet-prefix-child" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
