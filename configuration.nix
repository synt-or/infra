{ config, lib, pkgs, ... }:

{
  imports =
    [ ./hardware-configuration.nix
    ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # Clavier Mac ISO français
  boot.extraModprobeConfig = "options hid_apple iso_layout=1";
  console.keyMap = "mac-fr";

  # Hostname
  networking.hostName = "nixos";

  # WiFi — iwd avec DHCP intégré
  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };

  # Timezone et locale
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";

  # Pas de swap
  swapDevices = [ ];

  # Paquets
  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  # SSH serveur
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Git config globale déclarative
  programs.git = {
    enable = true;
    config = {
      user.name = "synt-or";
      user.email = "syntor@protonmail.com";
      gpg.format = "ssh";
      commit.gpgsign = true;
      init.defaultBranch = "main";
    };
  };

  # Utilisateur
  users.users.lambda = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBI/eFj3EA31vrOmiTQ0euOP2IjjdL+3YyWMT51ZJE3LqO0P0eiqrKQtIcQQ7Nm+wvI0JBQqMexkrNTOZ6UChGPE="
    ];
  };

  # Firmware Asahi
  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  system.stateVersion = "26.05";
}
