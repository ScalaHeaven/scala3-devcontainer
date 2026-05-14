FROM eclipse-temurin:26-jdk AS build

WORKDIR /app

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends curl gzip ca-certificates \
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
    cs install sbt --install-dir /usr/local/bin

COPY project ./project
COPY build.sbt ./
RUN sbt update

COPY src ./src
RUN sbt assembly

FROM eclipse-temurin:26-jre

WORKDIR /app

COPY --from=build /app/target/scala-3.8.3/app.jar ./app.jar

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
