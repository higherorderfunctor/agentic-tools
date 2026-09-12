{
  ancestor-tool,
  sibling_tool,
  runCommandLocal,
}:
runCommandLocal "facet-alpha-tool" {nativeBuildInputs = [ancestor-tool sibling_tool];} ''
  test -e ${ancestor-tool}/passed
  test -e ${sibling_tool}/passed
  mkdir -p "$out"
  touch "$out/passed"
''
