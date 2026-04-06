# 0012 — YubiKey Bio FIDO Edition

Date : 2026-04-06
Statut : acceptée (implémentation prévue Phase 4)

## Contexte

La migration vers une YubiKey Bio apporte la vérification biométrique dans le token (empreinte vérifiée localement, invisible au Mac). Deux variantes existent avec des capacités et des canaux de distribution différents.

## Options évaluées

### Option A — YubiKey Bio Multi-protocol Edition

FIDO2 + U2F + PIV/smart card. Disponible exclusivement via YubiKey as a Service (abonnement entreprise). Ajoute les certificats X.509, l'authentification Windows smart card, le VPN client-certificate, S/MIME.

Le seul scénario où PIV manquerait : stocker la clé de signature kernel directement sur la YubiKey au lieu du SEP macOS — nice-to-have, pas bloquant.

### Option B — YubiKey Bio FIDO Edition

FIDO2 + U2F uniquement. En vente libre (~90-100€). Couvre :

- Déverrouillage LUKS via FIDO2 (`systemd-cryptenroll --fido2-device=auto`)
- Clés SSH sk résidentes (`ssh-keygen -t ed25519-sk -O resident`)
- Signature de commits Git sans GPG (Git 2.34+, `gpg.format = ssh`)
- Passkeys pour l'authentification web
- 2FA biométrique : objet + empreinte (plus résistant à la capture que le PIN)

## Décision

Option B. Aucun use case identifié pour PIV/smart card (pas de PKI entreprise, pas d'Active Directory, pas de S/MIME). Les clés SSH sk résidentes couvrent la signature de commits sans GPG. Le canal de distribution en vente libre est un avantage pratique significatif par rapport à l'abonnement entreprise.

## Conséquences

La YubiKey Bio FIDO Edition sera achetée en Phase 4 (deux exemplaires : principale + secours). Elle remplacera la YubiKey FIDO2 + PIN actuelle. Le passage de PIN à biométrie améliore la résistance à la capture du facteur d'authentification (shoulder surfing, caméra) sans changer l'architecture LUKS ou SSH.

Si le besoin PIV émerge (PKI, signature kernel sur YubiKey), la Multi-protocol Edition pourra être réévaluée via une nouvelle ADR.
