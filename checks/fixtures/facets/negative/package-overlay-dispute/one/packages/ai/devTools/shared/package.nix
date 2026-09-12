{runCommandLocal}:
runCommandLocal "facet-shared" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
