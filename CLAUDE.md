# Infrastructure NixOS — MacBook Pro M1 Pro

Config déclarative NixOS pour un MacBook Pro M1 Pro 32 Go (2021) via Asahi Linux. Profil de sécurité élevé : données de santé HDS, infrastructure GPU (VS Network SAS), profil militant.

## Architecture

- LUKS2 (AES-256-XTS, Argon2id) → LVM → rootfs (200 GiB sur `/`) + data (100 GiB sur `/data`)
- Boot EFI monté via PARTUUID (pas UUID) — spécificité Asahi
- Firmware Asahi embarqué dans `./firmware` pour éviter `--impure`
- Stub clé SSH YubiKey dans `./ssh/` (pas un secret — pointeur vers la clé privée dans le hardware)
- 251 GiB libres pour futur lab LUKS imbriqué

## Workflow

Le flake vit dans `/data/infra`. Toute modification suit ce cycle :

1. Modifier les fichiers .nix dans `/data/infra`
1. `git add -A && git commit -m "description"` (la YubiKey clignotera pour signer)
1. `sudo nixos-rebuild switch --flake /data/infra#nixos`
1. `git push`

Pas de `--impure`. Pas de `sed` direct sur `/etc/nixos`. Pas de `nixos-rebuild` hors du flake.

Si `git commit` échoue avec “Couldn’t find key in agent”, vérifier `ssh-add -l`. Si l’agent est vide : `ssh-add ~/.ssh/id_ed25519_sk_rk`.

## Règles non négociables

1. **Tout passe par git.** Aucune modification de fichier .nix directement sur le disque. Modifier dans le repo, commit signé, rebuild.
1. **Tous les commits sont signés.** Clé SSH sk résidente sur YubiKey. Ne jamais `--no-gpg-sign`.
1. **Pas de `--impure`.** Si le build le demande, corriger le chemin absolu dans la config.
1. **L’impératif est toléré uniquement s’il disparaît au reboot ou est physiquement non déclarable.** Exemples tolérés : `systemd-cryptenroll`, `passwd`, connexion WiFi initiale. Tout impératif toléré doit être documenté avec sa justification.
1. **Jamais de secrets en clair dans le repo.** Pas de clé API, pas de token, pas de mot de passe.
1. **Ne pas toucher aux partitions 1-5.** Seule la partition 6 (LUKS) et l’espace libre après sont sous notre contrôle.

## Pièges de sécurité

- **Hibernation** : indisponible (CONFIG_HIBERNATION désactivé sur Asahi) ET incompatible avec lockdown. Ne pas proposer.
- **`iommu=force`** : paramètre x86. Le DART Apple est géré via device tree automatiquement.
- **Keyslots LUKS** : alternatives (OR), pas facteurs cumulables (AND). Le vrai multi-facteur nécessite du LUKS imbriqué.
- **`preLVM`** : incompatible avec systemd initrd. Ne pas utiliser.
- **`nixos-rebuild`** ne vérifie pas les signatures de commit. Un wrapper `safe-rebuild.sh` est prévu.
- **Merges, pas rebases** : les rebases cassent les signatures de commit.

## Connu cassé / en attente

- **Claude Code** : binaire natif Anthropic + `nix-ld`, pas via nixpkgs (version retirée de npm). À nixifier en Phase 0.5.
- **Emergency mode au boot** : race condition prompt LUKS / services systemd. Non bloquant (Entrée continue le boot).
- **Keymap TTY** : corrections partielles dans `keymap/mac-fr-custom.map`. Certaines combinaisons Option ne fonctionnent pas (limitation console Linux).

## Phases

1. Installation fonctionnelle ✅
   0.5. Nixifier Claude Code (dérivation custom + vérification GPG)
1. Hardening (lockdown, sysctl, firewall, safe-rebuild.sh)
1. Chaîne de confiance (signature kernel SEP, LUKS imbriqué, YubiKey secours)
1. Migration Synology (Vaultwarden, Paperless-ngx, sauvegardes)
1. Extension infrastructure (Hetzner, deploy-rs, YubiKey Bio)

Détails dans @TODO.md. Décisions architecturales dans @doc/adr/