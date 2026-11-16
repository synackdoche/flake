{
  pkgs,
  inputs,
  ...
}:
let
  docs = inputs.self.lib.internal.docs.app { inherit pkgs; };
in
docs
// {
  meta = (docs.meta or { }) // {
    mainProgram = "docs";
  };
}
