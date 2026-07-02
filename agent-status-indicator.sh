#!/usr/bin/env bash
set -euo pipefail

umask 077

DEFAULT_HOME="$HOME/Library/Application Support/AgentStatusIndicator"
LEGACY_HOME="$HOME/Library/Application Support/CodexAccountSwitcher"
if [[ ! -d "$DEFAULT_HOME" && -d "$LEGACY_HOME" ]]; then
  mkdir -p "$(dirname "$DEFAULT_HOME")"
  mv "$LEGACY_HOME" "$DEFAULT_HOME" 2>/dev/null || true
fi

AGENT_STATUS_INDICATOR_HOME="${AGENT_STATUS_INDICATOR_HOME:-$DEFAULT_HOME}"
ACCOUNT_SERVICE="${ACCOUNT_SERVICE:-codex}"
CLAUDE_DEFAULT_APP_SUPPORT="$HOME/Library/Application Support/Claude-3p"
if [[ ! -d "$CLAUDE_DEFAULT_APP_SUPPORT" && -d "$HOME/Library/Application Support/Claude" ]]; then
  CLAUDE_DEFAULT_APP_SUPPORT="$HOME/Library/Application Support/Claude"
fi

case "$ACCOUNT_SERVICE" in
  codex)
    SERVICE_TITLE="Codex"
    SERVICE_HOME="$AGENT_STATUS_INDICATOR_HOME"
    PROFILES_DIR="$AGENT_STATUS_INDICATOR_HOME/profiles"
    ACTIVE_FILE="$AGENT_STATUS_INDICATOR_HOME/active-profile"
    APP_NAME="${CODEX_APP_NAME:-Codex}"
    AUTH_FILE="${CODEX_AUTH_FILE:-$HOME/.codex/auth.json}"
    APP_SUPPORT="${CODEX_APP_SUPPORT:-$HOME/Library/Application Support/Codex}"
    PROFILE_AUTH_BASENAME="auth.json"
    PROFILE_APP_SUPPORT_DIRNAME="Codex"
    REQUIRE_AUTH_FILE=1
    ;;
  claude)
    SERVICE_TITLE="Claude"
    SERVICE_HOME="$AGENT_STATUS_INDICATOR_HOME/services/claude"
    PROFILES_DIR="$SERVICE_HOME/profiles"
    ACTIVE_FILE="$SERVICE_HOME/active-profile"
    APP_NAME="${CLAUDE_APP_NAME:-Claude}"
    AUTH_FILE="${CLAUDE_AUTH_FILE:-$HOME/.claude.json}"
    APP_SUPPORT="${CLAUDE_APP_SUPPORT:-$CLAUDE_DEFAULT_APP_SUPPORT}"
    PROFILE_AUTH_BASENAME="claude.json"
    PROFILE_APP_SUPPORT_DIRNAME="$(basename "$APP_SUPPORT")"
    REQUIRE_AUTH_FILE=0
    ;;
  *)
    printf 'error: unsupported ACCOUNT_SERVICE: %s\n' "$ACCOUNT_SERVICE" >&2
    exit 1
    ;;
esac

LOCK_DIR="$SERVICE_HOME/.lock"

usage() {
  cat <<'USAGE'
Agent Status Indicator

Usage:
  ACCOUNT_SERVICE=codex|claude agent-status-indicator.sh capture <profile>
  ACCOUNT_SERVICE=codex|claude agent-status-indicator.sh switch <profile> [--no-open]
  ACCOUNT_SERVICE=codex|claude agent-status-indicator.sh delete <profile>
  ACCOUNT_SERVICE=codex|claude agent-status-indicator.sh list [--plain]
  ACCOUNT_SERVICE=codex|claude agent-status-indicator.sh active
  ACCOUNT_SERVICE=codex|claude agent-status-indicator.sh open-folder

Environment overrides:
  AGENT_STATUS_INDICATOR_HOME  Profile storage directory
  ACCOUNT_SERVICE              codex or claude, default codex
  CODEX_AUTH_FILE              Codex CLI auth file, default ~/.codex/auth.json
  CODEX_APP_SUPPORT            Codex Desktop state directory, default ~/Library/Application Support/Codex
  CODEX_APP_NAME               macOS app name, default Codex
  CLAUDE_AUTH_FILE             Claude auth file, default ~/.claude.json
  CLAUDE_APP_SUPPORT           Claude state directory, default ~/Library/Application Support/Claude-3p when present
  CLAUDE_APP_NAME              macOS app name, default Claude
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '%s\n' "$*" >&2
}

