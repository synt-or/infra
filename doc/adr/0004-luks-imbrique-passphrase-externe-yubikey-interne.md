# 0004 — LUKS imbriqué : passphrase externe, YubiKey interne

Date : 2026-04-04
Statut : acceptée (implémentation prévue Phase 2)

## Contexte

Le vrai multi-facteur LUKS nécessite du LUKS imbriqué (les keyslots sont des alternatives OR, pas des facteurs AND). L'ordre des couches a des implications post-quantiques.

## Options évaluées

### Option A — YubiKey externe, passphrase interne

La YubiKey (FIDO2/ECDH, vulnérable à Shor) sert de première barrière. Un attaquant post-quantique casse la couche externe, découvre la couche interne, et doit encore bruteforcer la passphrase.

### Option B — Passphrase externe, YubiKey interne

La passphrase (AES-256 symétrique via Argon2id, quantum-safe) sert de première barrière. Un attaquant post-quantique ne franchit même pas la première porte. Aucune information sur la structure interne n'est révélée.

## Décision

Option B. La passphrase est le facteur durable (quantum-safe), la YubiKey est le facteur temporaire (robuste aujourd'hui, vulnérable à Shor via ECDH à terme). La première barrière doit être celle qui résistera le plus longtemps. Bonus : la passphrase ne passe pas par USB (clavier intégré via bus SPI), donc une interception du bus USB ne compromet aucune couche.

## Détail de la vulnérabilité quantique FIDO2

La YubiKey FIDO2 utilise l'extension `hmac-secret` pour le déverrouillage LUKS. Le flux est :

1. Un **sel** est stocké dans l'en-tête LUKS (public).
2. Au déverrouillage, la plateforme et la YubiKey établissent un **secret partagé via ECDH** (Elliptic Curve Diffie-Hellman) pour chiffrer les échanges.
3. La YubiKey calcule un **HMAC** avec son secret interne et le sel, et renvoie le résultat chiffré via le canal ECDH.
4. Ce résultat sert de **clé pour ouvrir le keyslot LUKS**.

Le HMAC lui-même est symétrique (quantum-safe). Mais le canal ECDH qui protège l'échange est asymétrique (courbes elliptiques). L'algorithme de Shor, sur un ordinateur quantique, casserait l'ECDH en temps polynomial.

### Vecteur HNDL (Harvest Now, Decrypt Later)

Un attaquant qui capture le trafic USB entre le Mac et la YubiKey pendant une session de déverrouillage (keylogger matériel USB-C, ou compromission du bus USB au niveau kernel) pourrait stocker cet échange chiffré et le déchiffrer rétroactivement quand les ordinateurs quantiques seront opérationnels. Il récupérerait alors le résultat HMAC et pourrait l'utiliser pour déverrouiller le volume LUKS interne sans jamais toucher physiquement la YubiKey.

### Conséquence sur l'architecture imbriquée

C'est pour ça que la passphrase (quantum-safe, symétrique) est en couche externe et la YubiKey (quantum-vulnérable via ECDH) en couche interne : l'attaquant post-quantique est bloqué dès la première porte et ne peut même pas accéder au trafic FIDO2 de la couche interne.

### Note sur la Phase 0

Le FIDO2 ECDSA n'est PAS un vecteur HNDL pour le LUKS en Phase 0 (LUKS simple, pas imbriqué) car la passphrase protège le volume et il n'y a pas de trafic FIDO2 à intercepter. Le vecteur HNDL ne devient pertinent qu'en Phase 2 quand la YubiKey est ajoutée comme couche de déverrouillage.

## Conséquences

Au boot : saisie passphrase → touch YubiKey Bio. Deux déverrouillages séquentiels. Surcoût ~10-15 secondes par boot. Implémentation prévue en Phase 2 sur la partition lab (251 GiB libres) avant migration. Combinaison LUKS imbriqué + FIDO2 + systemd initrd + Asahi = territoire pionnier, aucun témoignage trouvé.
