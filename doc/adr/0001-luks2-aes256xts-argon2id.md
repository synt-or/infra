# 0001 — LUKS2 avec AES-256-XTS et Argon2id

Date : 2026-04-04
Statut : acceptée

## Contexte

Le rootfs NixOS doit être chiffré intégralement. Le choix du format LUKS, du cipher et de la fonction de dérivation de clé a des implications directes sur la résistance au bruteforce et la compatibilité avec les outils NixOS (notamment `systemd-cryptenroll` pour FIDO2).

## Options évaluées

### Option A — LUKS1 avec PBKDF2

Format historique, compatible GRUB. PBKDF2 n'a pas de résistance mémoire — vulnérable au bruteforce par GPU/ASIC. Incompatible avec `systemd-cryptenroll`.

### Option B — LUKS2 avec Argon2id

Format moderne. Argon2id résiste au bruteforce CPU (coût en temps), GPU/ASIC (coût en mémoire ~1 GiB par tentative), et canaux auxiliaires (mode hybride "id"). Compatible `systemd-cryptenroll` pour futur enrôlement YubiKey FIDO2.

## Décision

LUKS2 avec les paramètres suivants :

- `--cipher aes-xts-plain64` — AES-256 en mode XTS, quantum-safe (Grover réduit à 128 bits effectifs, physiquement inattaquable)
- `--key-size 512` — 256 bits chiffrement + 256 bits tweak XTS
- `--hash sha512` — plus rapide que SHA-256 sur ARM64 (opérations 64 bits natives)
- `--pbkdf argon2id` — gagnant de la Password Hashing Competition 2015
- `--iter-time 5000` — 5 secondes par dérivation, compromis ergonomie/sécurité

## Conséquences

Avec une passphrase de ~158 bits d'entropie (diceware + random), le bruteforce est dans la zone d'impossibilité physique (nécessiterait plus d'énergie que la production annuelle du Soleil). Incompatible avec GRUB (pas un problème car Asahi utilise systemd-boot). Chaque saisie de passphrase prend ~5 secondes.
