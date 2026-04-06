# 0008 — gdisk interactif plutôt que sgdisk scriptable

Date : 2026-04-05
Statut : acceptée

## Contexte

Lors de la première tentative d'installation, `sgdisk -s` (sort) a renumé toutes les partitions par ordre de secteur. NixOS a été installé sur le RecoveryOS (5 Go) au lieu de la partition de 108 Go. La machine a été brickée, nécessitant un DFU restore complet.

## Décision

Utiliser `gdisk` (interactif) au lieu de `sgdisk` (scriptable) pour toute opération de partitionnement. `gdisk` modifie la table en mémoire sans écrire sur le disque tant que la commande `w` n'est pas explicitement confirmée. Toujours vérifier avec `p` (print) avant de valider. Ne jamais utiliser le flag `-s` (sort) de sgdisk.

## Conséquences

Moins scriptable, mais beaucoup plus sûr pour les opérations manuelles. Les numéros de partition ne correspondent pas à l'ordre physique des secteurs — c'est normal et sans impact fonctionnel.
