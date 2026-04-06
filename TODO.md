# Roadmap Infrastructure NixOS

Machine : MacBook Pro M1 Pro 32 Go (2021), dual boot macOS (Full Security) / NixOS (Permissive Security) via Asahi Linux.
Objectif : infrastructure déclarative, reproductible, durcie, avec chiffrement intégral et chaîne de confiance vérifiable, adaptée à un profil HDS (données de santé) et militant.

-----

## Phase 0 — Installation fonctionnelle ✅

Système NixOS opérationnel sur LUKS2 + LVM avec les fondations de sécurité en place.

- [x] Partitionnement via gdisk (partition 6, 300 GiB, type 8300)
- [x] LUKS2 : AES-256-XTS, Argon2id, iter-time 5000ms, passphrase ~158 bits (diceware + random)
- [x] LVM à l’intérieur du LUKS : rootfs (200 GiB sur `/`) + data (100 GiB sur `/data`)
- [x] 251 GiB d’espace libre réservés pour le lab LUKS imbriqué en Phase 2
- [x] NixOS installé depuis le flake `github:synt-or/infra`
- [x] Boot EFI via PARTUUID Asahi (pas UUID — voir ADR 0006)
- [x] WiFi iwd persistant (CasaDeWawa, les credentials sont sauvegardés par iwd dans `/var/lib/iwd/`)
- [x] Stub clé SSH YubiKey sk résidente placé déclarativement via activationScripts
- [x] Git configuré déclarativement : signature de commits SSH sk, merge-only (pas de rebase)
- [x] Clavier Mac ISO français : `iso_layout=1` + keymap custom (`keymap/mac-fr-custom.map`)
- [x] Firmware Asahi embarqué dans `./firmware/` (élimine le flag `--impure`)
- [x] Claude Code installé (binaire natif Anthropic via `curl`, `programs.nix-ld.enable = true`)
- [x] CLAUDE.md, ADR (0001-0009), skills, tâches documentées

**État du disque :**

```
nvme0n1p1  500 MiB   iBootSystemContainer  (ne pas toucher)
nvme0n1p2  372.5 GiB macOS APFS            (FileVault activé)
nvme0n1p3  2.3 GiB   Stub Asahi            (m1n1 stage 1, Boot Policy SEP)
nvme0n1p4  477 MiB   EFI NixOS             (systemd-boot, kernel, initrd — NON chiffré)
nvme0n1p5  5.0 GiB   RecoveryOSContainer   (ne pas toucher)
nvme0n1p6  300 GiB   LUKS2 → LVM           (rootfs 200G + data 100G)
           251 GiB   espace libre           (futur lab Phase 2)
```

**Problèmes connus :**

- Emergency mode au boot (race condition prompt LUKS / services systemd) — non bloquant, Entrée continue le boot
- Keymap TTY incomplet pour certaines combinaisons Option (limitation console Linux, pas d’Apple Silicon)
- Claude Code installé hors nixpkgs (version 2.1.88 retirée de npm) — à nixifier en Phase 0.5
- `ssh-add` au login via `programs.bash.interactiveShellInit` — en cours de déploiement

-----

## Phase 0.5 — Nixifier Claude Code

Remplacer l’installation impérative (binaire natif + `nix-ld`) par une dérivation Nix déclarative avec vérification cryptographique directe depuis Anthropic.

**Pourquoi :** le binaire natif installé via `curl | bash` est un impératif non reproductible. `programs.nix-ld.enable` ouvre un vecteur d’attaque (tous les binaires FHS fonctionnent, pas seulement Claude Code). La dérivation custom restreint ça à un seul binaire vérifié.

**Approche :**

- Télécharger le binaire aarch64-linux depuis le CDN Anthropic (pas npm, pas de tiers)
- Vérifier `manifest.json.sig` avec la clé GPG Anthropic (commitée dans le repo)
- Patcher le linker dynamique avec `autoPatchelfHook` (standard NixOS pour les binaires précompilés)
- Intégrer dans `environment.systemPackages` via le flake
- Retirer `programs.nix-ld.enable` une fois validé

**Critère de succès :** `claude --version` fonctionne après un rebuild pur (pas de `--impure`, pas de `nix-ld`).

-----

## Phase 1 — Hardening

Durcir le système NixOS pour atteindre un niveau de sécurité cohérent avec le profil HDS et militant.

**Kernel :**

