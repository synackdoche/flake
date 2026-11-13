{
  pkgs,
  inputs,
  ...
}:
let
  docs = inputs.self.lib.internal.docsApp { inherit pkgs; };
in
docs
// {
  meta = (docs.meta or { }) // {
    mainProgram = "docs";
  };
}
