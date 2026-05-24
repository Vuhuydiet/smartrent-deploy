#!/usr/bin/env bash
# Droplet Docker cleanup — safe to run on production server.
#
# What it does:
#   1. Removes stopped containers
#   2. For each smartrent image repo, keeps only the N newest tags
#      (always preserves :dev and :latest moving tags, plus any tag
#      currently used by a running container)
#   3. Prunes dangling images
#   4. Prunes builder cache but keeps the last 2GB hot
#   5. Reports disk usage before and after
#
# What it does NOT do (intentionally):
#   - Does NOT touch volumes (MySQL/Redis data lives there)
#   - Does NOT remove images currently in use by a running container
#   - Does NOT prune networks
#
# Usage:
#   ./droplet-cleanup.sh              # dry-run, shows what would be deleted
#   ./droplet-cleanup.sh --apply      # actually deletes
#   KEEP=10 ./droplet-cleanup.sh      # keep last 10 tags per repo (default: 5)

set -euo pipefail

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
fi

KEEP="${KEEP:-5}"
REPOS=(
  "vuhuydiet/smartrent-ai"
  "vuhuydiet/smartrent-backend"
  "vuhuydiet/smartrent-scraper"
)
# Tags that move (latest, dev, prd, etc.) — never delete these
PROTECTED_TAGS_REGEX='^(dev|prd|prod|main|latest)$'

log() { printf '\033[1;36m[cleanup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
run() {
  if [[ $APPLY -eq 1 ]]; then
    "$@"
  else
    printf '\033[1;90m  (dry-run)\033[0m %s\n' "$*"
  fi
}

if [[ $APPLY -eq 0 ]]; then
  warn "DRY-RUN mode. Re-run with --apply to actually delete."
fi

log "Disk usage BEFORE:"
docker system df
echo

# 1. Stopped containers
log "Pruning stopped containers..."
if [[ $APPLY -eq 1 ]]; then
  docker container prune -f
else
  docker container ls -a --filter status=exited --filter status=created --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}'
fi
echo

# 2. Per-repo tag retention
# Get tags in use by any container (running or stopped) so we never break them
IN_USE_IMAGES="$(docker ps -a --format '{{.Image}}' | sort -u)"

for repo in "${REPOS[@]}"; do
  log "Repo: $repo — keeping $KEEP newest tags (+ protected: dev/prd/prod/main/latest + in-use)"

  # List tags for this repo, newest first, format: "<tag> <image-id>"
  mapfile -t entries < <(
    docker images "$repo" --format '{{.Tag}}|{{.ID}}|{{.CreatedAt}}' \
      | grep -v '^<none>|' \
      | sort -t'|' -k3,3r \
      | awk -F'|' '{print $1"|"$2}'
  )

  if [[ ${#entries[@]} -eq 0 ]]; then
    log "  (no images for $repo)"
    continue
  fi

  log "  Found ${#entries[@]} tagged images"

  kept=0
  for entry in "${entries[@]}"; do
    tag="${entry%%|*}"
    id="${entry##*|}"
    full="${repo}:${tag}"

    # Always keep protected moving tags
    if [[ "$tag" =~ $PROTECTED_TAGS_REGEX ]]; then
      log "  KEEP  $full (protected tag)"
      continue
    fi

    # Always keep images currently used by a container
    if echo "$IN_USE_IMAGES" | grep -qx "$full"; then
      log "  KEEP  $full (in use by a container)"
      continue
    fi

    # Keep the N newest non-protected, non-in-use tags
    if [[ $kept -lt $KEEP ]]; then
      log "  KEEP  $full (recent)"
      kept=$((kept + 1))
      continue
    fi

    log "  DROP  $full"
    run docker rmi "$full" || warn "    failed to remove $full (might be referenced elsewhere)"
  done
  echo
done

# 3. Dangling images (untagged layers left over after builds/pulls)
log "Pruning dangling images..."
if [[ $APPLY -eq 1 ]]; then
  docker image prune -f
else
  docker images --filter dangling=true --format 'table {{.ID}}\t{{.Repository}}\t{{.Size}}'
fi
echo

# 4. Build cache — keep 2GB hot so future builds aren't ice-cold
log "Pruning builder cache (keeping 2GB hot)..."
if [[ $APPLY -eq 1 ]]; then
  docker builder prune -f --keep-storage 2GB
else
  docker builder prune --keep-storage 2GB
fi
echo

log "Disk usage AFTER:"
docker system df
echo

if [[ $APPLY -eq 0 ]]; then
  warn "This was a DRY-RUN. Re-run with --apply to actually delete:"
  warn "  ./droplet-cleanup.sh --apply"
fi

log "Done."
