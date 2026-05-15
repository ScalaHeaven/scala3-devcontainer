#!/usr/bin/env bash
set -euo pipefail

# Configuration
WORKSPACE="${WORKSPACE:-/workspaces/scala3-devcontainer}"
DEV_USER="${DEV_USER:-vscode}"
DEV_GROUP="${DEV_GROUP:-$DEV_USER}"
DEV_HOME="${DEV_HOME:-/home/$DEV_USER}"

GIT_USER_NAME="${GIT_USER_NAME:-Yehor Smoliakov}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-egorsmkv@gmail.com}"

HOST_SSH_DIR="${HOST_SSH_DIR:-/tmp/host-ssh}"
HOST_CODEX_DIR="${HOST_CODEX_DIR:-/tmp/host-codex}"
SSH_DIR="${SSH_DIR:-$DEV_HOME/.ssh}"
CODEX_DIR="${CODEX_DIR:-$DEV_HOME/.codex}"
COURSIER_CACHE="${COURSIER_CACHE:-$DEV_HOME/.cache/coursier}"

START_METALS_MCP="${START_METALS_MCP:-1}"
METALS_MCP_PORT="${METALS_MCP_PORT:-8421}"
METALS_MCP_TRANSPORT="${METALS_MCP_TRANSPORT:-http}"
METALS_MCP_BUILD_TOOL="${METALS_MCP_BUILD_TOOL:-sbt}"
METALS_MCP_STARTUP_WAIT_SECONDS="${METALS_MCP_STARTUP_WAIT_SECONDS:-30}"
CODEX_MCP_STARTUP_TIMEOUT_SECONDS="${CODEX_MCP_STARTUP_TIMEOUT_SECONDS:-30}"
CODEX_MCP_TOOL_TIMEOUT_SECONDS="${CODEX_MCP_TOOL_TIMEOUT_SECONDS:-120}"

SBT_VERSION="${SBT_VERSION:-1.12.11}"
SBT_RUNNER_VERSION="${SBT_RUNNER_VERSION:-0.2.0}"

BIN_DIR="${BIN_DIR:-/usr/local/bin}"
CS_BIN="${CS_BIN:-$BIN_DIR/cs}"
CODEX_CONFIG="${CODEX_CONFIG:-$CODEX_DIR/config.toml}"
METALS_MCP_DIR="${METALS_MCP_DIR:-$WORKSPACE/.metals/mcp}"
METALS_MCP_PID="${METALS_MCP_PID:-$METALS_MCP_DIR/metals-mcp.pid}"
METALS_MCP_LOG="${METALS_MCP_LOG:-$METALS_MCP_DIR/metals-mcp.log}"

SSH_FILES=(
  config
  known_hosts
  known_hosts.old
  id_ed25519
  id_ed25519.pub
  id_rsa
  id_rsa.pub
  id_ecdsa
  id_ecdsa.pub
)

CODEX_FILES=(
  auth.json
  config.toml
  installation_id
  models_cache.json
)

ensure_dir() {
  sudo mkdir -p "$@"
}

own_path() {
  sudo chown -R "$DEV_USER:$DEV_GROUP" "$@" 2>/dev/null || true
}

chmod_path() {
  sudo chmod -R "$@" 2>/dev/null || true
}

copy_files_from_dir() {
  local src_dir="$1"
  local dest_dir="$2"
  shift 2

  [ -d "$src_dir" ] || return 0
  ensure_dir "$dest_dir"

  local file
  for file in "$@"; do
    sudo cp "$src_dir/$file" "$dest_dir/" 2>/dev/null || true
  done
}

