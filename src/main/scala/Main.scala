def anotherFunction(): Unit =
  println("This is another function that can be called from the main function.")

@main def hello(): Unit =
  println("Hello from Scala 3 in a devcontainer. It works!")
  anotherFunction()
