# AGENTS.md

Guidance for coding agents working in this repository.

## Repository Purpose

This repository is a ready-to-open Scala 3 development workspace for VS Code Dev
Containers. It provides:

- a Scala 3 sbt project with a small example application
- a devcontainer image with JDK 26, Node.js, Codex, Coursier, Scala CLI, sbt,
  Metals, and Metals MCP
- VS Code settings for Scala editing, formatting, and debugging
- a production Dockerfile that builds a runnable assembly JAR

Treat this as both a Scala project template and a dev environment definition.
Changes often affect onboarding, editor behavior, or reproducible builds, not
just application code.

## Important Files

- `build.sbt`: main sbt build definition. Pins Scala `3.8.3`, enables
  SemanticDB, sets project metadata, and configures `sbt-assembly`.
- `project/build.properties`: pins sbt `1.12.11`.
- `project/plugins.sbt`: declares sbt plugins, currently `sbt-assembly`.
- `src/main/scala/Main.scala`: example Scala 3 application with the `hello`
  main class.
- `.scalafmt.conf`: Scala formatting config, using Scalafmt `3.10.7` and the
  Scala 3 dialect.
- `.devcontainer/devcontainer.json`: VS Code Dev Containers entry point.
- `.devcontainer/Dockerfile`: development image definition.
- `.devcontainer/post-start.sh`: repairs workspace permissions, syncs selected
  host SSH/Codex files, configures Git, configures Codex Metals MCP, and starts
  Metals MCP.
- `.vscode/launch.json`: Metals/Scala debug launch config for `hello`.
- `.vscode/settings.json`: editor settings, including watcher excludes.
- `Dockerfile`: production multi-stage build that runs `sbt assembly` and
  launches `target/scala-3.8.3/app.jar`.
- `README.md`: user-facing explanation of the environment and workflows.

## Build And Validation Commands

Run sbt commands serially. Starting multiple sbt processes at the same time can
hit the sbt boot socket lock and fail with `ServerAlreadyBootingException`.

Use these commands from the repository root:

```bash
sbt -Dsbt.batch=true compile
sbt -Dsbt.batch=true run
sbt -Dsbt.batch=true assembly
scala-cli run src/main/scala/Main.scala
docker build -t scala3-devcontainer .
docker run --rm scala3-devcontainer
```

For formatting, prefer the configured Scala formatter:

```bash
scala-cli fmt --check src/main/scala/Main.scala
scala-cli fmt src/main/scala/Main.scala
```

The repository has `.scalafmt.conf` but does not currently add the sbt-scalafmt
plugin, so do not assume `sbt scalafmtAll` is available.

## Coding Guidelines

- Follow idiomatic Scala 3 syntax and keep examples simple unless the task asks
  for a broader application.
- Preserve the top-level `@main` entry point or update every dependent reference
  when renaming it, including `build.sbt`, `.vscode/launch.json`, `README.md`,
  and Docker-related documentation.
- Keep `build.sbt` small and declarative. Add dependencies or plugins only when
  they support the requested behavior.
- Keep devcontainer scripts idempotent. They are run on creation and on start,
  so repeated execution must be safe.
- Preserve non-root `vscode` user behavior in container changes unless the task
  explicitly requires a different model.
- Prefer Coursier-based tool installation patterns already used in the
  devcontainer and production Dockerfile.
- Keep Docker layer ordering cache-friendly: copy build metadata before source
  files when dependency resolution can be cached.
- Update `README.md` whenever commands, tool versions, startup behavior, or the
  mental model for users changes.

## Generated And Local Files

Do not hand-edit generated or local state unless specifically investigating tool
behavior:

- `.bsp/`
- `.metals/`
- `target/`
- `project/target/`
- `.scala-build/`
- `.bloop/`

These paths may be present in a working tree because Metals, sbt, or Scala CLI
created them. Avoid committing generated build output.

## Current Capabilities

The repository currently supports:

- compiling and running a Scala 3 app with sbt
- running the single source file with Scala CLI
- producing a fat JAR with `sbt-assembly`
- building and running a production Docker image
- editing and debugging Scala through VS Code Metals
- exposing Metals MCP to Codex from inside the devcontainer
- syncing selected host SSH and Codex configuration into the container
- repairing common ownership and permission issues after container startup

It does not currently include a test framework or `src/test` tree. If adding
behavior with meaningful logic, add a test framework deliberately and document
the new test command here and in `README.md`.

## Verification Notes

At the time this file was added, these commands passed:

```bash
sbt -Dsbt.batch=true compile
sbt -Dsbt.batch=true assembly
scala-cli fmt --check src/main/scala/Main.scala
```

JDK 26 emits warnings about deprecated/restricted JVM APIs while sbt starts.
Those warnings are expected for this setup and are not application compile
failures.
