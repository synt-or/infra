# 0014 — Dérivation Nix custom pour Claude Code avec vérification GPG

Date : 2026-04-07
Statut : acceptée

## Contexte

Claude Code était installé via `curl | bash` (binaire natif Anthropic) avec `programs.nix-ld.enable = true` pour corriger le linker dynamique. Cette approche posait deux problèmes :

1. **Non reproductible** : le binaire vivait dans `~/.local/share/claude/` hors du contrôle de Nix. Un rebuild ne le reconstruisait pas.
2. **Surface d'attaque** : `nix-ld` place un faux linker à `/lib/ld-linux-aarch64.so.1` au niveau système, permettant à *tout* binaire compilé pour Linux standard de tourner — pas seulement Claude Code.

L'objectif de la Phase 0.5 était de remplacer cette installation impérative par une dérivation Nix déclarative avec vérification cryptographique.

## Options évaluées

### Option A — Utiliser `pkgs.claude-code` de nixpkgs

nixpkgs (unstable) fournit un paquet `claude-code` officiel.

**Avantages :** aucune maintenance, mises à jour via `nixpkgs`.
**Inconvénients :** utilise npm (pas le binaire natif Anthropic), pas de vérification GPG de la signature Anthropic, dépendance à la chaîne npm.

### Option B — Utiliser le flake sadjow/claude-code-nix

Flake communautaire qui télécharge le binaire natif depuis le CDN Anthropic et le patche avec `autoPatchelfHook`.

**Avantages :** binaire natif, multi-plateforme, mis à jour automatiquement.
**Inconvénients :** dépendance à un tiers, pas de vérification GPG — seul un hash statique vérifie l'intégrité sans authentifier l'origine.

### Option C — Dérivation custom dans ce repo (retenue)

Dérivation Nix écrite dans `packages/claude-code/default.nix`, s'appuyant sur trois `fetchurl` (binaire, manifest, signature) et une vérification GPG en `buildPhase`.

**Avantages :** pas de dépendance tierce, chaîne de vérification complète (GPG → manifest → SHA256 binaire), `autoPatchelfHook` corrige le linker d'un seul binaire, supprime `nix-ld`.
**Inconvénients :** mise à jour manuelle de `versions.json` à chaque nouvelle version (un futur `update-claude.sh` automatisera cela — voir tâche 2.4).

## Décision

Option C retenue. C'est la seule approche qui vérifie la chaîne d'authenticité complète :

```
clé GPG Anthropic (commitée dans keys/)
  → vérifie manifest.json.sig
    → extrait SHA256 attendu
      → vérifie le binaire téléchargé
```

La clé GPG Anthropic (fingerprint `31DD DE24 DDFA B679 F42D 7BD2 BAA9 29FF 1A7E CACE`) est vérifiée hors-bande et commitée dans `keys/claude-code.asc`. Toute modification du binaire ou du manifest invalide la signature et fait échouer le build.

## Conséquences

- `programs.nix-ld.enable` supprimé — plus aucun binaire FHS arbitraire ne peut tourner sans dérivation dédiée.
- `~/.local/bin/claude` (ancien symlink) devient obsolète ; le binaire est désormais dans `/run/current-system/sw/bin/claude`.
- `environment.sessionVariables.PATH` nettoyé (le hack `$HOME/.local/bin` supprimé).
- Mises à jour de Claude Code : bumper `version` et les trois SRI hashes dans `packages/claude-code/versions.json`, puis rebuilder.
- Risque résiduel : si Anthropic révoque ou remplace sa clé GPG, le build échoue jusqu'à mise à jour de `keys/claude-code.asc`. C'est le comportement souhaité.
