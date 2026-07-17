#!/bin/bash
# MPMS unified deploy — one script ships BE + FE to either environment.
#
#   ./deploy.sh staging [all|be|fe|dashboard|tablet]   → alblue  (branch: staging)
#   ./deploy.sh pilot   [all|be|fe|dashboard|tablet]   → algreen (branch: main, Mile's production)
#
# Per-environment config lives HERE (not in per-branch files), so a
# `merge staging → main` never conflicts. `.env` (gitignored) supplies the
# deploy host + SSH key; see .env.example.
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$ROOT/.env" ]; then set -a; source "$ROOT/.env"; set +a; fi

TARGET=${1:-}
WHAT=${2:-all}

# Public Sentry DSN (baked into the JS bundle — committing it adds no exposure).
SENTRY_DSN="https://315954545e637502fd5497b3090b5c9c@o4511398917177344.ingest.de.sentry.io/4511398994313296"

case "$TARGET" in
  staging)
    BRANCH=staging
    HOST="${DEPLOY_HOST_STAGING:-}"
    BE_PATH=/opt/alblue/api/ ; BE_SVC=alblue-api
    FE_PATH=/opt/alblue
    DASH_ORIGIN=https://alblue.duckdns.org
    TABLET_ORIGIN=https://alblue-tablet.duckdns.org
    SENTRY_ENV=alblue-staging
    TABLET_OFFLINE="${VITE_OFFLINE_WRITES:-false}"   # staging may flip offline on
    ;;
  pilot)
    BRANCH=main
    HOST="${DEPLOY_HOST_PILOT:-}"
    BE_PATH=/opt/algreen/api/ ; BE_SVC=algreen-api
    FE_PATH=/opt/algreen
    DASH_ORIGIN=https://tracker-api.algreen.rs
    TABLET_ORIGIN=https://tracker-api.algreen.rs
    SENTRY_ENV=algreen-pilot
    TABLET_OFFLINE=false                             # offline stays OFF on the pilot
    ;;
  *)
    echo "Usage: ./deploy.sh [staging|pilot] [all|be|fe|dashboard|tablet]"
    echo "  staging → branch=staging → alblue  (/opt/alblue,  alblue-api)"
    echo "  pilot   → branch=main    → algreen (/opt/algreen, algreen-api) — Mile's production"
    exit 1
    ;;
esac

[ -z "$HOST" ] && { echo "ERROR: deploy host not set — copy .env.example to .env and fill it in."; exit 1; }
DEPLOY_USER="${DEPLOY_USER:-root}"
SSH_KEY_ARG=""; [ -n "${DEPLOY_SSH_KEY:-}" ] && SSH_KEY_ARG="-i ${DEPLOY_SSH_KEY}"
DEST="${DEPLOY_USER}@${HOST}"

[ -n "$(git status --porcelain)" ] && { echo "❌ uncommitted changes — commit or stash before deploying."; exit 1; }

echo "🌿 $BRANCH → $TARGET"
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"
REL=$(git rev-parse --short HEAD)

deploy_be() {
  echo "🔨 BE ($REL)…"
  dotnet publish "$ROOT/be/AlgreenMES.API/AlgreenMES.API.csproj" -c Release -o "$ROOT/be/publish"
  echo "📦 BE → $DEST:$BE_PATH"
  rsync -az --delete --exclude='appsettings.Production.json' --exclude='uploads/' \
    -e "ssh ${SSH_KEY_ARG}" "$ROOT/be/publish/" "$DEST:$BE_PATH"
  echo "🗄️  migrations…"
  if ! ssh ${SSH_KEY_ARG} "$DEST" "cd ${BE_PATH} && ASPNETCORE_ENVIRONMENT=Production dotnet AlgreenMES.API.dll --migrate"; then
    echo "❌ migration failed — new binaries are on disk but $BE_SVC was NOT restarted (old process keeps serving). Fix + redeploy."
    exit 1
  fi
  echo "🔄 restart $BE_SVC"; ssh ${SSH_KEY_ARG} "$DEST" "systemctl restart $BE_SVC"
  echo "✅ BE deployed ($TARGET, $REL)"
}

# $1 = dashboard|tablet   $2 = api origin   $3 = offline flag (tablet only)
build_fe_app() {
  local app=$1 origin=$2 offline=$3
  echo "🔨 FE $app ($REL)…"
  VITE_API_BASE_URL="$origin/api" \
  VITE_SIGNALR_URL="$origin/hubs/production" \
  VITE_OFFLINE_WRITES="$offline" \
  VITE_SENTRY_DSN="$SENTRY_DSN" \
  VITE_SENTRY_ENVIRONMENT="$SENTRY_ENV" \
  VITE_SENTRY_RELEASE="$REL" \
  SENTRY_AUTH_TOKEN="${SENTRY_AUTH_TOKEN:-}" \
  pnpm -C "$ROOT/fe" --filter "$app" build
  echo "📦 FE $app → $DEST:$FE_PATH/$app/"
  rsync -az --delete -e "ssh ${SSH_KEY_ARG}" "$ROOT/fe/apps/$app/dist/" "$DEST:$FE_PATH/$app/"
  echo "✅ $app deployed"
}

case "$WHAT" in
  all)       deploy_be; build_fe_app dashboard "$DASH_ORIGIN" false; build_fe_app tablet "$TABLET_ORIGIN" "$TABLET_OFFLINE" ;;
  be)        deploy_be ;;
  fe)        build_fe_app dashboard "$DASH_ORIGIN" false; build_fe_app tablet "$TABLET_ORIGIN" "$TABLET_OFFLINE" ;;
  dashboard) build_fe_app dashboard "$DASH_ORIGIN" false ;;
  tablet)    build_fe_app tablet "$TABLET_ORIGIN" "$TABLET_OFFLINE" ;;
  *)         echo "Unknown '$WHAT' — use: all | be | fe | dashboard | tablet"; exit 1 ;;
esac

echo "🎉 Done: $TARGET / $WHAT (branch $BRANCH, $REL)"
