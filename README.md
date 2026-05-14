# Scala 3 Devcontainer

This workspace is initialized for Scala 3 development in a VS Code devcontainer.

## Included

- Java 21 base image
- sbt
- Scala CLI
- Metals extension for VS Code
- Minimal Scala 3 sbt project

## Try It

Open the folder in VS Code and choose **Dev Containers: Reopen in Container**.

Inside the container:

```bash
sbt run
scala-cli run src/main/scala/Main.scala
```

## Run With Docker

Build and run the application image:

```bash
docker build -t scala3-devcontainer .
docker run --rm scala3-devcontainer
```
