# 0002 — Hibernation écartée, s2idle + shutdown retenu

Date : 2026-04-04
Statut : acceptée

## Contexte

La clé LUKS reste en RAM pendant le fonctionnement. L'hibernation (suspend-to-disk) aurait permis de l'effacer à chaque suspension. Mais deux contraintes indépendantes l'empêchent.

## Options évaluées

### Option A — Hibernation

`CONFIG_HIBERNATION` est désactivé dans le kernel Asahi (décision volontaire de l'équipe). Et `lockdown=confidentiality` (prévu en Phase 1) bloque l'hibernation même si elle existait (patches de signature d'image jamais mergés upstream, pas de TPM2 sur Apple Silicon). Double blocage indépendant.

### Option B — Shutdown sur fermeture du couvercle

La clé LUKS disparaît de la RAM à chaque fermeture. Perte de session à chaque fois.

### Option C — s2idle + shutdown automatique après timeout

Absences courtes : s2idle (clé en RAM, espace utilisateur gelé). Absences longues : shutdown après 30 min d'inactivité (clé disparaît).

## Décision

Option C retenue. Justification formelle : le risque résiduel en s2idle (exploit kernel 0-day) est un sous-ensemble strict du risque déjà accepté en fonctionnement normal. La clé est dans la même position en RAM, mais l'espace utilisateur est gelé (surface d'attaque réduite). Les protections hardware (SiP élimine le cold boot) et software (lockdown bloque l'extraction userspace, DART bloque le DMA) rendent ce risque acceptable.

## Conséquences

Le shutdown automatique après 30 min borne la durée d'exposition. L'hibernation est en veille technique — si Asahi l'active et que les patches lockdown/hibernation sont mergés, le modèle sera réévalué.
