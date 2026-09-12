{runCommandLocal}:
runCommandLocal "facet-ancestor" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
