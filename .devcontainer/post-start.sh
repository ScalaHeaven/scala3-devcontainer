#!/usr/bin/env bash
set -euo pipefail

workspace=/workspaces/scala3-devcontainer

repair_workspace_permissions() {
  sudo mkdir -p "$workspace/.metals" "$workspace/.bsp" "$workspace/target" "$workspace/project/target"
  sudo find "$workspace" -type d -name .scala-build -prune -exec rm -rf {} + 2>/dev/null || true
  sudo chown -R vscode:vscode "$workspace" 2>/dev/null || true
  sudo find "$workspace" -type d -exec chmod u+rwx {} + 2>/dev/null || true
  sudo find "$workspace" -type f -exec chmod u+rw {} + 2>/dev/null || true
  sudo find "$workspace" \
    \( -type d -name .bloop -o -type d -name .scala-build -o -type d -name target \) \
    -prune -exec chown -R vscode:vscode {} + 2>/dev/null || true
  sudo find "$workspace" \
    \( -type d -name .bloop -o -type d -name .scala-build -o -type d -name target \) \
    -prune -exec chmod -R u+rwX {} + 2>/dev/null || true
  sudo chown -R vscode:vscode \
    "$workspace/.git" \
    "$workspace/.metals" \
    "$workspace/.bsp" \
    "$workspace/target" \
    "$workspace/project/target" \
    2>/dev/null || true
  sudo chmod -R u+rwX \
    "$workspace/.git" \
    "$workspace/.metals" \
    "$workspace/.bsp" \
    "$workspace/target" \
    "$workspace/project/target" \
    2>/dev/null || true
}

git config --global user.name "Yehor Smoliakov"
git config --global user.email "egorsmkv@gmail.com"
git config --global --add safe.directory "$workspace"

repair_workspace_permissions

if grep -q '/root/.cache/coursier' /usr/local/bin/scala3 /usr/local/bin/scala3-compiler /usr/local/bin/scala-cli /usr/local/bin/sbt 2>/dev/null; then
  sudo rm -f /usr/local/bin/scala3 /usr/local/bin/scala3-compiler /usr/local/bin/scala-cli /usr/local/bin/sbt /usr/local/bin/metals-mcp
  sudo mkdir -p /home/vscode/.cache/coursier
  sudo env COURSIER_CACHE=/home/vscode/.cache/coursier \
    cs install scala3-compiler scala-cli metals-mcp --install-dir /usr/local/bin
  printf '%s\n' '#!/usr/bin/env sh' \
    'export COURSIER_CACHE="${COURSIER_CACHE:-/home/vscode/.cache/coursier}"' \
    'exec /usr/local/bin/cs launch sbt -- "$@"' | sudo tee /usr/local/bin/sbt >/dev/null
  sudo chmod +x /usr/local/bin/sbt
  sudo chown -R vscode:vscode /home/vscode/.cache
fi

if ! command -v metals-mcp >/dev/null 2>&1; then
  sudo mkdir -p /home/vscode/.cache/coursier
  sudo env COURSIER_CACHE=/home/vscode/.cache/coursier \
    cs install metals-mcp --install-dir /usr/local/bin
  sudo chown -R vscode:vscode /home/vscode/.cache
fi

mkdir -p /home/vscode/.ssh
if [ -d /tmp/host-ssh ]; then
  for file in \
    config \
    known_hosts \
    known_hosts.old \
    id_ed25519 \
    id_ed25519.pub \
    id_rsa \
    id_rsa.pub \
    id_ecdsa \
    id_ecdsa.pub; do
    sudo cp "/tmp/host-ssh/$file" /home/vscode/.ssh/ 2>/dev/null || true
  done
fi
sudo chown -R vscode:vscode /home/vscode/.ssh
chmod 700 /home/vscode/.ssh
chmod 600 /home/vscode/.ssh/config /home/vscode/.ssh/id_ed25519 /home/vscode/.ssh/id_rsa /home/vscode/.ssh/id_ecdsa 2>/dev/null || true
chmod 644 /home/vscode/.ssh/id_ed25519.pub /home/vscode/.ssh/id_rsa.pub /home/vscode/.ssh/id_ecdsa.pub /home/vscode/.ssh/known_hosts /home/vscode/.ssh/known_hosts.old 2>/dev/null || true
if ! ssh-keygen -F github.com -f /home/vscode/.ssh/known_hosts >/dev/null 2>&1; then
  ssh-keyscan github.com >> /home/vscode/.ssh/known_hosts 2>/dev/null || true
fi

mkdir -p /home/vscode/.codex
if [ -d /tmp/host-codex ]; then
  for file in auth.json config.toml installation_id models_cache.json; do
    sudo cp "/tmp/host-codex/$file" /home/vscode/.codex/ 2>/dev/null || true
  done
fi
sudo chown -R vscode:vscode /home/vscode/.codex
chmod 700 /home/vscode/.codex
chmod 600 /home/vscode/.codex/auth.json /home/vscode/.codex/config.toml 2>/dev/null || true
chmod 644 /home/vscode/.codex/installation_id /home/vscode/.codex/models_cache.json 2>/dev/null || true

metals_mcp_port=8421
codex_config=/home/vscode/.codex/config.toml
touch "$codex_config"
tmp_codex_config="$(mktemp)"
awk '
  /^\[mcp_servers\.metals\]$/ { skip = 1; next }
  /^\[[^]]+\]$/ { skip = 0 }
  !skip { print }
' "$codex_config" > "$tmp_codex_config"
cat "$tmp_codex_config" > "$codex_config"
rm -f "$tmp_codex_config"
cat >> "$codex_config" <<EOF

[mcp_servers.metals]
url = "http://127.0.0.1:${metals_mcp_port}/mcp"
enabled = true
startup_timeout_sec = 30
tool_timeout_sec = 120
EOF
chmod 600 "$codex_config"

metals_mcp_dir="$workspace/.metals/mcp"
metals_mcp_pid="$metals_mcp_dir/metals-mcp.pid"
metals_mcp_log="$metals_mcp_dir/metals-mcp.log"
mkdir -p "$metals_mcp_dir"

metals_mcp_is_listening() {
  curl -sS --max-time 2 "http://127.0.0.1:${metals_mcp_port}/mcp" >/dev/null 2>&1
}

if [ "${START_METALS_MCP:-1}" != "1" ]; then
  exit 0
fi

if [ -f "$metals_mcp_pid" ] && kill -0 "$(cat "$metals_mcp_pid")" 2>/dev/null && metals_mcp_is_listening; then
  exit 0
fi

COURSIER_CACHE=/home/vscode/.cache/coursier \
  cs fetch org.scala-sbt:sbt-launch:1.12.11 io.get-coursier.sbt:sbt-runner:0.2.0 >/dev/null || true

rm -f "$metals_mcp_pid"
setsid sh -c '
  exec </dev/null
  exec metals-mcp \
    --workspace "$1" \
    --port "$2" \
    --transport http \
    --target-build-tool sbt \
    --default-bsp-to-build-tool \
    --auto-import-builds all
' sh "$workspace" "$metals_mcp_port" >"$metals_mcp_log" 2>&1 &
echo "$!" > "$metals_mcp_pid"

for _ in $(seq 1 30); do
  if metals_mcp_is_listening; then
    exit 0
  fi
  if ! kill -0 "$(cat "$metals_mcp_pid")" 2>/dev/null; then
    break
  fi
  sleep 1
done

printf 'metals-mcp did not start on port %s; see %s\n' "$metals_mcp_port" "$metals_mcp_log" >&2
exit 1
