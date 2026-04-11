#!/usr/bin/env bash
# safe-rebuild.sh — wrapper nixos-rebuild avec vérification de signature SSH
# ADR 0007 : nixos-rebuild ne vérifie pas les signatures de commit.
# Ce script comble ce trou.
#
# Limites connues (documentées dans RISQUES-RESIDUELS.md) :
# - Replay d'un ancien commit signé : pas de contrôle de monotonie
# - Merge incorporant des parents non signés : seul HEAD est vérifié
# - Empoisonnement flake.lock : non détecté (revue humaine requise)
set -euo pipefail

# Neutraliser les variables d'environnement qui pourraient rediriger git ou nix
unset GIT_DIR GIT_WORK_TREE GIT_CEILING_DIRECTORIES
unset NIXOS_CONFIG NIX_PATH NIX_CONFIG NIX_SSHOPTS NIX_SUDOOPTS

REPO="/data/infra"
ALLOWED_SIGNERS="$REPO/.allowed_signers"
AUDIT_LOG="/var/log/nixos-rebuild-audit.log"
NIXOS_REBUILD="/run/current-system/sw/bin/nixos-rebuild"

# Hash SHA-256 épinglé de .allowed_signers (protection contre modification commitée distante)
# À mettre à jour uniquement lors de l'ajout d'une nouvelle clé autorisée (ex: YubiKey secours)
ALLOWED_SIGNERS_SHA256="72e70e37538525295682c92b21228706d8af6a0eb8a321ac6bebe1dd4edf5e2e"

# Sous-commandes autorisées
ALLOWED_ACTIONS="switch boot test build"
# Sous-commandes qui nécessitent sudo
NEEDS_SUDO="switch boot test"

# Whitelist d'arguments passables à nixos-rebuild
# Tout argument hors de cette liste est refusé
ALLOWED_FLAGS=(
  --show-trace
  --verbose -v
  --no-build-output -Q
  --keep-going -k
  --keep-failed -K
  --max-jobs -j
  --cores
  --print-build-logs -L
  --fallback
  --diff
  --dry-run
  --no-reexec
)

# --- Fonctions utilitaires ---

log_audit() {
  local commit="$1" action="$2" result="$3"
  local entry
  entry="[$(date --iso-8601=seconds)] user=$(id -un) commit=$commit action=$action result=$result"
  echo "$entry" | sudo tee -a "$AUDIT_LOG" >/dev/null
  echo "$entry"
}

die() {
  echo "ERREUR : $1" >&2
  exit 1
}

is_allowed_flag() {
  local arg="$1"
  for allowed in "${ALLOWED_FLAGS[@]}"; do
    # Accepte le flag exact ou le flag suivi de = (ex: --max-jobs=4)
    if [[ "$arg" == "$allowed" || "$arg" == "$allowed="* ]]; then
      return 0
    fi
  done
  # Accepte les valeurs numériques (pour --max-jobs 4, --cores 8)
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    return 0
  fi
  return 1
}

# --- Vérifications préalables ---

[[ -f "$ALLOWED_SIGNERS" ]] || die "$ALLOWED_SIGNERS introuvable"
[[ -x "$NIXOS_REBUILD" ]] || die "$NIXOS_REBUILD introuvable ou non exécutable"

# Vérifier l'intégrité de .allowed_signers (protection contre compromission GitHub)
actual_hash=$(sha256sum "$ALLOWED_SIGNERS" | cut -d' ' -f1)
if [[ "$actual_hash" != "$ALLOWED_SIGNERS_SHA256" ]]; then
  die ".allowed_signers modifié (attendu: ${ALLOWED_SIGNERS_SHA256:0:16}…, obtenu: ${actual_hash:0:16}…). Vérifier manuellement."
fi

cd "$REPO"

# Récupérer et valider la sous-commande
action="${1:-}"
[[ -n "$action" ]] || die "Usage : safe-rebuild.sh <switch|boot|test|build> [options...]"
if [[ " $ALLOWED_ACTIONS " != *" $action "* ]]; then
  die "Sous-commande invalide : '$action'. Autorisées : $ALLOWED_ACTIONS"
fi
shift

# Vérifier chaque argument contre la whitelist
for arg in "$@"; do
  if ! is_allowed_flag "$arg"; then
    die "Argument non autorisé : '$arg'. Seuls les flags de debug/performance sont acceptés."
  fi
done

# Vérifier qu'on est sur une branche (pas en HEAD détaché)
if ! git symbolic-ref HEAD >/dev/null 2>&1; then
  die "HEAD détaché. Checkout une branche avant de rebuild."
fi

# Récupérer le commit HEAD
commit=$(git rev-parse --short HEAD)
commit_full=$(git rev-parse HEAD)

# Vérifier que le repo est propre (fichiers critiques non commités = danger)
if ! git diff --quiet -- '*.nix' 'flake.lock' 'scripts/' '.allowed_signers'; then
  die "Des fichiers critiques ont des modifications non commitées. Commit d'abord."
fi
if ! git diff --cached --quiet -- '*.nix' 'flake.lock' 'scripts/' '.allowed_signers'; then
  die "Des fichiers critiques sont stagés mais non commités. Commit d'abord."
fi

# --- Vérification de signature ---

echo "Vérification de la signature du commit $commit..."

verify_output=$(git -c gpg.ssh.allowedSignersFile="$ALLOWED_SIGNERS" verify-commit "$commit_full" 2>&1) || {
  log_audit "$commit" "$action" "REFUSED"
  echo "$verify_output" >&2
  die "Signature invalide ou absente sur le commit $commit. Rebuild refusé."
}

echo "Signature valide (commit $commit)."

# --- Rebuild (ancré sur le commit vérifié) ---

# ?rev= ancre le build sur le commit exact vérifié (protection TOCTOU)
PINNED_FLAKE="/data/infra?rev=$commit_full#nixos"

echo "Lancement de nixos-rebuild $action (commit $commit)..."
log_audit "$commit" "$action" "STARTED"

if [[ " $NEEDS_SUDO " == *" $action "* ]]; then
  if sudo "$NIXOS_REBUILD" "$action" --flake "$PINNED_FLAKE" "$@"; then
    log_audit "$commit" "$action" "OK"
    echo "Rebuild $action terminé avec succès."
  else
    log_audit "$commit" "$action" "FAILED"
    die "nixos-rebuild $action a échoué."
  fi
else
  if "$NIXOS_REBUILD" "$action" --flake "$PINNED_FLAKE" "$@"; then
    log_audit "$commit" "$action" "OK"
    echo "Rebuild $action terminé avec succès."
  else
    log_audit "$commit" "$action" "FAILED"
    die "nixos-rebuild $action a échoué."
  fi
fi
