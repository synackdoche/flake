{ lib, config, ... }:
{
  config = lib.mkIf config.wired.enable {
    systemd.services.wired = {
      serviceConfig.ExecStart = lib.escapeShellArgs (
        [ "wired" ] ++ map toString config.wired.certificates
      );
      wantedBy = [ "multi-user.target" ];
    };
  };
  meta = {
    description = "Runs a unit from the certificate list the NixOS module system provides.";
    example.wired.enable = true;
  };
  options.wired = {
    certificates = lib.mkOption {
      default = config.security.pki.certificateFiles;
      defaultText = lib.literalExpression "config.security.pki.certificateFiles";
      description = "Certificates the unit starts with, defaulted from the NixOS option that owns them.";
      type = lib.types.listOf lib.types.path;
    };
    enable = lib.mkEnableOption "the wired unit";
  };
}