- `lockdown=confidentiality` — empêche root de lire la mémoire kernel (bloque extraction clé LUKS depuis userspace). Bloque aussi kprobes, /dev/mem, /dev/kmem, /proc/kcore, chargement de modules non signés. Compatible Asahi (drivers compilés in-tree).
- Paramètres sysctl : `kptr_restrict=2`, `dmesg_restrict=1`, `perf_event_paranoid=3`, `unprivileged_bpf_disabled=1`, `bpf_jit_harden=2`, `yama.ptrace_scope=2`, `kexec_load_disabled=1`
- `security.protectKernelImage = true`, `security.lockKernelModules = true`
- Vérification DART actif : `dmesg | grep -i dart` (le DART est l’IOMMU Apple Silicon, géré via device tree, pas via `iommu=force` qui est x86)

**Réseau :**

- Firewall strict : tout fermé par défaut (`networking.firewall.enable = true`, pas de ports ouverts)
- Tailscale comme unique interface d’accès distant
- SSH restreint aux clés sk uniquement (`PubkeyAcceptedKeyTypes = "sk-ecdsa-sha2-nistp256@openssh.com,sk-ssh-ed25519@openssh.com"`)

**Gestion d’énergie :**

- s2idle sur fermeture du couvercle (seul mode disponible sur Asahi, voir ADR 0002)
- Shutdown automatique après 30 min d’inactivité
- Justification formelle : le risque en s2idle est un sous-ensemble strict du risque en fonctionnement normal (voir ADR 0002)

**Chaîne de déploiement :**

- `safe-rebuild.sh` : wrapper autour de `nixos-rebuild` qui vérifie la signature SSH sk du dernier commit avant de builder. Refuse les commits non signés. Log d’audit dans `/var/log/nixos-rebuild-audit.log`. Fichier `.allowed_signers` versionné dans le repo. (Voir ADR 0007)
- Convention : ne jamais exécuter `nixos-rebuild` directement

**Nettoyage de la config :**

- Remplacer `system.activationScripts.sshStub` par `systemd.tmpfiles.rules` (plus idiomatique NixOS)
- Remplacer les lignes SSH dans l’activationScript par `programs.ssh.extraConfig` (déclaratif system-wide)
- Ajouter `pull.rebase = "false"` dans `programs.git.config` (voir ADR 0009)

**Vérification macOS :**

- Confirmer que FileVault est activé sur le conteneur APFS macOS (chiffrement couche 2, indispensable contre le vol physique)

-----

## Phase 2 — Chaîne de confiance

Établir une chaîne de confiance cryptographique vérifiable de bout en bout, du build à la partition EFI.

**Signature kernel et vérification d’intégrité :**

- Générer une paire ECDSA P-256 dans le SEP macOS (clé privée ne quitte jamais le SEP, chaque signature requiert Touch ID)
- `sign-kernel.sh` : depuis macOS, signe le kernel + initrd sur la partition EFI via SEP + Touch ID
- `verify-boot-integrity.sh` : depuis macOS (SSV garantit l’intégrité de l’environnement de vérification), calcule les hashes SHA-256 de tout le contenu de la partition EFI et compare avec les références stockées dans le Keychain macOS
- `update-hashes.sh` : met à jour les références après un rebuild signé réussi
- Procédure post-absence documentée : booter macOS → vérifier → si OK → booter NixOS

**Redondance YubiKey et récupération :**

- Acheter une seconde YubiKey (secours)
- Enrôler la YubiKey principale via `systemd-cryptenroll --fido2-device=auto` (keyslot additionnel)
- Enrôler la YubiKey de secours dans un second keyslot
- Passphrase de récupération longue sur papier dans un coffre physique (chez Émilie ou coffre bancaire)
- Tester chaque méthode de déverrouillage indépendamment
- Rappel : les keyslots LUKS sont des alternatives (OR), pas des facteurs (AND) — voir ADR 0004

**LUKS imbriqué (vrai multi-facteur) :**

- Tester sur la partition lab (251 GiB libres) AVANT de toucher au rootfs principal
- Architecture cible : partition → LUKS externe (passphrase diceware, quantum-safe) → LUKS interne (YubiKey Bio FIDO2, robuste aujourd’hui) → LVM → {rootfs, data}
- L’ordre passphrase-externe / YubiKey-interne est un choix post-quantique délibéré (voir ADR 0004) : la passphrase (symétrique, quantum-safe) est le facteur durable, la YubiKey (ECDH, vulnérable à Shor) est le facteur temporaire
- Combinaison LUKS imbriqué + FIDO2 + systemd initrd + Asahi = territoire pionnier, aucun témoignage trouvé — d’où le test sur partition lab
- Si test OK : planifier la migration du rootfs (reformater p6, réinstaller depuis le flake)
- Régénérer la partie random de la passphrase à 10-12 caractères (~66-79 bits résiduels pour résistance 30 ans contre attaquant étatique)

-----

## Phase 3 — Migration services Synology

Le Synology DS918+ est le SPOF le plus critique de l’infrastructure. Il contient toutes les sauvegardes depuis 2019, le vault Vaultwarden, Paperless-ngx, les mails, les données Google. DSM est un OS Linux propriétaire avec un historique de CVE. Ports 5001, 443 et autres ouverts.

