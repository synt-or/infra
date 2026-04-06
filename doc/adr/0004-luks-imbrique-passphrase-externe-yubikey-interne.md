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

## Conséquences

Au boot : saisie passphrase → touch YubiKey Bio. Deux déverrouillages séquentiels. Surcoût ~10-15 secondes par boot. Implémentation prévue en Phase 2 sur la partition lab (251 GiB libres) avant migration. Combinaison LUKS imbriqué + FIDO2 + systemd initrd + Asahi = territoire pionnier, aucun témoignage trouvé.
