# 0009 — Merge plutôt que rebase

Date : 2026-04-05
Statut : acceptée

## Contexte

Git propose trois stratégies pour réconcilier des branches divergentes : merge, rebase, et fast-forward only. Les commits de ce repo sont signés avec une clé SSH sk résidente sur YubiKey.

## Décision

Merge uniquement (`git config pull.rebase false`). Le rebase réécrit les commits (nouveaux hashes), ce qui casse les signatures existantes. Le merge préserve les commits originaux avec leurs signatures intactes et crée un commit de merge par-dessus (lui-même signé). Le fast-forward only n'est pas toujours possible quand les branches ont divergé.

## Conséquences

L'historique git contient des commits de merge, ce qui est moins "propre" visuellement mais préserve l'intégrité cryptographique de chaque commit. Cohérent avec le wrapper `safe-rebuild.sh` qui vérifie les signatures.
