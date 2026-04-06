# 0007 — nixos-rebuild ne vérifie pas les signatures de commit

Date : 2026-04-04
Statut : acceptée

## Contexte

Les commits du repo sont signés avec une clé SSH sk résidente sur YubiKey. Mais `nixos-rebuild --flake` ne vérifie pas ces signatures — il fait un fetch et build aveuglément. Un attaquant qui push un commit non signé (via compromission GitHub) ou qui fait un rebuild local depuis un flake arbitraire pourrait déployer une config malveillante.

## Options évaluées

### Option A — Accepter le risque

`nixos-rebuild` est l'outil standard NixOS. Modifier son comportement n'est pas prévu upstream.

### Option B — Wrapper safe-rebuild.sh

Un script qui vérifie la signature du dernier commit sur `origin/main` avant de lancer le rebuild. Refuse de builder si le commit n'est pas signé par la clé autorisée. Log d'audit. `.allowed_signers` versionné dans le repo.

## Décision

Option B. Le wrapper est une convention, pas une contrainte technique (root peut le contourner). La protection ultime reste la vérification des hashes depuis macOS + signature kernel via SEP. Le `--ff-only` dans le wrapper empêche les rebases forcés.

## Conséquences

À implémenter en Phase 1. Ne jamais exécuter `nixos-rebuild` directement — toujours passer par `safe-rebuild.sh`. Un attaquant root peut contourner le wrapper, mais le log d'audit et la vérification post-reboot depuis macOS couvrent ce vecteur.
