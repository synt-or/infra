{ config, lib, pkgs, ... }:

{
  imports =
    [ ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  boot.extraModprobeConfig = "options hid_apple iso_layout=0";
  console.keyMap = "mac-fr";

  networking.hostName = "nixos";

  networking.wireless.iwd.enable = true;
  networking.wireless.iwd.settings.General.EnableNetworkConfiguration = true;

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";

  swapDevices = [ ];

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.lambda = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBI/eFj3EA31vrOmiTQ0euOP2IjjdL+3YyWMT51ZJE3LqO0P0eiqrKQtIcQQ7Nm+wvI0JBQqMexkrNTOZ6UChGPE="
    ];
  };

  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  system.stateVersion = "26.05";
}