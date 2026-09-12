{runCommandLocal}:
runCommandLocal "facet-nested" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
