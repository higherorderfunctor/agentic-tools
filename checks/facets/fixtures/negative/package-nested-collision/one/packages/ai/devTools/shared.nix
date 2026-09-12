{runCommandLocal}:
runCommandLocal "facet-one" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
