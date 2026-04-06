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

## Analyse d'entropie

La passphrase est composée de deux parties concaténées.

**Partie diceware :** 7 mots de la liste EFF (7776 mots, log₂(7776) ≈ 12.9 bits par mot = ~90.3 bits) + 1 mot absent de la liste (conservativement un mot anglais courant parmi ~50 000, log₂(50000) ≈ 15.6 bits). Total partie diceware : **~106 bits**.

**Partie random :** 8 caractères truly random sur l'alphabet ASCII imprimable (95 caractères, log₂(95) ≈ 6.6 bits par caractère = ~52.6 bits). Total partie random : **~53 bits**.

**Total : ~158 bits d'entropie.** Au-delà du seuil post-quantique (128 bits après réduction par Grover).

### Résistance résiduelle si Bitwarden est compromis

Si la partie diceware est exposée, la sécurité repose sur la partie random seule. Avec 8 caractères random (~53 bits) et Argon2id à 5 secondes par tentative :

- **Aujourd'hui** : un cluster de 1000 GPU A100 (80 Go VRAM chacun, ~80 000 tentatives/seconde grâce à la résistance mémoire d'Argon2id) mettrait environ **28 500 ans**. Suffisant.
- **2056, attaquant étatique** (~10⁹ tentatives/seconde) : **~2.3 ans**. Insuffisant.

### Recommandation

Augmenter la partie random à 10-12 caractères (~66-79 bits résiduels), déjà prévu en Phase 2 (voir TODO.md) :

- 10 caractères (~66 bits) : attaquant étatique 2056 → ~29 000 ans
- 12 caractères (~79 bits) : attaquant étatique 2056 → ~30 milliards d'années

### Contexte physique (limite de Landauer)

Effacer un bit d'information coûte au minimum kT·ln(2) ≈ 2.85 × 10⁻²¹ joules à température ambiante. Bruteforcer 2²⁵⁶ clés nécessiterait au minimum ~3.3 × 10⁵⁶ joules — environ 2.75 × 10²² fois la production énergétique annuelle du Soleil. C'est une impossibilité physique, pas computationnelle. La passphrase complète de 158 bits est dans cette zone.

## Conséquences

La passphrase complète est aussi stockée sur papier dans un coffre physique (chez Émilie ou coffre bancaire) comme filet de sécurité ultime. Recommandation : augmenter la partie random à 10-12 caractères (~66-79 bits résiduels) pour une marge de sécurité sur 30 ans face à un attaquant étatique.
