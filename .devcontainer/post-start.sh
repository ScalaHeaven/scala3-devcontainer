#!/usr/bin/env bash
set -euo pipefail

workspace=/workspaces/scala3-devcontainer

git config --global user.name "Yehor Smoliakov"
git config --global user.email "egorsmkv@gmail.com"

sudo chown -R vscode:vscode "$workspace"
mkdir -p "$workspace/.metals"

mkdir -p /home/vscode/.ssh
if [ -d /tmp/host-ssh ]; then
  sudo cp /tmp/host-ssh/id_ed25519 /tmp/host-ssh/id_ed25519.pub /home/vscode/.ssh/ 2>/dev/null || true
  sudo cp /tmp/host-ssh/known_hosts /home/vscode/.ssh/ 2>/dev/null || true
fi
sudo chown -R vscode:vscode /home/vscode/.ssh
chmod 700 /home/vscode/.ssh
chmod 600 /home/vscode/.ssh/id_ed25519 2>/dev/null || true
chmod 644 /home/vscode/.ssh/id_ed25519.pub /home/vscode/.ssh/known_hosts 2>/dev/null || true

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
