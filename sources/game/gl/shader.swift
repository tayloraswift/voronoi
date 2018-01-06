import Glibc
import OpenGL

struct Program
{
    enum ShaderType
    {
        case vertex, geometry, fragment
    }

    private
    enum CompilationStep
    {
        case compile(GL.UInt), link(GL.UInt)
    }

    private
    let id:GL.UInt,
        uniforms:[GL.Int]

    static
    func create(shaders shaderSources:[(path:String, type:ShaderType)],
        uniforms:[String] = [], textures:[String] = []) -> Program?
    {
        guard let shaders:[GL.UInt] = compileShaders(shaderSources)
        else
        {
            return nil
        }

        // link program
        let program:GL.UInt   = glCreateProgram()
        for shader in shaders
        {
            glAttachShader(program, shader)
            defer
            {
                glDeleteShader(shader)
            }
        }

        glLinkProgram(program)
        // always read the log for now
        printLog(step: .link(program))

        let programName:String =
            "{\(shaderSources.map{ $0.path }.joined(separator: ", "))}"
        guard check(step: .link(program))
        else
        {
            print("program compilation failed (\(programName))")

            glDeleteProgram(program) // cleanup
            return nil
        }

        print("program compilation succeeded (\(programName))")

        for shader in shaders
        {
            glDetachShader(program, shader)
        }

        // attempt to find standard uniform blocks in program and set them to
        // point to the right global binding points
        glUniformBlockBinding(program: program,
            uniformBlockIndex: glGetUniformBlockIndex(program, "CameraMatrixBlock"),
            uniformBlockBinding: 0)
        glUniformBlockBinding(program: program,
            uniformBlockIndex: glGetUniformBlockIndex(program, "CameraDataBlock"),
            uniformBlockBinding: 1)

        glUseProgram(program)

        for (i, texture):(Int, String) in textures.enumerated()
        {
            let location:GL.Int = glGetUniformLocation(program, texture)
            guard location != -1
            else
            {
                print("\(programName): warning: program does not use texture '\(texture)'")
                continue
            }

            glUniform1i(location, GL.Int(i))
        }

        let uniformLocations:[GL.Int] = uniforms.map
        {
            (name:String) in

            let location:GL.Int = glGetUniformLocation(program, name)
            if location == -1
            {
                print("\(programName): warning: program does not use uniform '\(name)'")
            }

            return location
        }

        glUseProgram(0)

        return Program(id: program, uniforms: uniformLocations)
    }

    private static
    func compileShader(path:String, type:ShaderType) -> GL.UInt?
    {
        guard let source:UnsafeBufferPointer<CChar> =
            openTextFile(posixPath(path))
        else
        {
            print("failed to open shader file '\(path)'")
            return nil
        }
        defer
        {
            // TODO: when swift 5 comes out replace with direct call on UnsafePointer
            UnsafeMutablePointer(mutating: source.baseAddress!)
                .deallocate(capacity: source.count)
        }

        let shader:GL.UInt
        switch type
        {
        case .vertex:
            shader = glCreateShader(GL.VERTEX_SHADER)

        case .geometry:
            shader = glCreateShader(GL.GEOMETRY_SHADER)

        case .fragment:
            shader = glCreateShader(GL.FRAGMENT_SHADER)
        }

        var string:UnsafePointer<CChar>? = source.baseAddress,
                                        // the null terminator does not count
            length:GL.Int               = GL.Int(source.count - 1)

        glShaderSource(shader: shader, count: 1, string: &string, length: &length)
        glCompileShader(shader)
        // always print the shader log for now
        printLog(step: .compile(shader))

        guard check(step: .compile(shader))
        else
        {
            print("shader compilation failed (\(path))")
            // clean up
            glDeleteShader(shader)
            return nil
        }

        print("shader compilation succeeded (\(path))")

        return shader
    }

    private static
    func compileShaders(_ sources:[(path:String, type:ShaderType)]) -> [GL.UInt]?
    {
        var shaders:[GL.UInt] = []
        for (path, type):(String, ShaderType) in sources
        {
            guard let shader:GL.UInt = compileShader(path: path, type: type)
            else
            {
                for shader:GL.UInt in shaders
                {
                    glDeleteShader(shader)
                }

                return nil
            }

            shaders.append(shader)
        }

        return shaders
    }

