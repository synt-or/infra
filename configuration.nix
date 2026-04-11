{ config, lib, pkgs, claude-code, ... }:

{
  imports =
    [ ./hardware-configuration.nix
    ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.consoleLogLevel = 3;

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

  # Hardening — Phase 1
  # Lockdown LSM (désactivé dans nixpkgs upstream pour reproductibilité — MODULE_SIG génère une clé random par build)
  # Pré-builder de nuit : nix build /data/infra#nixosConfigurations.nixos.config.system.build.toplevel
  boot.kernelPatches = [
    {
      name = "enable-lockdown-lsm";
      patch = null;
      extraConfig = ''
        SECURITY_LOCKDOWN_LSM y
        SECURITY_LOCKDOWN_LSM_EARLY y
        MODULE_SIG y
        MODULE_SIG_FORCE y
      '';
    }
  ];
  boot.kernelParams = [ "lockdown=confidentiality" ];
  security.protectKernelImage = true;
  # Charger les modules nécessaires au boot AVANT le lock (modules_disabled=1)
  # Ajouter ici les modules pour Docker/Podman quand ils seront configurés : bridge veth overlay br_netfilter
  boot.kernelModules = [ "wireguard" "fuse" "exfat" ];
  security.lockKernelModules = true;
  boot.kernel.sysctl = {
    # Désactiver Magic SysRq (compatible avec lockdown)
    "kernel.sysrq" = 0;
    # Restreindre dmesg aux processus privilégiés
    "kernel.dmesg_restrict" = 1;
    # Masquer les pointeurs kernel dans /proc
    "kernel.kptr_restrict" = 2;
    # Désactiver BPF pour les non-root
    "kernel.unprivileged_bpf_disabled" = 1;
    # Hardening BPF JIT
    "net.core.bpf_jit_harden" = 2;
    # Bloquer les user namespaces (surface d'attaque kernel — CVE-2022-0185, CVE-2023-32233)
    "user.max_user_namespaces" = 0;
    # Restreindre perf_event aux root
    "kernel.perf_event_paranoid" = 3;
    # Désactiver ptrace sauf root avec CAP_SYS_PTRACE
    "kernel.yama.ptrace_scope" = 2;
    # Réseau — anti-spoofing et durcissement
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    # SYN flood protection
    "net.ipv4.tcp_syncookies" = 1;
  };

  # Firewall strict — tout fermé par défaut
  networking.firewall = {
    enable = true;
    # SSH ouvert — à restreindre à l'interface Tailscale en Phase 1.8
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ ];
  };

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
  environment.systemPackages = (with pkgs; [
    git
    vim
    bat
    ripgrep
    fd
    tmux
    btop
  ]) ++ [
    claude-code
  ];

  # Variables de session
  environment.sessionVariables = {
    CLAUDE_CODE_TASK_LIST_ID = "infra";
  };


  # SSH serveur — hardened
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowTcpForwarding = false;
      AllowStreamLocalForwarding = false;
      MaxAuthTries = 3;
    };
  };

  # SSH client — config déclarative
  programs.ssh.extraConfig = ''
    IdentityFile ~/.ssh/id_ed25519_sk_rk
    AddKeysToAgent yes
  '';

  # SSH client — stub YubiKey sk résidente (pointeur vers la clé hardware)
  systemd.tmpfiles.rules = [
    "d /home/lambda/.ssh 0700 lambda users -"
    "C /home/lambda/.ssh/id_ed25519_sk_rk 0600 lambda users - ${./ssh/id_ed25519_sk_rk}"
    "C /home/lambda/.ssh/id_ed25519_sk_rk.pub 0644 lambda users - ${./ssh/id_ed25519_sk_rk.pub}"
  ];

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
