{runCommandLocal}:
runCommandLocal "facet-reserved" {} ''
  mkdir -p "$out"
  touch "$out/passed"
''