repair_workspace_permissions() {
  ensure_dir \
    "$WORKSPACE/.metals" \
    "$WORKSPACE/.bsp" \
    "$WORKSPACE/target" \
    "$WORKSPACE/project/target"

  sudo find "$WORKSPACE" -type d -name .scala-build -prune -exec rm -rf {} + 2>/dev/null || true
  own_path "$WORKSPACE"
  sudo find "$WORKSPACE" -type d -exec chmod u+rwx {} + 2>/dev/null || true
  sudo find "$WORKSPACE" -type f -exec chmod u+rw {} + 2>/dev/null || true
  sudo find "$WORKSPACE" \
    \( -type d -name .bloop -o -type d -name .scala-build -o -type d -name target \) \
    -prune -exec chown -R "$DEV_USER:$DEV_GROUP" {} + 2>/dev/null || true
  sudo find "$WORKSPACE" \
    \( -type d -name .bloop -o -type d -name .scala-build -o -type d -name target \) \
    -prune -exec chmod -R u+rwX {} + 2>/dev/null || true
  own_path \
    "$WORKSPACE/.git" \
    "$WORKSPACE/.metals" \
    "$WORKSPACE/.bsp" \
    "$WORKSPACE/target" \
    "$WORKSPACE/project/target"
  chmod_path u+rwX \
    "$WORKSPACE/.git" \
    "$WORKSPACE/.metals" \
    "$WORKSPACE/.bsp" \
    "$WORKSPACE/target" \
    "$WORKSPACE/project/target"
}

configure_git() {
  git config --global user.name "$GIT_USER_NAME"
  git config --global user.email "$GIT_USER_EMAIL"
  git config --global --add safe.directory "$WORKSPACE"
}

install_sbt_wrapper() {
  printf '%s\n' \
    '#!/usr/bin/env sh' \
    "export COURSIER_CACHE=\"\${COURSIER_CACHE:-$COURSIER_CACHE}\"" \
    "exec $CS_BIN launch sbt -- \"\$@\"" \
    | sudo tee "$BIN_DIR/sbt" >/dev/null
  sudo chmod +x "$BIN_DIR/sbt"
}

install_coursier_tools() {
  ensure_dir "$COURSIER_CACHE"
  sudo env COURSIER_CACHE="$COURSIER_CACHE" \
    "$CS_BIN" install "$@" --install-dir "$BIN_DIR"
  own_path "$DEV_HOME/.cache"
}

repair_root_coursier_wrappers() {
  if ! grep -q '/root/.cache/coursier' \
    "$BIN_DIR/scala3" \
    "$BIN_DIR/scala3-compiler" \
    "$BIN_DIR/scala-cli" \
    "$BIN_DIR/sbt" \
    2>/dev/null; then
    return 0
  fi

  sudo rm -f \
    "$BIN_DIR/scala3" \
    "$BIN_DIR/scala3-compiler" \
    "$BIN_DIR/scala-cli" \
    "$BIN_DIR/sbt" \
    "$BIN_DIR/metals-mcp"
  install_coursier_tools scala3-compiler scala-cli metals-mcp
  install_sbt_wrapper
}

ensure_metals_mcp_installed() {
  if command -v metals-mcp >/dev/null 2>&1; then
    return 0
  fi

  install_coursier_tools metals-mcp
}

sync_ssh_config() {
  ensure_dir "$SSH_DIR"
  copy_files_from_dir "$HOST_SSH_DIR" "$SSH_DIR" "${SSH_FILES[@]}"
  own_path "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  chmod 600 "$SSH_DIR/config" "$SSH_DIR/id_ed25519" "$SSH_DIR/id_rsa" "$SSH_DIR/id_ecdsa" 2>/dev/null || true
  chmod 644 \
    "$SSH_DIR/id_ed25519.pub" \
    "$SSH_DIR/id_rsa.pub" \
    "$SSH_DIR/id_ecdsa.pub" \
    "$SSH_DIR/known_hosts" \
    "$SSH_DIR/known_hosts.old" \
    2>/dev/null || true

  if ! ssh-keygen -F github.com -f "$SSH_DIR/known_hosts" >/dev/null 2>&1; then
    ssh-keyscan github.com >> "$SSH_DIR/known_hosts" 2>/dev/null || true
  fi
}

