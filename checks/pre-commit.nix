{
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  enabled = lib.attrNames (lib.filterAttrs (_name: hook: hook.enable or false) hookSet.config.hooks);
  hookSet = inputs.self.lib.preCommit {
    inherit pkgs;
    extraHooks.integration = {
      enable = true;
      entry = "${integrationHook}";
      language = "system";
      name = "docs-integration";
      pass_filenames = false;
    };
    src = ../.;
  };
  integrationHook = pkgs.writeShellScript "docs-integration-hook" ''
    export LANG=''${LANG:-C.UTF-8}
    if [ ! -S /nix/var/nix/daemon-socket/socket ] || ! ${lib.getExe' pkgs.util-linux "unshare"} --user --map-root-user true 2> /dev/null; then
      echo "docs-integration: no nix daemon socket or no user namespaces here, skipping the jail suite"
      exit 0
    fi
    exec ${lib.getExe inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.docs-integration}
  '';
in
assert lib.assertMsg
  (
    enabled == [
      "docs"
      "integration"
      "treefmt"
    ]
  )
  "the hook set is the formatter, the documentation check and the jailed integration suite, got: ${lib.concatStringsSep ", " enabled}";
assert lib.assertMsg (
  hookSet.config.hooks.treefmt.enable && hookSet.config.hooks.docs.enable
) "the formatter and the documentation check run on every commit";
assert lib.assertMsg hookSet.config.hooks.integration.enable
  "the jailed integration suite runs on every commit, and reports when it cannot run";
hookSet
