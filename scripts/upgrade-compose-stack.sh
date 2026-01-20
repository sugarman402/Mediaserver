#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.yaml"

# Check dependencies
for cmd in yq jq curl; do
  command -v "$cmd" >/dev/null || { echo "❌ $cmd not found"; exit 1; }
done
yq --version | grep -q 'version v4' || { echo "❌ yq v4 required"; exit 1; }

# Backup and start
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.bak.$(date +%s)"
echo "📦 Backup created"
echo "🔍 Processing services..."

# Exclusion patterns for filtering tags
EXCLUDE_PATTERN='(alpha|beta|rc[0-9]?|dev|nightly|edge|test|preview|canary|experimental|windows|nanoserver|servercore|ltsc|amd64|arm64|arm32|armv[67]|ppc64le|s390x|i386|386|riscv64|alpine|ubuntu|debian|bullseye|bookworm|buster|jammy|focal|bionic|react[0-9]+|no-new-use-public-image)'

# Extract best semantic version tag from a list, preserving 'v' prefix if present
pick_best_tag() {
  local all_tags="$1"
  local clean_tag has_v
  
  # Try clean semver first (X.Y.Z or X.Y.Z-N)
  clean_tag=$(echo "$all_tags" | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?$' | sed 's/^v//' | sort -V | tail -n1)
  
  if [[ -n "$clean_tag" ]]; then
    has_v=$(echo "$all_tags" | grep -E "^v${clean_tag}$" || true)
    echo "${has_v:-$clean_tag}"
    return
  fi
  
  # Fallback: looser version match with exclusions
  echo "$all_tags" | grep -E '^v?[0-9]+\.[0-9]+' | grep -vE "$EXCLUDE_PATTERN" | sort -V | tail -n1 || echo ""
}

# Fetch tags from various registries
fetch_tags() {
  local registry="$1" repo="$2"
  
  case "$registry" in
    docker.io)
      [[ "$repo" != */* ]] && repo="library/$repo"
      curl -fsSL "https://registry.hub.docker.com/v2/repositories/${repo}/tags?page_size=100" 2>/dev/null | jq -r '.results[].name'
      ;;
    ghcr.io)
      local image="${repo#ghcr.io/}"
      local token=$(curl -fsSL "https://ghcr.io/token?scope=repository:${image}:pull" 2>/dev/null | jq -r '.token // empty')
      local auth_header=""
      [[ -n "$token" ]] && auth_header="Authorization: Bearer $token"
      curl -fsSL ${auth_header:+-H "$auth_header"} "https://ghcr.io/v2/${image}/tags/list" 2>/dev/null | jq -r '.tags[]?'
      ;;
    gcr.io)
      local image="${repo#gcr.io/}"
      curl -fsSL "https://gcr.io/v2/${image}/tags/list" 2>/dev/null | jq -r '.manifest | to_entries[].value.tag[]?' 2>/dev/null
      ;;
    quay.io)
      local image="${repo#quay.io/}"
      curl -fsSL "https://quay.io/api/v1/repository/${image}/tag/" 2>/dev/null | jq -r '.tags[].name'
      ;;
    *)
      return 1
      ;;
  esac
}

# Version comparison (returns 0 if v1 < v2)
version_lt() {
  local v1="${1#v}" v2="${2#v}"
  [[ "$(printf '%s\n%s' "$v1" "$v2" | sort -V | head -n1)" == "$v1" && "$v1" != "$v2" ]]
}

# Parse image into registry, repo, tag
parse_image() {
  local image="$1"
  local repo="${image%:*}" tag="${image##*:}"
  [[ "$image" != *":"* ]] && tag="latest"
  
  local registry="docker.io"
  [[ "$repo" =~ ^([^/]+)/.+/.+ ]] && registry="${BASH_REMATCH[1]}"
  
  echo "$registry" "$repo" "$tag"
}

# Main loop
for service in $(yq -r '.services | keys[]' "$COMPOSE_FILE"); do
  image=$(yq -r ".services.$service.image" "$COMPOSE_FILE")
  [[ "$image" == "null" ]] && continue

  read -r registry repo current_tag <<<"$(parse_image "$image")"
  
  if [[ "$current_tag" == "latest" ]]; then
    echo "ℹ️  $service: Skipping latest tag"
    continue
  fi

  all_tags=$(fetch_tags "$registry" "$repo" 2>/dev/null) || {
    echo "⚠️  $service: Unsupported registry ($registry)"
    continue
  }

  latest_tag=$(pick_best_tag "$all_tags")
  
  if [[ -z "$latest_tag" ]]; then
    echo "⚠️  $service: Unable to fetch tags"
    continue
  fi
  
  if [[ "$latest_tag" == "$current_tag" ]]; then
    echo "ℹ️  $service: Up-to-date ($current_tag)"
    continue
  fi
  
  if ! version_lt "$current_tag" "$latest_tag"; then
    echo "⚠️  $service: Not downgrading ($current_tag → $latest_tag)"
    continue
  fi

  echo "✅ $service: $current_tag → $latest_tag"
  yq -i ".services.$service.image = \"${repo}:${latest_tag}\"" "$COMPOSE_FILE"
done

echo "🎉 Upgrade complete"
docker compose pull && docker compose up -d

echo "🧹 Removing unused images..."
docker image prune -af
