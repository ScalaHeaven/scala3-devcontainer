FROM mcr.microsoft.com/devcontainers/java:1-21-bookworm

ARG USERNAME=vscode

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends curl gzip ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) coursier_arch="x86_64-pc-linux" ;; \
      arm64) coursier_arch="aarch64-pc-linux" ;; \
      *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fL "https://github.com/coursier/coursier/releases/latest/download/cs-${coursier_arch}.gz" \
      | gzip -d > /usr/local/bin/cs; \
    chmod +x /usr/local/bin/cs; \
    cs install scala-cli sbt --install-dir /usr/local/bin; \
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.cache" || true

USER ${USERNAME}

RUN mkdir -p "/home/${USERNAME}/.sbt" "/home/${USERNAME}/.cache/coursier"
