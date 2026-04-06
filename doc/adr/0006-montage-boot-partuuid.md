# 0006 — Montage /boot via PARTUUID au lieu de UUID

Date : 2026-04-05
Statut : acceptée

## Contexte

La partition EFI NixOS doit être montée comme `/boot` au démarrage. `nixos-generate-config` a détecté un UUID (`3B6A-1703`) mais le montage échouait avec un timeout au boot.

## Options évaluées

### Option A — UUID du filesystem FAT32

C'est ce que `nixos-generate-config` détecte par défaut. Problème : l'UUID a été mal lu sur une photo (3B6A vs 386A), causant un timeout au boot. L'UUID FAT32 est aussi plus fragile (peut changer si la partition est reformatée).

### Option B — PARTUUID de la table GPT

Le PARTUUID est dérivé de la table GPT, disponible plus tôt dans le processus de boot. C'est aussi ce que le guide officiel Asahi recommande via `/proc/device-tree/chosen/asahi,efi-system-partition`.

## Décision

Option B. Le PARTUUID `24d48474-2a34-451f-813a-105ed62ad249` est utilisé dans `hardware-configuration.nix`. Vérifié par MD5 croisé entre le Mac et l'iPhone.

## Conséquences

Plus fiable au boot. Aligné avec la recommandation Asahi. Le PARTUUID ne change pas si le filesystem est reformaté (seul un repartitionnement le modifierait).
