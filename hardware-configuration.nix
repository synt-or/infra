{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "usb_storage" "sdhci_pci" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.initrd.systemd.enable = true;

  boot.initrd.luks.devices."nixos-crypt" = {
    device = "/dev/disk/by-uuid/fcdb2782-1687-4027-b633-37d9757c1738";
  };

  fileSystems."/" =
    { device = "/dev/mapper/nixos--vg-rootfs";
      fsType = "ext4";
    };

  fileSystems."/data" =
    { device = "/dev/mapper/nixos--vg-data";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-partuuid/24d48474-2a34-451f-813a-105ed62ad249";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}