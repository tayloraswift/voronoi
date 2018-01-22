import GLFW

func main()
{
    guard glfwInit() == 1
    else
    {
        fatalError("glfwInit() failed")
    }
    defer { glfwTerminate() }

    glfwSetErrorCallback
    {
        (error:CInt, description:UnsafePointer<CChar>?) in

        if let description = description
        {
            print("Error \(error): \(String(cString: description))")
        }
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_ANY_PROFILE)
    glfwWindowHint(GLFW_RESIZABLE, 1)
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, 1)
    glfwWindowHint(GLFW_SAMPLES, 4)

    let interface:Interface = Interface(size: (1200, 600), name: "Diannamy 3")

    interface.play()
}

main()
