# Scala 3 Devcontainer

This repository is a ready-to-open Scala 3 development workspace for VS Code Dev
Containers. It gives newcomers the same local environment every time: a JDK,
Scala tools, sbt, Metals editor support, formatting, debugging, and a production
Docker image path.

## Quick Start

Open the folder in VS Code and run **Dev Containers: Reopen in Container**.

Inside the container:

```bash
scala3-compiler -version
sbt run
scala-cli run src/main/scala/Main.scala
```

Build and run the application image:

```bash
docker build -t scala3-devcontainer .
docker run --rm scala3-devcontainer
```

## Mental Model

Scala development in this repository has three layers:

1. The container provides the operating system, JDK, Node.js, Codex, Coursier,
   Scala CLI, sbt, and Metals MCP.
2. The Scala project provides the source code, sbt build definition, dependency
   resolution, packaging, formatting, and debug metadata.
3. VS Code and Metals provide editor features such as diagnostics, go-to
   definition, completion, build import, and debugging.

The important idea is that the editor does not compile Scala by itself. VS Code
talks to Metals, Metals talks to a build server through BSP, and the build
server uses sbt or Scala CLI to compile and understand the project.

## Core Scala Components

### JDK

Scala runs on the JVM, so the Java Development Kit is the foundation of the
whole environment. The devcontainer uses Eclipse Temurin JDK 26. The production
image uses a JDK while building and a smaller JRE while running.

The devcontainer also installs JDK source files into `src.zip` so editor
navigation can jump into Java standard library classes.

### Scala 3

`build.sbt` sets:

```scala
ThisBuild / scalaVersion := "3.8.3"
```

That version is used by sbt for the main project. The container also installs
`scala3-compiler` so you can check the compiler directly.

### sbt

sbt is the main build tool for this repository. It is responsible for:

- reading `build.sbt`
- reading `project/build.properties`
- downloading Scala, plugins, and library dependencies
- compiling code
- running the application with `sbt run`
- packaging the application with `sbt assembly`
- exposing project metadata to Metals through BSP

The project pins sbt in `project/build.properties`:

```properties
sbt.version=1.12.11
```

The devcontainer creates `/usr/local/bin/sbt` as a small Coursier-based wrapper
instead of storing a launcher script in the repository.

### Coursier

Coursier is the dependency and tool installer used by this setup. It downloads
Scala tools and JVM artifacts into the Coursier cache, normally under:

```text
/home/vscode/.cache/coursier
```

The devcontainer uses Coursier to install:

- `scala3-compiler`
- `scala-cli`
- `metals-mcp`
- the sbt launcher used by the `sbt` wrapper

### Scala CLI

Scala CLI is installed for lightweight Scala workflows. It is useful when you
want to run a single file directly:

```bash
scala-cli run src/main/scala/Main.scala
```

In this repository, sbt remains the main project build tool. Scala CLI is a
convenient companion for scripts, experiments, and small examples.

### Metals

Metals is the Scala language server. It powers the Scala experience in VS Code:

- diagnostics
- completion
- go-to definition
- symbol search
- code actions
- build import
- debug integration

The VS Code extension `scalameta.metals` starts and communicates with Metals.
The devcontainer settings give Metals a larger heap and tell it to use the build
tool as the default BSP source.

### BSP

BSP means Build Server Protocol. It is the bridge between Metals and the build
tool.

`/.bsp/sbt.json` tells tools how to start sbt in BSP mode. When Metals imports
the build, it can ask sbt for compile targets, classpaths, source directories,
compiler options, and diagnostics.

You usually do not edit `.bsp` files by hand. They are generated build-tool
metadata and are ignored by git in this repository.

### Scalafmt

`.scalafmt.conf` configures formatting:

```hocon
version = "3.10.7"
runner.dialect = scala3
```

VS Code has `editor.formatOnSave` enabled in the devcontainer settings, so Scala
files are formatted automatically when the formatter is available.

### SemanticDB

`build.sbt` enables SemanticDB:

```scala
ThisBuild / semanticdbEnabled := true
```

SemanticDB stores semantic information about Scala code. Tools such as Metals
use this information for richer navigation, references, and code intelligence.

## Project Files

### `src/main/scala/Main.scala`

This is the example Scala 3 application. It defines a top-level `@main` method:

```scala
@main def hello(): Unit =
  println("Hello from Scala 3 in a devcontainer. It works!")
  anotherFunction()
```

The generated main class is named `hello`, which is why the sbt assembly and
VS Code launch configuration both reference `hello`.

