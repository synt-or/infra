# Instructions pour Claude Code — Compléments

Lis CLAUDE.md et les ADR existantes dans doc/adr/ pour le contexte. Trois éléments manquants à intégrer.

-----

## 1. Enrichir `doc/adr/0003-passphrase-split-bitwarden-iphone.md`

Ajouter une section “Analyse d’entropie” après la section “Décision” avec les éléments suivants :

La passphrase est composée de deux parties concaténées.

Partie diceware : 7 mots de la liste EFF (7776 mots, log₂(7776) ≈ 12.9 bits par mot = ~90.3 bits) + 1 mot absent de la liste (conservativement un mot anglais courant parmi ~50 000, log₂(50000) ≈ 15.6 bits). Total partie diceware : ~106 bits.

Partie random : 8 caractères truly random sur l’alphabet ASCII imprimable (95 caractères, log₂(95) ≈ 6.6 bits par caractère = ~52.6 bits).

Total : ~158 bits d’entropie. C’est au-delà du seuil post-quantique (128 bits après réduction par Grover).

Analyse de résistance résiduelle si Bitwarden est compromis (partie diceware exposée, partie random seule) : avec 8 caractères random (~53 bits) et Argon2id à 5 secondes par tentative, un cluster de 1000 GPU A100 (80 Go VRAM chacun, ~80 000 tentatives/seconde grâce à la résistance mémoire d’Argon2id) mettrait environ 28 500 ans. Suffisant aujourd’hui, mais un attaquant étatique en 2056 avec ~10⁹ tentatives/seconde le casserait en ~2.3 ans.

Recommandation (déjà dans TODO.md Phase 2) : augmenter la partie random à 10-12 caractères (~66-79 bits résiduels). Avec 10 caractères, l’attaquant étatique de 2056 mettrait ~29 000 ans. Avec 12 caractères, ~30 milliards d’années.

Contexte physique (limite de Landauer) : effacer un bit d’information coûte au minimum kT·ln(2) ≈ 2.85 × 10⁻²¹ joules à température ambiante. Bruteforcer 2²⁵⁶ clés nécessiterait au minimum ~3.3 × 10⁵⁶ joules — environ 2.75 × 10²² fois la production énergétique annuelle du Soleil. C’est une impossibilité physique, pas computationnelle. La passphrase complète de 158 bits est dans cette zone.

-----

## 2. Enrichir `doc/adr/0004-luks-imbrique-passphrase-ext-yubikey-int.md`

Ajouter une section “Détail de la vulnérabilité quantique FIDO2” après la section “Décision” :

La YubiKey FIDO2 utilise l’extension hmac-secret pour le déverrouillage LUKS. Le flux est : un sel est stocké dans l’en-tête LUKS (public). Au déverrouillage, la plateforme et la YubiKey établissent un secret partagé via ECDH (Elliptic Curve Diffie-Hellman) pour chiffrer les échanges. La YubiKey calcule un HMAC avec son secret interne et le sel, et renvoie le résultat chiffré via le canal ECDH. Ce résultat sert de clé pour ouvrir le keyslot LUKS.

Le HMAC lui-même est symétrique (quantum-safe). Mais le canal ECDH qui protège l’échange est asymétrique (courbes elliptiques). L’algorithme de Shor, sur un ordinateur quantique, casserait l’ECDH en temps polynomial.

C’est un vecteur “Harvest Now, Decrypt Later” (HNDL) : un attaquant qui capture le trafic USB entre le Mac et la YubiKey pendant une session de déverrouillage (par exemple via un keylogger matériel USB-C, ou une compromission du bus USB au niveau kernel) pourrait stocker cet échange chiffré et le déchiffrer rétroactivement quand les ordinateurs quantiques seront opérationnels. Il récupérerait alors le résultat HMAC et pourrait l’utiliser pour déverrouiller le volume LUKS interne sans jamais toucher physiquement la YubiKey.