ensure_store() {
  mkdir -p "$PROFILES_DIR"
}

with_lock() {
  ensure_store
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    fail "another switch is already running"
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
}

validate_profile_name() {
  local name="${1:-}"
  [[ -n "$name" ]] || fail "profile name is required"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || \
    fail "profile name may only contain letters, numbers, dot, dash, and underscore"
}

profile_dir() {
  printf '%s/%s\n' "$PROFILES_DIR" "$1"
}

profile_auth_file() {
  printf '%s/auth/%s\n' "$(profile_dir "$1")" "$PROFILE_AUTH_BASENAME"
}

profile_app_support_dir() {
  printf '%s/app-support/%s\n' "$(profile_dir "$1")" "$PROFILE_APP_SUPPORT_DIRNAME"
}

active_profile() {
  if [[ -f "$ACTIVE_FILE" ]]; then
    sed -n '1p' "$ACTIVE_FILE"
  fi
}

copy_file_if_present() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$src" ]]; then
    cp -p "$src" "$dst"
    chmod 600 "$dst" 2>/dev/null || true
  else
    rm -f "$dst"
  fi
}

assert_safe_sync_target() {
  local dst="$1"
  case "$dst" in
    ""|"/"|"$HOME"|"$HOME/"|"$HOME/Library"|"$HOME/Library/Application Support")
      fail "refusing to sync into unsafe target: $dst"
      ;;
  esac
}

sync_dir_if_present() {
  local src="$1"
  local dst="$2"
  assert_safe_sync_target "$dst"

  if [[ -d "$src" && -d "$dst" ]]; then
    local src_real dst_real
    src_real="$(cd "$src" && pwd -P)"
    dst_real="$(cd "$dst" && pwd -P)"
    [[ "$src_real" != "$dst_real" ]] || fail "refusing to sync a directory onto itself: $src"
  fi

  mkdir -p "$(dirname "$dst")"
  if [[ ! -d "$src" ]]; then
    rm -rf "$dst"
    return 0
  fi

  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --checksum --delete \
      --exclude 'Cache/' \
      --exclude 'Code Cache/' \
      --exclude 'Crashpad/' \
      --exclude 'DawnGraphiteCache/' \
      --exclude 'DawnWebGPUCache/' \
      --exclude 'GPUCache/' \
      "$src"/ "$dst"/
  else
    local tmp="$dst.tmp.$$"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    cp -pR "$src"/. "$tmp"/
    rm -rf "$dst"
    mv "$tmp" "$dst"
  fi
}

capture_into_profile() {
  local name="$1"
  validate_profile_name "$name"
  ensure_store

  local dir
  dir="$(profile_dir "$name")"
  mkdir -p "$dir/auth" "$dir/app-support"

  copy_file_if_present "$AUTH_FILE" "$(profile_auth_file "$name")"
  sync_dir_if_present "$APP_SUPPORT" "$(profile_app_support_dir "$name")"

  {
    printf 'name=%s\n' "$name"
    printf 'service=%s\n' "$ACCOUNT_SERVICE"
    printf 'captured_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'auth_file=%s\n' "$AUTH_FILE"
    printf 'app_support=%s\n' "$APP_SUPPORT"
  } > "$dir/profile.env"
}

cmd_capture() {
  local name="${1:-}"
  validate_profile_name "$name"
  with_lock
  log "quitting $APP_NAME before capture"
  quit_target_app
  capture_into_profile "$name"
  printf '%s\n' "$name" > "$ACTIVE_FILE"
  log "captured current $SERVICE_TITLE state as '$name'"
}

