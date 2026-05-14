FROM eclipse-temurin:21-jdk-noble

ARG USERNAME=vscode

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends curl gzip ca-certificates git openssh-client sudo gnupg \
    && install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && useradd --create-home --shell /bin/bash "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
    && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
    && npm install -g @openai/codex \
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
    cs install scala3 scala3-compiler scala-cli sbt --install-dir /usr/local/bin; \
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.cache" || true

USER ${USERNAME}

RUN mkdir -p "/home/${USERNAME}/.sbt" "/home/${USERNAME}/.cache/coursier"
