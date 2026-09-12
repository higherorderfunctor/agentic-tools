{runCommandLocal}:
runCommandLocal "facet-two" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
