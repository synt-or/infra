# 0005 — LVM à l'intérieur du LUKS, un seul jeu de clés

Date : 2026-04-05
Statut : acceptée

## Contexte

Le rootfs NixOS et les données utilisateur doivent être séparés logiquement (pour pouvoir reformater l'un sans toucher l'autre) mais protégés par le même ensemble de clés (pour ne pas multiplier les risques de perte de clé).

## Options évaluées

### Option A — Deux LUKS indépendants avec clés différentes

Séparation cryptographique complète. Double le nombre de clés à gérer, double le risque de perte.

### Option B — Deux LUKS indépendants avec même clé

Séparation cryptographique mais même passphrase. Deux déverrouillages au boot pour la même clé — mauvaise UX sans gain de sécurité.

### Option C — Un LUKS avec LVM à l'intérieur

Un seul déverrouillage. LVM sépare rootfs (200 GiB) et data (100 GiB) logiquement. Reformater le rootfs et réinstaller NixOS depuis le flake ne touche pas au volume data. Redimensionnement possible sans reformatage.

## Décision

Option C. Un seul LUKS, un seul jeu de clés, deux volumes logiques. La séparation est logique (LVM), pas cryptographique. L'architecture complète en Phase 2 sera : partition physique → LUKS externe (passphrase) → LUKS interne (YubiKey) → LVM → {rootfs, data}.

## Conséquences

Un seul déverrouillage au boot. Le volume data survit aux réinstallations. Le repo git vit dans `/data/infra` et persiste indépendamment du rootfs.
