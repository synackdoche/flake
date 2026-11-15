{
  description = "Harness that runs the base flake's documentation suites in a bubblewrap jail";
  inputs = {
    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
    nixpkgs.url = "github:synackdoche/nixpkgs/nixos-26.05";
    synackdoche-flake.url = "github:synackdoche/flake";
  };
  outputs =
    {
      jail-nix,
      nixpkgs,
      synackdoche-flake,
      ...
    }:
    let
      jail = jail-nix.lib.init pkgs;
      jailed =
        name:
        jail "docs-integration-${name}" (pkgs.lib.getExe suites.${name}) (
          with jail.combinators;
          [
            network
            (ro-bind "${synackdoche-flake}" "/repo")
            (readonly "/nix/store")
            (try-readonly "/nix/var/nix/daemon-socket")
            (set-env "DOCS_INTEGRATION_SOURCE" "/repo")
            (set-env "NIX_REMOTE" "daemon")
          ]
        );
      pkgs = nixpkgs.legacyPackages.${system};
      suites = import ./docs-integration.nix { inherit pkgs synackdoche-flake; };
      system = "x86_64-linux";
    in
    {
      packages.${system} = {
        all-types = jailed "all-types";
        check-mode = jailed "check-mode";
        gate = jailed "gate";
        meta-dedupe = jailed "meta-dedupe";
        template = jailed "template";
      };
    };
}
