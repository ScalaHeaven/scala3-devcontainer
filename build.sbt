ThisBuild / scalaVersion := "3.8.3"

ThisBuild / semanticdbEnabled := true

lazy val root = (project in file("."))
  .settings(
    name := "scala3-devcontainer",
    version := "0.1.0-SNAPSHOT",
    assembly / mainClass := Some("hello"),
    assembly / assemblyJarName := "app.jar"
  )