quit_target_app() {
  /usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  for _ in {1..40}; do
    if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  log "warning: $APP_NAME is still running; continuing anyway"
}

restore_profile() {
  local name="$1"
  local auth_src app_src
  auth_src="$(profile_auth_file "$name")"
  app_src="$(profile_app_support_dir "$name")"

  [[ -d "$(profile_dir "$name")" ]] || fail "profile '$name' does not exist"

  if [[ -f "$auth_src" ]]; then
    mkdir -p "$(dirname "$AUTH_FILE")"
    cp -p "$auth_src" "$AUTH_FILE"
    chmod 600 "$AUTH_FILE" 2>/dev/null || true
  elif [[ "$REQUIRE_AUTH_FILE" == "1" ]]; then
    fail "profile '$name' has no saved auth file; capture it after logging in"
  else
    log "warning: profile '$name' has no saved auth file; restoring app state only"
  fi

  if [[ -d "$app_src" ]]; then
    sync_dir_if_present "$app_src" "$APP_SUPPORT"
  elif [[ ! -f "$auth_src" ]]; then
    fail "profile '$name' has no saved auth file or app state"
  else
    log "warning: profile '$name' has no $SERVICE_TITLE app state; only auth was restored"
  fi
}

cmd_switch() {
  local name="${1:-}"
  local no_open="${2:-}"
  validate_profile_name "$name"
  [[ "$no_open" == "" || "$no_open" == "--no-open" ]] || fail "unknown option: $no_open"

  with_lock

  local current
  current="$(active_profile || true)"
  if [[ -z "$current" ]]; then
    fail "no active profile is recorded; run 'capture <profile>' for the current account first"
  fi
  validate_profile_name "$current"

  log "quitting $APP_NAME"
  quit_target_app

  if [[ "$current" != "$name" ]]; then
    log "saving current $SERVICE_TITLE state into '$current'"
    capture_into_profile "$current"
  fi

  log "switching to '$name'"
  restore_profile "$name"
  printf '%s\n' "$name" > "$ACTIVE_FILE"

  if [[ "$no_open" != "--no-open" ]]; then
    log "opening $APP_NAME"
    /usr/bin/open -a "$APP_NAME" >/dev/null 2>&1 || log "warning: could not open $APP_NAME"
  fi
}

cmd_list() {
  local plain="${1:-}"
  [[ "$plain" == "" || "$plain" == "--plain" ]] || fail "unknown option: $plain"
  ensure_store
  local active
  active="$(active_profile || true)"

  find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort | while IFS= read -r dir; do
    local name
    name="$(basename "$dir")"
    if [[ "$plain" == "--plain" ]]; then
      printf '%s\n' "$name"
    elif [[ "$name" == "$active" ]]; then
      printf '* %s\n' "$name"
    else
      printf '  %s\n' "$name"
    fi
  done
}

cmd_delete() {
  local name="${1:-}"
  validate_profile_name "$name"
  ensure_store

  local dir active
  dir="$(profile_dir "$name")"
  [[ -d "$dir" ]] || fail "profile '$name' does not exist"

  active="$(active_profile || true)"
  if [[ "$name" == "$active" ]]; then
    fail "cannot delete the active profile '$name'; switch accounts first"
  fi

  case "$dir" in
    "$PROFILES_DIR"/*) ;;
    *) fail "refusing to delete unsafe profile path: $dir" ;;
  esac

  rm -rf "$dir"
  log "deleted $SERVICE_TITLE profile '$name'"
}

cmd_active() {
  active_profile || true
}

cmd_open_folder() {
  ensure_store
  /usr/bin/open "$SERVICE_HOME"
}

main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    capture) cmd_capture "$@" ;;
    switch) cmd_switch "$@" ;;
    delete) cmd_delete "$@" ;;
    list) cmd_list "$@" ;;
    active) cmd_active ;;
    open-folder) cmd_open_folder ;;
    -h|--help|help|"") usage ;;
    *) fail "unknown command: $command" ;;
  esac
}

main "$@"
