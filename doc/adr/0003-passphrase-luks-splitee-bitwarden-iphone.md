# 0003 — Passphrase LUKS splitée entre Bitwarden et iPhone

Date : 2026-04-04
Statut : acceptée

## Contexte

La passphrase LUKS doit être mémorisable, tapable quotidiennement, et résistante au bruteforce sur 30+ ans. Elle doit aussi survivre à la perte d'un des supports de stockage.

## Options évaluées

### Option A — Passphrase unique stockée dans Bitwarden

Un seul point de compromission. Si Bitwarden tombe, tout tombe.

### Option B — Passphrase mixte (diceware + random), splitée

Partie diceware (7 mots + 1 hors liste) dans Bitwarden. Partie random (8+ caractères truly random) dans le Secure Enclave de l'iPhone. LUKS est tout-ou-rien : aucun signal partiel n'indique à l'attaquant qu'il a une partie correcte.

## Décision

Option B. Entropie totale ~158 bits. Chaque moitié seule est inutile en temps humainement pertinent. Un attaquant qui compromet Bitwarden doit encore bruteforcer ~53-66 bits (partie random seule + Argon2id 5s = ~28 500 ans sur un cluster 1000×A100 aujourd'hui). Surfaces d'attaque orthogonales : Bitwarden est un service cloud (attaque réseau), le Secure Enclave est du hardware local (attaque physique).

## Conséquences

La passphrase complète est aussi stockée sur papier dans un coffre physique (chez Émilie ou coffre bancaire) comme filet de sécurité ultime. Recommandation : augmenter la partie random à 10-12 caractères (~66-79 bits résiduels) pour une marge de sécurité sur 30 ans face à un attaquant étatique.
