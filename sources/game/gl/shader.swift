import Glibc
import OpenGL

struct Shader
{
    private
    typealias Status_func = (GL.UInt, GL.Enum, UnsafeMutablePointer<GL.Int>) -> ()
    private
    typealias Log_func = (GL.UInt, GL.Int, UnsafeMutablePointer<GL.Size>, UnsafeMutablePointer<GL.Char>) -> ()

    private 
    let program:GL.UInt

    let uniforms:[GL.Int]

    init?(vertex_file:String, geometry_file:String? = nil, fragment_file:String? = nil,
    uniforms:[String] = [], textures:[String] = [])
    {
        guard let vert_source:UnsafeMutableBufferPointer<CChar> =
            Shader.open_text_file(Shader.posix_path(vertex_file))
        else
        {
            return nil
        }
        defer
        {
            vert_source.baseAddress?.deallocate(capacity: vert_source.count)
        }

        let geom_source:UnsafeMutableBufferPointer<CChar>?
        if let geometry_file:String = geometry_file
        {
            guard let _geom_source:UnsafeMutableBufferPointer<CChar> =
                Shader.open_text_file(Shader.posix_path(geometry_file))
            else
            {
                return nil
            }

            geom_source = _geom_source
        }
        else
        {
            geom_source = nil
        }
        defer
        {
            geom_source?.baseAddress?.deallocate(capacity: geom_source?.count ?? 0)
        }

        let frag_source:UnsafeMutableBufferPointer<CChar>?
        if let fragment_file:String = fragment_file
        {
            guard let _frag_source:UnsafeMutableBufferPointer<CChar> =
                Shader.open_text_file(Shader.posix_path(fragment_file))
            else
            {
                return nil
            }

            frag_source = _frag_source
        }
        else
        {
            frag_source = nil
        }
        defer
        {
            frag_source?.baseAddress?.deallocate(capacity: frag_source?.count ?? 0)
        }

        let program:GL.UInt   = glCreateProgram()
        var shaders:[GL.UInt] = []

        for (shader_source, shader_type):(UnsafeMutableBufferPointer<CChar>?, GL.Enum) in
        [(vert_source, GL.VERTEX_SHADER  ),
         (frag_source, GL.FRAGMENT_SHADER),
         (geom_source, GL.GEOMETRY_SHADER)]
        {
            guard let source:UnsafePointer<CChar> = UnsafePointer<CChar>(shader_source?.baseAddress)
            else
            {
                continue
            }
            guard let shader:GL.UInt = Shader.compile(source: source, type: shader_type)
            else
            {
                return nil
            }

            shaders.append(shader)
        }

        guard Shader.link(program: program, shaders: shaders)
        else
        {
            return nil
        }

        // attempt to find and bind standard uniform blocks to binding points
        glUniformBlockBinding(  program: program,
                                uniformBlockIndex: glGetUniformBlockIndex(program, "CameraMatrixBlock"),
                                uniformBlockBinding: 0)
        glUniformBlockBinding(  program: program,
                                uniformBlockIndex: glGetUniformBlockIndex(program, "CameraDataBlock"),
                                uniformBlockBinding: 1)

        @inline(__always)
        func _guard_missing_uniform(_ name:String) -> GL.Int
        {
            let index:GL.Int = glGetUniformLocation(program, name)
            if index == -1
            {
                print("warning: shader does not contain uniform '\(name)'")
            }

            return index
        }

        glUseProgram(program)
        for (i, texture):(Int, String) in textures.enumerated()
        {
            glUniform1i(_guard_missing_uniform(texture), GL.Int(i))
        }

        self.uniforms = uniforms.map{ _guard_missing_uniform($0) }
        self.program  = program
    }

    private static
    func compile(source:UnsafePointer<CChar>, type shader_type:GL.Enum) -> GL.UInt?
    {
        let shader:GL.UInt = glCreateShader(type: shader_type)

        glShaderSource(shader: shader, count: 1, string: [source], length: [-1])
        glCompileShader(shader)

        if let error_msg:String = Shader.compile_success(object: shader, stage: GL.COMPILE_STATUS,
                                                         status:{ glGetShaderiv(shader: $0,
                                                                                pname : $1,
                                                                                params: $2)
                                                                },
                                                         log   :{ glGetShaderInfoLog(shader : $0,
                                                                                     bufSize: $1,
                                                                                     length : $2,
                                                                                     infoLog: $3)
                                                                })
        {
            print(error_msg)
            return nil
        }
        else
        {
            return shader
        }
    }

    private static
    func link(program:GL.UInt, shaders:[GL.UInt]) -> Bool
    {
        for shader in shaders
        {
            glAttachShader(program, shader)
            defer
            {
                glDeleteShader(shader)
            }
        }
        glLinkProgram(program)

        if let error_msg:String = Shader.compile_success(object: program, stage: GL.LINK_STATUS,
                                                         status: { glGetProgramiv($0, $1, $2) },
                                                         log   : { glGetProgramInfoLog($0, $1, $2, $3) })
        {
            print(error_msg)
            return false
        }
        else
        {
            return true
        }
    }

    private static
    func compile_success(object:GL.UInt, stage:GL.Enum, status:Status_func, log:Log_func) -> String?
    {
        var success:GL.Int = 0
        status(object, stage, &success)
        if success == 1
        {
            return nil
        }
        else
        {
            var message_length:GL.Size = 0
            status(object, GL.INFO_LOG_LENGTH, &message_length)
            guard message_length > 0
            else
            {
                return ""
            }
            var error_message = [GL.Char](repeating: 0, count: Int(message_length))
            log(object, message_length, &message_length, &error_message)
            return String(cString: error_message)
        }
    }

    private static
    func posix_path(_ path:String) -> String
    {
        guard let first_char:Character = path.first
        else
        {
            return path
        }
        var expanded_path:String = path
        if first_char == "~"
        {
            if expanded_path.count == 1 || expanded_path[expanded_path.index(after: expanded_path.startIndex)] == "/"
            {
                expanded_path = String(cString: getenv("HOME")) + String(expanded_path.dropFirst())
            }
        }
        return expanded_path
    }

    private static
    func open_text_file(_ posix_path:String) -> UnsafeMutableBufferPointer<CChar>?
    {
        guard let f:UnsafeMutablePointer<FILE> = fopen(posix_path, "rb")
        else
        {
            print("could not open file stream '\(posix_path)'")
            return nil
        }
        defer { fclose(f) }

        let fseek_status:CInt = fseek(f, 0, SEEK_END)
        guard fseek_status == 0
        else
        {
            print("fseek() on file '\(posix_path)' failed with error code \(fseek_status)")
            return nil
        }

        let n:CLong = ftell(f)
        guard 0 ..< CLong.max ~= n
        else
        {
            print("ftell() on file '\(posix_path)' returned too large file size (\(n) bytes)")
            return nil
        }
        rewind(f)

        let buffer:UnsafeMutableBufferPointer<CChar> =
            UnsafeMutableBufferPointer<CChar>(start: UnsafeMutablePointer<CChar>.allocate(capacity: n + 1), count: n + 1)

        let n_read = fread(buffer.baseAddress, 1, n, f)
        guard n_read == n
        else
        {
            buffer.baseAddress?.deallocate(capacity: buffer.count)
            print("fread() on file '\(posix_path)' read \(n_read) characters out of \(n)")
            return nil
        }

        buffer[n] = 0 // cap with sentinel
        return buffer
    }

    func activate()
    {
        glUseProgram(self.program)
    }
}
