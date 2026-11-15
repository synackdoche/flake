{ inputs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };
  imports = [ inputs.self.nixosModules.example ];
  meta.description = "The example host runs the demo stack.";
  networking.hostName = "example";
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "24.05";
}