C’est pour ça que la passphrase (quantum-safe, symétrique) est en couche externe et la YubiKey (quantum-vulnérable via ECDH) en couche interne : l’attaquant post-quantique est bloqué dès la première porte et ne peut même pas accéder au trafic FIDO2 de la couche interne.

Note : le FIDO2 ECDSA n’est PAS un vecteur HNDL pour le LUKS en Phase 0 (LUKS simple, pas imbriqué) car la passphrase protège le volume et il n’y a pas de trafic FIDO2 à intercepter. Le vecteur HNDL ne devient pertinent qu’en Phase 2 quand la YubiKey est ajoutée comme couche de déverrouillage.

-----

## 3. Créer `doc/adr/0013-incident-dfu-sgdisk-lecon.md`

ADR documentant l’incident qui a mené au DFU restore. Utilise le template dans .claude/skills/new-adr/SKILL.md.

Date : 2026-04-04
Statut : acceptée (leçon apprise)

Contexte : Première tentative d’installation de NixOS sur le MacBook Pro M1 Pro via Asahi Linux.

Ce qui s’est passé : L’installeur Asahi a correctement redimensionné macOS à 875 Go et créé le stub APFS, la partition EFI, et réservé 108.6 GiB d’espace libre pour NixOS. La table de partition avant l’erreur était : p1 iBoot, p2 macOS, p3 stub Asahi, p4 EFI, p5 RecoveryOS.

La commande `sgdisk /dev/nvme0n1 -n 0:0 -s` a créé une nouvelle partition dans l’espace libre de 108.6 GiB ET retrié toutes les partitions par ordre de secteur de début (flag -s, “sort”). Après le tri : la nouvelle partition (dont les secteurs sont entre p4 et l’ancien RecoveryOS) est devenue p5, et le RecoveryOS a été décalé en p6.

L’instruction suivante était de formater “p6” en pensant que c’était la nouvelle partition. En réalité p6 était devenu le RecoveryOSContainer (5 Go). NixOS a été installé sur 5 Go au lieu de 108.6 Go.

Conséquences : RecoveryOS écrasé par NixOS. Espace insuffisant pour nixos-rebuild switch (5 Go). La partition de 108.6 Go est restée vierge et inutilisée. macOS, iBoot, stub Asahi et EFI intacts.

L’erreur a mené à un brick du Mac nécessitant un DFU restore complet via Apple Configurator (idevicerestore). Le disque a été entièrement effacé. macOS a été réinstallé de zéro. L’installeur Asahi a été relancé, cette fois avec macOS redimensionné à 372.5 GiB (au lieu de 875 Go), laissant plus d’espace pour NixOS.

Décision : Utiliser gdisk (interactif, écriture seulement sur `w`) au lieu de sgdisk (scriptable, exécution immédiate) pour toute opération de partitionnement. Ne jamais utiliser le flag `-s` (sort). Toujours vérifier avec `p` (print) avant de valider avec `w` (write). Voir ADR 0008 pour la décision formelle.

Leçon : Après toute opération de partitionnement, toujours revérifier quel numéro de partition correspond à quoi avec `sgdisk -p` ou `gdisk` → `p` avant de formater. Les numéros de partition GPT sont des étiquettes arbitraires qui ne correspondent pas nécessairement à l’ordre physique des secteurs.

Ce qui a été sauvé malgré l’incident : configuration.nix et flake.nix poussés sur GitHub (https://github.com/synt-or/infra). Clé SSH ed25519-sk résidente générée dans la YubiKey et ajoutée à GitHub. Ces éléments ont permis de repartir rapidement après le DFU restore.

-----

## Règles

- Écrire en français
- Pour les ADR, utiliser le template de .claude/skills/new-adr/SKILL.md
- Pour les enrichissements d’ADR existantes : ajouter les nouvelles sections sans modifier le contenu existant (respecter le principe d’immutabilité des ADR sauf ajout de contexte)
- Commit signé avec message descriptif