### `build.sbt`

This is the main sbt build definition. It sets:

- Scala version `3.8.3`
- SemanticDB support
- project name and version
- the assembly main class
- the assembly output JAR name

### `project/build.properties`

This pins the sbt version. Pinning sbt matters because sbt behavior and plugin
compatibility can change between versions.

### `project/plugins.sbt`

This adds sbt plugins. The current plugin is:

```scala
addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "2.3.1")
```

`sbt-assembly` builds one runnable JAR containing the application and its
runtime dependencies.

### `.vscode/launch.json`

This defines the VS Code debug target named `hello`. It uses the Scala debug
adapter through Metals and points at the sbt build target:

```json
"mainClass": "hello"
```

Use this when you want breakpoints and a debugger instead of a terminal run.

### `.vscode/settings.json`

This keeps VS Code from watching `target` directories. Build output changes
frequently, and excluding it reduces editor noise and file-watcher load.

## Devcontainer Files

### `.devcontainer/devcontainer.json`

This is the entry point for VS Code Dev Containers. It defines:

- the devcontainer name
- the Dockerfile used for the development environment
- the remote user, `vscode`
- startup and creation commands
- mounted host directories for SSH and Codex config
- VS Code extensions
- VS Code and Metals settings

Important lifecycle commands:

- `initializeCommand` runs on the host before the container starts. It prepares
  writable build and editor directories.
- `postCreateCommand` runs after the container is created. It verifies installed
  tools and warms sbt dependencies.
- `postStartCommand` runs each time the container starts. It repairs permissions,
  syncs config, and starts Metals MCP.

### `.devcontainer/Dockerfile`

This builds the interactive development environment. It installs:

- Eclipse Temurin JDK 26
- basic OS tools such as Git, curl, SSH, sudo, and gzip
- Node.js 26
- the Codex CLI through npm
- a non-root `vscode` user
- JDK sources for editor navigation
- Coursier
- Scala compiler, Scala CLI, Metals MCP, and an sbt wrapper

It also warms expensive sbt downloads so the first project import is faster.

### `.devcontainer/post-start.sh`

This script makes the container usable after each start. It handles:

- Git user configuration
- marking the workspace as a safe Git directory
- workspace permission repair
- Coursier wrapper repair if tools point at the wrong cache
- Metals MCP installation checks
- SSH config sync from the host mount
- Codex config sync from the host mount
- Codex MCP configuration for Metals
- starting `metals-mcp` on port `8421`

Most environment variables at the top of the script are override points. For
example, `METALS_MCP_PORT`, `START_METALS_MCP`, `GIT_USER_NAME`, and
`GIT_USER_EMAIL` can be changed without editing the script.

## Production Dockerfile

The repository root `Dockerfile` is separate from the devcontainer Dockerfile.
It builds a runnable application image, not an editor environment.

It has two stages:

1. `build`: installs Coursier and sbt, copies build metadata, downloads
   dependencies, copies sources, and runs `sbt assembly`.
2. runtime: starts from a smaller JRE image, copies `app.jar`, and runs it with
   `java -jar`.

This separation keeps the production image focused on running the application
instead of carrying development tools.

## Generated And Ignored Directories

The following directories are generated by tools and should normally not be
edited manually:

- `.bsp/`: build server connection files
- `.metals/`: Metals workspace data and logs
- `.scala-build/`: Scala CLI build data
- `target/`: sbt and compiler output
- `project/target/`: sbt build-project output
- `project/project/`: nested sbt build metadata

They are ignored by `.gitignore`. `.dockerignore` also excludes them from Docker
build context so images do not include local build caches or editor state.

## Common Commands

```bash
# Run the sbt project
sbt run

# Compile the sbt project
sbt compile

# Run tests, once tests exist
sbt test

# Build the runnable assembly JAR
sbt assembly

# Run the single Scala file with Scala CLI
scala-cli run src/main/scala/Main.scala

# Check installed tool versions
java -version
scala3-compiler -version
scala-cli --version
sbt sbtVersion
```

## Troubleshooting

If Metals does not import the build, run:

```bash
sbt compile
```

Then use the VS Code command **Metals: Import build**.

If generated directories have permission problems, restart the devcontainer.
The startup script repairs ownership and write permissions for the common build
directories.

If Codex cannot reach Metals MCP, check:

```bash
cat .metals/mcp/metals-mcp.log
```

The default MCP endpoint is:

```text
http://127.0.0.1:8421/mcp
```