sync_codex_config() {
  ensure_dir "$CODEX_DIR"
  copy_files_from_dir "$HOST_CODEX_DIR" "$CODEX_DIR" "${CODEX_FILES[@]}"
  own_path "$CODEX_DIR"
  chmod 700 "$CODEX_DIR"
  chmod 600 "$CODEX_DIR/auth.json" "$CODEX_DIR/config.toml" 2>/dev/null || true
  chmod 644 "$CODEX_DIR/installation_id" "$CODEX_DIR/models_cache.json" 2>/dev/null || true
}

configure_codex_metals_mcp() {
  ensure_dir "$(dirname "$CODEX_CONFIG")"
  touch "$CODEX_CONFIG"
  local tmp_codex_config
  tmp_codex_config="$(mktemp)"

  awk '
    /^\[mcp_servers\.metals\]$/ { skip = 1; next }
    /^\[[^]]+\]$/ { skip = 0 }
    !skip { print }
  ' "$CODEX_CONFIG" > "$tmp_codex_config"
  cat "$tmp_codex_config" > "$CODEX_CONFIG"
  rm -f "$tmp_codex_config"

  cat >> "$CODEX_CONFIG" <<EOF

[mcp_servers.metals]
url = "http://127.0.0.1:${METALS_MCP_PORT}/mcp"
enabled = true
startup_timeout_sec = ${CODEX_MCP_STARTUP_TIMEOUT_SECONDS}
tool_timeout_sec = ${CODEX_MCP_TOOL_TIMEOUT_SECONDS}
EOF
  chmod 600 "$CODEX_CONFIG"
}

metals_mcp_is_listening() {
  curl -sS --max-time 2 "http://127.0.0.1:${METALS_MCP_PORT}/mcp" >/dev/null 2>&1
}

warm_sbt_cache() {
  COURSIER_CACHE="$COURSIER_CACHE" \
    "$CS_BIN" fetch \
      "org.scala-sbt:sbt-launch:$SBT_VERSION" \
      "io.get-coursier.sbt:sbt-runner:$SBT_RUNNER_VERSION" \
      >/dev/null || true
}

start_metals_mcp() {
  mkdir -p "$METALS_MCP_DIR"

  if [ "$START_METALS_MCP" != "1" ]; then
    return 0
  fi

  if [ -f "$METALS_MCP_PID" ] \
    && kill -0 "$(cat "$METALS_MCP_PID")" 2>/dev/null \
    && metals_mcp_is_listening; then
    return 0
  fi

  warm_sbt_cache
  rm -f "$METALS_MCP_PID"
  setsid sh -c '
    exec </dev/null
    exec metals-mcp \
      --workspace "$1" \
      --port "$2" \
      --transport "$3" \
      --target-build-tool "$4" \
      --default-bsp-to-build-tool \
      --auto-import-builds all
  ' sh "$WORKSPACE" "$METALS_MCP_PORT" "$METALS_MCP_TRANSPORT" "$METALS_MCP_BUILD_TOOL" \
    >"$METALS_MCP_LOG" 2>&1 &
  echo "$!" > "$METALS_MCP_PID"

  local _
  for _ in $(seq 1 "$METALS_MCP_STARTUP_WAIT_SECONDS"); do
    if metals_mcp_is_listening; then
      return 0
    fi
    if ! kill -0 "$(cat "$METALS_MCP_PID")" 2>/dev/null; then
      break
    fi
    sleep 1
  done

  printf 'metals-mcp did not start on port %s; see %s\n' "$METALS_MCP_PORT" "$METALS_MCP_LOG" >&2
  return 1
}

main() {
  configure_git
  repair_workspace_permissions
  repair_root_coursier_wrappers
  ensure_metals_mcp_installed
  sync_ssh_config
  sync_codex_config
  configure_codex_metals_mcp
  start_metals_mcp
}

main "$@"
