FROM eclipse-temurin:26-jdk-noble

ARG USERNAME=vscode
ARG NODE_MAJOR=26
ARG JDK_SOURCES_URL=https://github.com/adoptium/temurin26-binaries/releases/download/jdk-26%2B35/OpenJDK26U-jdk-sources_26_35.tar.gz
ARG JDK_SOURCES_SHA256=f2efe308f37809127c96eb73ffba2d2484013aac18777d09079cea39091f0d08

# Base OS tools used by git, VS Code, NodeSource, and setup scripts.
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      gnupg \
      gzip \
      openssh-client \
      sudo \
    && rm -rf /var/lib/apt/lists/*

# Node.js is installed from NodeSource so Codex can be installed with npm.
RUN install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g @openai/codex \
    && rm -rf /var/lib/apt/lists/*

# The devcontainer runs as a non-root sudo user, matching VS Code defaults.
RUN useradd --create-home --shell /bin/bash "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
    && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
    && mkdir -p "/home/${USERNAME}/.sbt" "/home/${USERNAME}/.cache/coursier" \
    && chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.sbt" "/home/${USERNAME}/.cache"

# Add JDK source files for editor navigation.
RUN set -eux; \
    curl -fsSL "$JDK_SOURCES_URL" -o /tmp/jdk-sources.tar.gz; \
    echo "$JDK_SOURCES_SHA256  /tmp/jdk-sources.tar.gz" | sha256sum -c -; \
    mkdir -p /tmp/jdk-sources /tmp/jdk-srczip; \
    tar -xzf /tmp/jdk-sources.tar.gz -C /tmp/jdk-sources --strip-components=1; \
    for classes in /tmp/jdk-sources/src/*/share/classes; do \
      module="$(basename "$(dirname "$(dirname "$classes")")")"; \
      mkdir -p "/tmp/jdk-srczip/$module"; \
      cp -R "$classes"/. "/tmp/jdk-srczip/$module"/; \
    done; \
    cd /tmp/jdk-srczip; \
    jar --create --file /opt/java/openjdk/lib/src.zip .; \
    rm -rf /tmp/jdk-sources /tmp/jdk-srczip /tmp/jdk-sources.tar.gz

# Install Coursier, then use it for Scala tools and an sbt wrapper.
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
    COURSIER_CACHE="/home/${USERNAME}/.cache/coursier" cs install scala3-compiler scala-cli metals-mcp --install-dir /usr/local/bin; \
    printf '%s\n' '#!/usr/bin/env sh' 'export COURSIER_CACHE="${COURSIER_CACHE:-/home/vscode/.cache/coursier}"' 'exec /usr/local/bin/cs launch sbt -- "$@"' > /usr/local/bin/sbt; \
    chmod +x /usr/local/bin/sbt; \
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.cache" || true

USER ${USERNAME}

# Fail the build early if the installed language-server bridge is broken.
RUN metals-mcp --version

# Warm the most expensive sbt downloads used by the template project.
RUN COURSIER_CACHE="/home/${USERNAME}/.cache/coursier" \
    cs fetch org.scala-sbt:sbt-launch:1.12.11 io.get-coursier.sbt:sbt-runner:0.2.0 >/dev/null
