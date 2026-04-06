-----

## name: new-adr
description: Créer une nouvelle Architecture Decision Record dans doc/adr/
argument-hint: [titre-court-de-la-decision]

# Créer une ADR

Les ADR documentent les décisions architecturales significatives du projet. Une décision est significative si elle affecte la sécurité, la structure du système, ou si elle est difficilement réversible.

## Workflow

1. Lister les ADR existantes : `ls doc/adr/`
1. Prendre le prochain numéro disponible (format 4 chiffres : 0001, 0002, …)
1. Créer le fichier `doc/adr/NNNN-titre-en-kebab-case.md` avec le template ci-dessous
1. Commit signé avec le message `docs: ADR NNNN — titre`

## Template

```markdown
# NNNN — Titre de la décision

Date : YYYY-MM-DD
Statut : acceptée | rejetée | remplacée par NNNN

## Contexte

Quel problème ou quelle question a motivé cette décision ? Quel était le contexte technique et les contraintes connues ?

## Options évaluées

### Option A — Nom
Description. Avantages et inconvénients.

### Option B — Nom
Description. Avantages et inconvénients.

## Décision

Quelle option a été retenue et pourquoi ?

## Conséquences

Qu'est-ce que cette décision implique ? Quels risques résiduels ? Quelles actions futures ?
```

## Règles

- Ne jamais modifier une ADR existante pour changer la décision. Créer une nouvelle ADR avec le statut “remplacée par NNNN” et mettre à jour le statut de l’ancienne.
- Le statut `rejetée` est utilisé pour documenter des options évaluées et explicitement écartées (utile pour ne pas les réévaluer à l’avenir).
- Écrire en français.