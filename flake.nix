{
  description = ''
    SYNACKDOCHE GAMES - Base Flake

    shared formatter, pre-commit, docgate checks and flake scaffolding
  '';
  inputs = {
    blueprint = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/blueprint";
    };
    git-hooks = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:cachix/git-hooks.nix";
    };
    nixpkgs.url = "github:synackdoche/nixpkgs/nixos-26.05";
    pedantix = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
      };
      url = "github:swarsel/pedantix";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };
  outputs =
    { blueprint, ... }@inputs:
    let
      docsFor =
        system:
        let
          docs = own.lib.internal.docsApp { pkgs = inputs.nixpkgs.legacyPackages.${system}; };
        in
        docs
        // {
          meta = (docs.meta or { }) // {
            mainProgram = "docs";
          };
        };
      formatterFor =
        pkgs:
        import ./formatter.nix {
          inherit pkgs;
          flake.inputs = {
            inherit (inputs) pedantix treefmt-nix;
          };
        };
      lib = inputs.nixpkgs.lib;
      mixin =
        args:
        let
          defaultsFor =
            system:
            let
              existingChecks = generated.checks.${system} or { };
              pkgs = inputs.nixpkgs.legacyPackages.${system};
              preCommit = own.lib.preCommit {
                inherit pkgs;
                src = self.outPath;
              };
            in
            {
              checks.${system} =
                existingChecks
                // lib.optionalAttrs (!(existingChecks ? readme)) {
                  readme = own.lib.readmeGate (
                    own.lib.flakeArgs {
                      inherit pkgs;
                      checks = { };
                      flake = self;
                      root = self.outPath;
                    }
                  );
                }
                // lib.optionalAttrs (!(existingChecks ? "pre-commit")) {
                  pre-commit = preCommit;
                }
                // lib.optionalAttrs (!(existingChecks ? documentation)) {
                  documentation = own.lib.docsGate {
                    inherit pkgs;
                    flake = self;
                    root = self.outPath;
                  };
                };
              devShells.${system}.default =
                (generated.devShells.${system} or { }).default or (own.lib.devShell {
                  inherit pkgs;
                  preCommit = existingChecks.pre-commit or preCommit;
                });
              formatter.${system} = if hasOwnFormatter then generated.formatter.${system} else formatterFor pkgs;
              packages.${system}.docs = (generated.packages.${system} or { }).docs or (docsFor system);
            };
          generated = blueprint args;
          hasOwnFormatter = builtins.pathExists (self.outPath + "/formatter.nix");
          self = args.inputs.self;
        in
        generated // lib.foldl' (acc: system: acc // defaultsFor system) { } (args.systems or [ ]);
      own = blueprint {
        inherit inputs;
        systems = [ "x86_64-linux" ];
      };
    in
    own
    // {
      __functor = _: mixin;
      url = "github:synackdoche/flake";
    };
}
