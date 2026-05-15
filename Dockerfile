ARG SCALA_BINARY_VERSION=3.8.3

FROM eclipse-temurin:26-jdk AS build

WORKDIR /app

# Install the small set of OS tools needed to download Coursier.
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gzip \
    && rm -rf /var/lib/apt/lists/*

# Install Coursier, then use it to install sbt.
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
    cs install sbt --install-dir /usr/local/bin

# Copy build metadata first so Docker can cache dependency downloads.
COPY project ./project
COPY build.sbt ./
RUN sbt update

# Copy application sources last; this is the layer that changes most often.
COPY src ./src
RUN sbt assembly

FROM eclipse-temurin:26-jre

WORKDIR /app

ARG SCALA_BINARY_VERSION

COPY --from=build /app/target/scala-${SCALA_BINARY_VERSION}/app.jar ./app.jar

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
