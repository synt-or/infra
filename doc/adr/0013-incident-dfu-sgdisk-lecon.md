# 0013 — Incident DFU : sgdisk -s et perte du RecoveryOS

Date : 2026-04-04
Statut : acceptée (leçon apprise)

## Contexte

Première tentative d'installation de NixOS sur le MacBook Pro M1 Pro via Asahi Linux. L'installeur Asahi a correctement redimensionné macOS à 875 Go et créé le stub APFS, la partition EFI, et réservé 108.6 GiB d'espace libre pour NixOS.

Table de partition avant l'erreur :

| Partition | Contenu              | Taille    |
| --------- | -------------------- | --------- |
| p1        | iBootSystemContainer | 500 MiB   |
| p2        | macOS APFS           | 875 GiB   |
| p3        | Stub Asahi           | 2.3 GiB   |
| p4        | EFI NixOS            | 477 MiB   |
| p5        | RecoveryOSContainer  | 5 GiB     |
|           | espace libre         | 108.6 GiB |

## Options évaluées

### Option A — sgdisk (scriptable, exécution immédiate)

La commande `sgdisk /dev/nvme0n1 -n 0:0 -s` a créé une nouvelle partition dans l'espace libre de 108.6 GiB **ET** retrié toutes les partitions par ordre de secteur de début (flag `-s`, « sort »).

Après le tri : la nouvelle partition (dont les secteurs sont entre p4 et l'ancien RecoveryOS) est devenue p5, et le RecoveryOS a été décalé en p6.

L'instruction suivante était de formater « p6 » en pensant que c'était la nouvelle partition. En réalité p6 était devenu le RecoveryOSContainer (5 Go). NixOS a été installé sur 5 Go au lieu de 108.6 Go.

### Option B — gdisk (interactif, écriture seulement sur `w`)

gdisk permet de créer la partition, vérifier avec `p` (print) que les numéros correspondent à ce qu'on attend, puis valider avec `w` (write). Aucune renumérotation silencieuse.

## Décision

Option B. Utiliser gdisk (interactif) au lieu de sgdisk (scriptable) pour toute opération de partitionnement. Ne jamais utiliser le flag `-s` (sort). Toujours vérifier avec `p` avant de valider avec `w`. Voir [ADR 0008](0008-gdisk-interactif-pas-sgdisk.md) pour la décision formelle.

## Conséquences

**Dommages :** RecoveryOS écrasé par NixOS. Espace insuffisant pour `nixos-rebuild switch` (5 Go). La partition de 108.6 Go restée vierge et inutilisée. macOS, iBoot, stub Asahi et EFI intacts.

**Récupération :** DFU restore complet via Apple Configurator (idevicerestore). Disque entièrement effacé. macOS réinstallé de zéro. Installeur Asahi relancé, cette fois avec macOS redimensionné à 372.5 GiB (au lieu de 875 Go), laissant plus d'espace pour NixOS.

**Ce qui a été sauvé :** `configuration.nix` et `flake.nix` poussés sur GitHub (`github.com:synt-or/infra`). Clé SSH ed25519-sk résidente générée dans la YubiKey et ajoutée à GitHub. Ces éléments ont permis de repartir rapidement après le DFU restore.

**Leçon :** après toute opération de partitionnement, toujours revérifier quel numéro de partition correspond à quoi avec `sgdisk -p` ou `gdisk` → `p` avant de formater. Les numéros de partition GPT sont des étiquettes arbitraires qui ne correspondent pas nécessairement à l'ordre physique des secteurs.
