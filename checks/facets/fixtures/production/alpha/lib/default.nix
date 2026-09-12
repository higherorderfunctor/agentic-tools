{
  inputs,
  lib,
  ...
}: {
  ai = {
    callableControl = {
      __functor = _: value: "called:${value}";
      hidden = throw "callable internals must stay lazy";
    };
    mkControl = {
      optional ? "default",
      required,
    }: "${inputs.fixture.sentinel}:${required}:${optional}";
    optionControl = lib.mkOption {type = lib.types.str;};
    typeControl = lib.types.submodule {
      options.required = lib.mkOption {type = lib.types.str;};
    };
  };
}