    private static
    func check(step:CompilationStep) -> Bool
    {
        var success:GL.Int = 0

        switch step
        {
        case .compile(let shader):
            glGetShaderiv(shader: shader, pname: GL.COMPILE_STATUS, params: &success)

        case .link(let program):
            glGetProgramiv(program: program, pname: GL.LINK_STATUS, params: &success)
        }

        return success == 1 ? true : false
    }

    private static
    func log(step:CompilationStep) -> String
    {
        var messageLength:GL.Size = 0

        switch step
        {
        case .compile(let shader):
            glGetShaderiv(shader: shader, pname: GL.INFO_LOG_LENGTH,
                params: &messageLength)

        case .link(let program):
            glGetProgramiv(program: program, pname: GL.INFO_LOG_LENGTH,
                params: &messageLength)
        }

        guard messageLength > 0
        else
        {
            return ""
        }

        let message = UnsafeMutablePointer<CChar>.allocate(capacity: Int(messageLength))
        defer
        {
            message.deallocate(capacity: Int(messageLength))
        }

        switch step
        {
        case .compile(let shader):
            glGetShaderInfoLog(shader: shader, bufSize: messageLength,
                length: nil, infoLog: message)

        case .link(let program):
            glGetProgramInfoLog(program: program, bufSize: messageLength,
                length: nil, infoLog: message)
        }

        return String(cString: message)
    }

    private static
    func printLog(step:CompilationStep)
    {
        let message:String = log(step: step)
        guard message != ""
        else
        {
            return
        }

        print(message)
    }

    private static
    func posixPath(_ path:String) -> String
    {
        guard let firstChar:Character = path.first
        else
        {
            return path
        }
        var expandedPath:String = path
        if firstChar == "~"
        {
            if  expandedPath.count == 1 ||
                expandedPath[expandedPath.index(after: expandedPath.startIndex)] == "/"
            {
                expandedPath = String(cString: getenv("HOME")) + String(expandedPath.dropFirst())
            }
        }
        return expandedPath
    }

    // allocates and returns a null-terminated char buffer containing the contents
    // of the text file. the caller is responsible for deallocating the buffer
    private static
    func openTextFile(_ posixPath:String) -> UnsafeBufferPointer<CChar>?
    {
        guard let f:UnsafeMutablePointer<FILE> = fopen(posixPath, "rb")
        else
        {
            print("could not open file stream '\(posixPath)'")
            return nil
        }
        defer { fclose(f) }

        let fseekStatus:CInt = fseek(f, 0, SEEK_END)
        guard fseekStatus == 0
        else
        {
            print("fseek() on file '\(posixPath)' failed with error code \(fseekStatus)")
            return nil
        }

        let n:CLong = ftell(f)
        guard 0 ..< CLong.max ~= n
        else
        {
            print("ftell() on file '\(posixPath)' returned too large file size (\(n) bytes)")
            return nil
        }
        rewind(f)

        let buffer = UnsafeMutableBufferPointer<CChar>(start:
            UnsafeMutablePointer<CChar>.allocate(capacity: n + 1), count: n + 1)

        let nRead = fread(buffer.baseAddress, 1, n, f)
        guard nRead == n
        else
        {
            buffer.baseAddress?.deallocate(capacity: buffer.count)
            print("fread() on file '\(posixPath)' read \(nRead) characters out of \(n)")
            return nil
        }

        buffer[n] = 0 // cap with sentinel
        // TODO: when Swift 5 comes out replace with simple cast
        return UnsafeBufferPointer(start: buffer.baseAddress, count: buffer.count)
    }

    func uniform(_ location:Int, float:Float)
    {
        glUniform1f(GL.Int(location), float)
    }

    func uniform(_ location:Int, vec2:Math<Float>.V2)
    {
        glUniform2f(GL.Int(location), vec2.0, vec2.1)
    }

    func uniform(_ location:Int, vec3:Math<Float>.V3)
    {
        glUniform3f(GL.Int(location), vec3.0, vec3.1, vec3.2)
    }

    func uniform(_ location:Int, vec4:(Float, Float, Float, Float))
    {
        glUniform4f(GL.Int(location), vec4.0, vec4.1, vec4.2, vec4.3)
    }

    func uniform(_ location:Int, mat4:[Float], count:Int = 1)
    {
        glUniformMatrix4fv(GL.Int(location), GL.Size(count), false, mat4)
    }

    func activate()
    {
        glUseProgram(self.id)
    }
}
