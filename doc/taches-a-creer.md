# Tâches à importer dans Claude Code Tasks

Ce fichier contient toutes les tâches détaillées à créer dans le système de Tasks natif de Claude Code. Chaque phase est une tâche parente. Les sous-tâches ont des dépendances explicites.

Instruction pour Claude Code : “Crée les tâches de la Phase X à partir de taches-a-creer.md avec les dépendances indiquées.”

-----

## Phase 0.5 — Nixifier Claude Code

Parente : “Nixifier l’installation de Claude Code”

1. Rechercher la dernière version stable de Claude Code sur npm et le CDN Anthropic
1. Télécharger et vérifier la clé GPG Anthropic (`claude-code.asc`), la commiter dans le repo
- dépend de : 1
1. Écrire une dérivation Nix custom qui télécharge le binaire natif aarch64-linux depuis le CDN Anthropic
- dépend de : 1
1. Ajouter la vérification GPG de `manifest.json.sig` dans la dérivation
- dépend de : 2, 3
1. Ajouter `autoPatchelfHook` pour patcher le linker dynamique
- dépend de : 3
1. Intégrer la dérivation dans `configuration.nix` via `environment.systemPackages`
- dépend de : 4, 5
1. Tester : `claude --version` fonctionne après rebuild
- dépend de : 6
1. Retirer `programs.nix-ld.enable = true` de la config
- dépend de : 7
1. Vérifier que Claude Code fonctionne toujours sans nix-ld
- dépend de : 8
1. Commit signé + ADR 0010 documentant la dérivation custom
- dépend de : 9

-----

## Phase 1 — Hardening

Parente : “Hardening du système NixOS”

### Kernel et boot

1. Ajouter `lockdown=confidentiality` à `boot.kernelParams`
1. Ajouter les paramètres sysctl de hardening :
- `kernel.kptr_restrict = 2`
- `kernel.dmesg_restrict = 1`
- `kernel.perf_event_paranoid = 3`
- `kernel.unprivileged_bpf_disabled = 1`
- `net.core.bpf_jit_harden = 2`
- `kernel.yama.ptrace_scope = 2`
- `kernel.kexec_load_disabled = 1`
- dépend de : 11
1. Ajouter `security.protectKernelImage = true`
- dépend de : 11
1. Ajouter `security.lockKernelModules = true`
- dépend de : 11
1. Rebuild + reboot + vérifier que le système boot correctement avec lockdown
- dépend de : 12, 13, 14
1. Vérifier que le DART est actif : `dmesg | grep -i dart`
- dépend de : 15

### Réseau

1. Configurer le firewall strict : tout fermé par défaut
- dépend de : 15
1. Installer et configurer Tailscale
- dépend de : 17
1. Restreindre SSH aux clés sk uniquement : `PubkeyAcceptedKeyTypes = "sk-ecdsa-sha2-nistp256@openssh.com,sk-ssh-ed25519@openssh.com"`
- dépend de : 17

### Gestion d’énergie

1. Configurer `services.logind` : s2idle sur fermeture couvercle, shutdown après 30 min
- dépend de : 15
1. Tester : fermer le couvercle → s2idle, attendre 30 min → shutdown
- dépend de : 20

### Chaîne de déploiement

1. Écrire `safe-rebuild.sh` : vérification signature du dernier commit avant rebuild
- dépend de : 15
1. Créer `.allowed_signers` avec la clé publique SSH sk autorisée
- dépend de : 22
1. Tester : commit non signé → safe-rebuild refuse. Commit signé → safe-rebuild accepte
- dépend de : 23
1. Mettre en place le log d’audit `/var/log/nixos-rebuild-audit.log`
- dépend de : 22

### Nettoyage config

1. Remplacer `system.activationScripts.sshStub` par `systemd.tmpfiles.rules`
1. Remplacer les lignes SSH dans activationScript par `programs.ssh.extraConfig`
- dépend de : 26
1. Ajouter `pull.rebase = "false"` dans `programs.git.config`
1. Rebuild + reboot + vérifier que tout fonctionne (SSH, git, agent)
- dépend de : 26, 27, 28

### Vérification macOS

1. Vérifier que FileVault est activé côté macOS
1. ADR 0011 documentant le hardening Phase 1
- dépend de : 29, 30

-----

## Phase 2 — Chaîne de confiance

Parente : “Établir la chaîne de confiance complète”

### Signature et vérification

1. Générer une paire ECDSA P-256 dans le SEP macOS pour la signature kernel
1. Écrire `sign-kernel.sh` : signe kernel + initrd via SEP + Touch ID depuis macOS
- dépend de : 32
1. Écrire `verify-boot-integrity.sh` : vérifie hashes partition EFI depuis macOS
- dépend de : 32
1. Écrire `update-hashes.sh` : met à jour les hashes de référence après un rebuild signé
- dépend de : 34
1. Documenter la procédure post-absence (quand vérifier, comment réagir)
- dépend de : 34

### YubiKey de secours

1. Acheter une seconde YubiKey
1. Enrôler la YubiKey principale dans LUKS via `systemd-cryptenroll --fido2-device=auto`
1. Enrôler la YubiKey de secours dans un second keyslot LUKS
- dépend de : 37, 38
1. Créer et stocker la passphrase de récupération sur papier (keyslot 2, coffre physique)
- dépend de : 38
1. Tester chaque méthode de déverrouillage : YubiKey principale, YubiKey secours, passphrase récupération
- dépend de : 39, 40

### LUKS imbriqué

1. Créer une partition lab sur les 251 GiB libres via gdisk
1. Formater en LUKS externe (passphrase) → LUKS interne (FIDO2) → LVM → ext4 sur la partition lab
- dépend de : 42
1. Tester le boot complet depuis la partition lab
- dépend de : 43
1. Si OK : planifier la migration du rootfs principal vers LUKS imbriqué
- dépend de : 44
1. Régénérer la partie random de la passphrase à 10-12 caractères
1. ADR 0012+ documentant les décisions Phase 2
- dépend de : 45

-----

## Phase 3 — Migration Synology

Parente : “Migrer les services du Synology DS918+ vers NixOS”

1. Auditer les services actuels du Synology : ports ouverts, données, dépendances
1. Écrire le module NixOS pour Vaultwarden avec profil AppArmor
- dépend de : 48
1. Migrer les données Vaultwarden depuis le Synology
- dépend de : 49
1. Écrire le module NixOS pour Paperless-ngx avec profil AppArmor
- dépend de : 48
1. Migrer les données Paperless-ngx depuis le Synology
- dépend de : 51
1. Configurer les sauvegardes restic/borg chiffrées côté client
- dépend de : 50, 52
1. Tester la restauration complète depuis les sauvegardes
- dépend de : 53
1. ADR documentant la migration et l’architecture résultante
- dépend de : 54

-----

## Phase 4 — Extension infrastructure

Parente : “Étendre l’infrastructure NixOS”

1. Déployer NixOS sur un VPS Hetzner
1. Configurer deploy-rs pour déploiement unifié depuis le repo
- dépend de : 56
1. Planifier le remplacement du Synology par un NixOS hardened dédié
- dépend de : 54 (Phase 3)
1. Acheter une YubiKey Bio FIDO Edition
1. Évaluer Lanzaboote sur Asahi pour les UKI signées
1. Évaluer Rosenpass pour le post-quantum sur WireGuard/Tailscale
1. Configurer `mlkem768x25519-sha256` pour SSH quand OpenSSH 10.x sera disponible
- dépend de : 61
1. Veille technique : CONFIG_HIBERNATION Asahi, ML-DSA pour YubiKey (estimé 2027-2028)