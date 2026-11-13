{
  pkgs,
  inputs,
}:
{
  inherit pkgs;
  description = inputs.self.title;
  formatter = inputs.self.formatter.x86_64-linux;
  internalLibrary = inputs.self.lib.internal;
  library = { };
  name = "flake";
  packages = inputs.self.packages.x86_64-linux;
  root = ./.;
  system = "x86_64-linux";
}
