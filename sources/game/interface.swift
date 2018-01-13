import GLFW
import OpenGL

protocol GameScene
{
    //var frame:Size2D { get }
    mutating
    func show3D(_:Double)
    mutating func onResize(newFrame:Math<CInt>.V2)
    mutating func press(_ position:Math<Double>.V2, button:Interface.MouseButton)
    mutating func drag(_ position:Math<Double>.V2, anchor:Interface.MouseAnchor)
    mutating func release()
    mutating func scroll(axis:Bool, sign:Bool)
    mutating func key(_:Interface.PhysicalKey)

    func destroy()
}

// use reference type because we want to attach `self` pointer to GLFW
final
class Interface
{
    enum PhysicalKey:CInt
    {
        case unknown = -1,
             space   = 32,
             period  = 46,
             esc     = 256,
             enter,
             tab,
             backspace,
             insert,
             delete,
             right,
             left,
             down,
             up,

             zero = 48, one, two, three, four, five, six, seven, eight, nine,

             f1 = 290, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
    }

    enum MouseButton
    {
        case left, middle, right

        init?(_ buttonCode:CInt)
        {
            switch buttonCode
            {
            case GLFW_MOUSE_BUTTON_LEFT:
                self = .left
            case GLFW_MOUSE_BUTTON_MIDDLE:
                self = .middle
            case GLFW_MOUSE_BUTTON_RIGHT:
                self = .right
            default:
                return nil
            }
        }
    }

    struct MouseAnchor
    {
        let position:Math<Double>.V2,
            button:MouseButton
    }

    private
    let window:OpaquePointer
    private
    var size:Math<CInt>.V2,
        mouseAnchor:MouseAnchor?,
        scenes:[GameScene]

    init(size:Math<CInt>.V2, name:String)
    {
        guard let window:OpaquePointer = glfwCreateWindow(size.x, size.y, name, nil, nil)
        else
        {
            fatalError("glfwCreateWindow failed")
        }

        glfwMakeContextCurrent(window)
        glfwSwapInterval(1)

        self.window = window
        self.size   = size
        self.scenes = [View3D(frame: size)]

        // attach pointer to self to window
        glfwSetWindowUserPointer(window,
            UnsafeMutableRawPointer(Unmanaged<Interface>.passUnretained(self).toOpaque()))

        glfwSetFramebufferSizeCallback(window)
        {
            (window:OpaquePointer?, width:CInt, height:CInt) in

            glViewport(0, 0, width, height)
            Interface.reconstitute(from: window).resizeTo((width, height))
        }

        glfwSetKeyCallback(window)
        {
            (window:OpaquePointer?, key:CInt, scancode:CInt, action:CInt, mods:CInt) in

            guard action == GLFW_PRESS
            else
            {
                return
            }

            guard let physicalKey:PhysicalKey = PhysicalKey(rawValue: key)
            else
            {
                print("invalid key \(key)")
                return
            }

            Interface.reconstitute(from: window).key(physicalKey)
        }
        glfwSetCharCallback(window)
        {
            (window:OpaquePointer?, codepoint:CUnsignedInt) in
        }

        glfwSetCursorPosCallback(window)
        {
            (window:OpaquePointer?, x:Double, y:Double) in

            Interface.reconstitute(from: window).hover((x, -y))
        }

        glfwSetMouseButtonCallback(window)
        {
            (window:OpaquePointer?, button:CInt, action:CInt, mods:CInt) in

            let interface:Interface = Interface.reconstitute(from: window)
            if action == GLFW_PRESS
            {
                var position:Math<Double>.V2 = (0, 0)
                glfwGetCursorPos(window, &position.x, &position.y)
                position.y = -position.y

                guard let mouseButton:MouseButton = MouseButton(button)
                else
                {
                    print("invalid mouse button \(button)")
                    return
                }

                interface.press(position, button: mouseButton)
            }
            else // if action == GLFW_RELEASE
            {
                interface.release()
            }
        }

        glfwSetScrollCallback(window)
        {
            (window:OpaquePointer?, xoffset:Double, yoffset:Double) in

            Interface.reconstitute(from: window)
                .scroll(axis: yoffset != 0, sign: (xoffset + yoffset) == 1)
        }
    }

    deinit
    {
        for i in self.scenes.indices
        {
            self.scenes[i].destroy()
        }
        glfwDestroyWindow(self.window)
    }

    func play()
    {
        glBlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA,
                            GL.ONE_MINUS_DST_ALPHA, GL.ONE)
        glEnable(GL.BLEND)

        var t0:Double = glfwGetTime()
        while glfwWindowShouldClose(self.window) == 0
        {
            glfwPollEvents()
            glClearColor(0.1, 0.1, 0.1, 1)
            glClear(mask: GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT)

            let t1:Double = glfwGetTime()
            let dt:Double = t1 - t0
            for i in self.scenes.indices
            {
                self.scenes[i].show3D(dt)
            }
            t0 = t1

            glfwSwapBuffers(self.window)
        }
    }

    fileprivate
    func resizeTo(_ size:Math<CInt>.V2)
    {
        self.size = size
        for i in self.scenes.indices
        {
            self.scenes[i].onResize(newFrame: size)
        }
    }

    private
    func scroll(axis:Bool, sign:Bool)
    {
        self.scenes[0].scroll(axis: axis, sign: sign)
    }

    private
    func hover(_ position:Math<Double>.V2)
    {
        if let mouseAnchor = self.mouseAnchor
        {
            self.scenes[0].drag(position, anchor: mouseAnchor)
        }
    }

    private
    func press(_ position:Math<Double>.V2, button:MouseButton)
    {
        self.mouseAnchor = MouseAnchor(position: position, button: button)
        self.scenes[0].press(position, button: button)
    }

    private
    func release()
    {
        self.scenes[0].release()
        self.mouseAnchor = nil
    }

    private
    func key(_ key:PhysicalKey)
    {
        self.scenes[0].key(key)
    }

    private static
    func reconstitute(from window:OpaquePointer?) -> Interface
    {
        return Unmanaged<Interface>.fromOpaque(glfwGetWindowUserPointer(window)).takeUnretainedValue()
    }
}

/*
func read_gl_errors(hide:Bool = false)
{
    while true
    {
        let e = SGLOpenGL.glGetError()
        if e == SGLOpenGL.GL_NO_ERROR
        {
            break
        }
        else if !hide
        {
            print(String(e, radix: 16))
        }
    }
}
*/
