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
  # Chargement du keymap custom après le keymap de base
  console.keyMap = "mac-fr";
  systemd.services.custom-keymap = {
    description = "Custom Mac FR keymap fixes";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-vconsole-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kbd}/bin/loadkeys -q ${./keymap/mac-fr-custom.map}";
    };
  };


  # Emergency shell accessible dans l'initrd
  boot.initrd.systemd.emergencyAccess = true;

  # Hostname
  networking.hostName = "mac";

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

  # Ajout des fonctionnalités expérimentales pour les commandes nix et les flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Autoriser les paquets unfree (Claude Code)
  nixpkgs.config.allowUnfree = true;

  # Paquets
  environment.systemPackages = with pkgs; [
    git
    vim
    bat
    ripgrep
    fd
  ];

  # Pour permettre la compatibilité avec les binaires compilés FHS
  programs.nix-ld.enable = true; 

  # Variables de session
    # Pour ajouter Claude Code au $PATH
    environment.sessionVariables = {
      PATH = [ "$HOME/.local/bin" ];
      CLAUDE_CODE_TASK_LIST_ID = "infra";
    };


  # SSH serveur
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # SSH client — stub YubiKey sk résidente placé déclarativement (à nixifier)
  system.activationScripts.sshStub = ''
    mkdir -p /home/lambda/.ssh
    cp ${./ssh/id_ed25519_sk_rk} /home/lambda/.ssh/id_ed25519_sk_rk
    cp ${./ssh/id_ed25519_sk_rk.pub} /home/lambda/.ssh/id_ed25519_sk_rk.pub
    chmod 600 /home/lambda/.ssh/id_ed25519_sk_rk
    chmod 644 /home/lambda/.ssh/id_ed25519_sk_rk.pub
    chown -R lambda:users /home/lambda/.ssh
    if ! grep -q 'id_ed25519_sk_rk' /home/lambda/.ssh/config 2>/dev/null; then
      echo 'IdentityFile ~/.ssh/id_ed25519_sk_rk' >> /home/lambda/.ssh/config
      chown lambda:users /home/lambda/.ssh/config
    fi
    if ! grep -q 'AddKeysToAgent' /home/lambda/.ssh/config 2>/dev/null; then
      echo 'AddKeysToAgent yes' >> /home/lambda/.ssh/config
      chown lambda:users /home/lambda/.ssh/config
    fi
  '';

  # Ajout automatique des clés SSH à l'agent au chargement d'un terminal
  programs.bash.interactiveShellInit = ''
    ssh-add -l | grep -q 'id_ed25519_sk_rk' 2>/dev/null || ssh-add ~/.ssh/id_ed25519_sk_rk 2>/dev/null
  '';

  # Ajout de la fonction UndistractMe au terminal
  programs.bash.undistractMe.enable = true;


  # SSH agent
  programs.ssh.startAgent = true;

  # Git config globale déclarative
  programs.git = {
    enable = true;
    config = {
      user.name = "synt-or";
      user.email = "syntor@protonmail.com";
      gpg.format = "ssh";
      user.signingKey = "key::sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIIxIpGAQxp4EFzLAqYrKnjY5BFyYqPGFhLPZ6v907PJ3AAAABHNzaDo= ssh:";
      commit.gpgsign = true;
      init.defaultBranch = "main";
      core.editor = "vim";
      pull.rebase = "false";
    };
  };

  # Utilisateur
  users.users.lambda = {
    isNormalUser = true;
    extraGroups = [ "wheel" "plugdev" ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBI/eFj3EA31vrOmiTQ0euOP2IjjdL+3YyWMT51ZJE3LqO0P0eiqrKQtIcQQ7Nm+wvI0JBQqMexkrNTOZ6UChGPE="
    ];
  };

  # Règles udev pour accès FIDO2 en session non-locale (SSH)
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev", TAG+="uaccess"
  '';
  users.groups.plugdev = {};
  

  # Firmware Asahi
  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  system.stateVersion = "26.05";
}