**Services à migrer :**

- **Vaultwarden** : serveur de mots de passe (actuellement seul gestionnaire de secrets). Module NixOS déclaratif avec profil AppArmor dédié. Données à migrer depuis le Synology.
- **Paperless-ngx** : gestion de documents (factures, courriers, documents administratifs). Module NixOS déclaratif avec profil AppArmor dédié.
- **Sauvegardes** : remplacer Active Backup for Business (propriétaire Synology) par restic ou borgbackup avec chiffrement côté client. Le serveur de sauvegarde ne voit jamais de données en clair. La clé de chiffrement peut être dérivée d’un secret sur la YubiKey.

**Sécurité :**

- Chaque service isolé par AppArmor (un profil par service, principe du moindre privilège)
- Chiffrement côté client pour toutes les sauvegardes
- Test de restauration complète obligatoire avant de considérer la migration terminée
- La passphrase de récupération LUKS (keyslot 2) sert aussi de clé de dernier recours pour les sauvegardes

-----

## Phase 4 — Extension infrastructure

Étendre l’architecture NixOS au-delà du MacBook Pro, vers un déploiement multi-machine unifié.

**NixOS sur Hetzner :**

- VPS cloud pour les services publics (reverse proxy, monitoring)
- Bootstrap via cloud-init → NixOS takeover
- Même flake, même structure, configuration par host dans `hosts/`

**Remplacement du Synology :**

- Machine NixOS hardened dédiée (homelab) pour remplacer le DS918+
- Même niveau de sécurité que le MacBook Pro : LUKS, AppArmor, firewall strict

**Déploiement unifié :**

- deploy-rs pour pousser les configurations depuis le MacBook vers les machines distantes
- Un seul repo, un seul flake, des configurations par host

**YubiKey Bio FIDO Edition :**

- Migration de YubiKey FIDO2 + PIN vers YubiKey Bio (empreinte vérifiée dans le token, invisible au Mac)
- 2FA amélioré : objet + biométrie (plus résistant à la capture que le PIN)
- Disponible en achat direct (~90-100€), pas besoin de la Multi-protocol Edition (réservée à l’abonnement entreprise, le PIV/smart card n’est pas nécessaire pour ce use case)

**Lanzaboote :**

- Évaluer la compatibilité sur Asahi pour les Unified Kernel Images (UKI) signées
- Comblerait le trou de la partition EFI non chiffrée (kernel + initrd dans un seul binaire signé)

**Post-quantum :**

- **Rosenpass** pour WireGuard/Tailscale : déjà packagé dans nixpkgs, ajoute une couche post-quantum sur le tunnel WireGuard. C’est le vecteur HNDL (Harvest Now, Decrypt Later) le plus urgent — le trafic réseau chiffré aujourd’hui peut être stocké et déchiffré quand les ordinateurs quantiques seront opérationnels.
- **SSH** : épingler `mlkem768x25519-sha256` dans `KexAlgorithms` quand OpenSSH 10.x sera disponible sur nixpkgs
- **YubiKey** : attendre le support firmware ML-DSA (FIPS 204 / CRYSTALS-Dilithium) pour SSH — estimé 2027-2028
- **LUKS** : déjà quantum-safe (AES-256 symétrique, Grover réduit à 128 bits effectifs — physiquement inattaquable)
- **FIDO2 ECDSA** : vulnérable à Shor mais pas un vecteur HNDL pour LUKS (pas de trafic réseau à intercepter, l’échange ECDH se fait sur le bus USB local)

-----

## Principes transversaux

Ces principes s’appliquent à toutes les phases et ne sont pas spécifiques à une étape.

- **Déclaratif d’abord** : toute configuration passe par Git avec commits signés. L’impératif est toléré uniquement s’il disparaît au reboot ou est physiquement non déclarable (chaque exception est documentée et justifiée).
- **Reproductibilité** : le flake + `flake.lock` épinglent toutes les versions. Un `nixos-rebuild` depuis un commit donné produit le même système.
- **Architecture comme document vivant** : les ADR documentent chaque décision significative. On ne modifie jamais une ADR — on en crée une nouvelle qui la remplace.
- **Défense en profondeur** : chaque couche (hardware Apple Silicon, LUKS, kernel lockdown, AppArmor, firewall, SSH sk) protège indépendamment. La compromission d’une couche ne compromet pas les autres.
- **Pessimisme calibré** : le modèle de menace inclut l’attaquant étatique et le scénario post-quantique, mais les décisions sont pragmatiques (on ne sacrifie pas l’ergonomie quotidienne pour un scénario à 0.01% de probabilité).