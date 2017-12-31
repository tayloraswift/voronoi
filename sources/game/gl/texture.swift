import OpenGL
import MaxPNG

struct GLTexture
{
    enum Format
    {
        case quad8,
             triple8,
             double8,
             single8,
             quad16,
             triple16,
             double16,
             single16,
             rgbaPerInt32,
             argbPerInt32

        private
        var format_code:GL.Enum
        {
            switch self
            {
            case .quad8, .quad16, .rgbaPerInt32:
                return GL.RGBA
            case .argbPerInt32:
                return GL.BGRA
            case .triple8, .triple16:
                return GL.RGB
            case .double8, .double16:
                return GL.RG
            case .single8, .single16:
                return GL.RED
            }
        }

        private
        var layout_code:GL.Enum
        {
            switch self
            {
            case .quad8, .triple8, .double8, .single8:
                return GL.UNSIGNED_BYTE
            case .quad16, .triple16, .double16, .single16:
                return GL.UNSIGNED_SHORT
            case .rgbaPerInt32:
                return GL.UNSIGNED_INT_8_8_8_8
            case .argbPerInt32:
                return GL.UNSIGNED_INT_8_8_8_8_REV
            }
        }

        private
        var internal_code:GL.Enum
        {
            switch self
            {
            case .quad8, .rgbaPerInt32, .argbPerInt32:
                return GL.RGBA8
            case .triple8:
                return GL.RGB8
            case .double8:
                return GL.RG8
            case .single8:
                return GL.R8
            case .quad16:
                return GL.RGBA16
            case .triple16:
                return GL.RGB16
            case .double16:
                return GL.RG16
            case .single16:
                return GL.R16
            }
        }

        var bpp:Int
        {
            switch self
            {
            case .quad8, .double16, .rgbaPerInt32, .argbPerInt32:
                return 4
            case .triple8:
                return 3
            case .double8, .single16:
                return 2
            case .single8:
                return 1
            case .quad16:
                return 8
            case .triple16:
                return 6
            }
        }

        func uploadSub2D(target:GL.Enum, size:Math<GL.Int>.V2, pixels:UnsafePointer<UInt8>?)
        {
            glTexSubImage2D(target  : target,
                            level   : 0,
                            xoffset : 0,
                            yoffset : 0,
                            width   : size.x,
                            height  : size.y,
                            format  : self.format_code,
                            type    : self.layout_code,
                            pixels  : pixels)
        }

        func upload2D(target:GL.Enum, size:Math<GL.Int>.V2, pixels:UnsafePointer<UInt8>?)
        {
            glTexImage2D(target         : target,
                         level          : 0,
                         internalformat : self.internal_code,
                         width          : size.x,
                         height         : size.y,
                         border         : 0,
                         format         : self.format_code,
                         type           : self.layout_code,
                         pixels         : pixels)
        }

        func upload3D(target:GL.Enum, size:Math<GL.Int>.V3, pixels:UnsafePointer<UInt8>?)
        {
            glTexImage3D(target         : target,
                         level          : 0,
                         internalformat : self.internal_code,
                         width          : size.x,
                         height         : size.y,
                         depth          : size.z,
                         border         : 0,
                         format         : self.format_code,
                         type           : self.layout_code,
                         pixels         : pixels)
        }
    }

    let texture:GL.UInt

    struct Bitmap2D
    {
        let format:Format,
            pixbytes:[UInt8],
            size:Math<Int>.V2

        var isCubeTexture:Bool // mainly for assertions
        {
            return self.size.x == self.size.y * 6
        }

        static
        func open(fromPNG path:String) -> Bitmap2D?
        {
            let pixbits:[UInt8],
                properties:PNGProperties
            do
            {
                try (pixbits, properties) = png_decode(path: path)
            }
            catch
            {
                print(error)
                return nil
            }

            let format:Format
            switch properties.color
            {
            case .rgba8:
                format = .quad8
            case .rgba16:
                format = .quad16
            case .rgb8, .indexed1, .indexed2, .indexed4, .indexed8:
                format = .triple8
            case .rgb16:
                format = .triple16
            case .grayscale_a8:
                format = .double8
            case .grayscale_a16:
                format = .double16
            case .grayscale1, .grayscale2, .grayscale4, .grayscale8:
                format = .single8
            case .grayscale16:
                format = .single16
            }

            guard let deinterlacedPixbits:[UInt8] = properties.interlaced ?
                properties.deinterlace(raw_data: pixbits) : pixbits
            else
            {
                return nil
            }

            guard let pixbytes = properties.expand(raw_data: deinterlacedPixbits)
            else
            {
                return nil
            }

            return Bitmap2D(format: format,
                            pixbytes: pixbytes,
                            size: (properties.width, properties.height))
        }

        func upload(target:GL.Enum)
        {
            self.format.upload2D(target: target,
                size: Math.cast(self.size, as: GL.Int.self), pixels: self.pixbytes)
        }

        func uploadCubemap()
        {
            self.pixbytes.withUnsafeBufferPointer
            {
                let faceStride:Int = self.size.x * self.size.x * self.format.bpp
                var base:UnsafePointer<UInt8> = $0.baseAddress!
                for i in GL.Int(0) ..< GL.Int(6)
                {
                    self.format.upload2D(target: GL.TEXTURE_CUBE_MAP_POSITIVE_X + i,
                        size: Math.cast((self.size.x, self.size.x), as: GL.Int.self),
                        pixels: base)
                    base += faceStride
                }
            }

            glTexParameteri(target: GL.TEXTURE_CUBE_MAP, pname: GL.TEXTURE_WRAP_S, param: GL.CLAMP_TO_EDGE)
            glTexParameteri(target: GL.TEXTURE_CUBE_MAP, pname: GL.TEXTURE_WRAP_T, param: GL.CLAMP_TO_EDGE)
            glTexParameteri(target: GL.TEXTURE_CUBE_MAP, pname: GL.TEXTURE_WRAP_R, param: GL.CLAMP_TO_EDGE)
        }
    }

    struct Bitmap3D
    {
        let format:Format,
            pixbytes:[UInt8],
            size:Math<Int>.V3

        static
        func open(fromPNG path:String) -> Bitmap3D?
        {
            guard let bitmap2D:Bitmap2D = Bitmap2D.open(fromPNG: path)
            else
            {
                return nil
            }

            guard bitmap2D.size.x * bitmap2D.size.x == bitmap2D.size.y
            else
            {
                print("ambiguous 3d texture dimensions")
                return nil
            }

            return Bitmap3D(format: bitmap2D.format,
                            pixbytes: bitmap2D.pixbytes,
                            size: (bitmap2D.size.x, bitmap2D.size.x, bitmap2D.size.x))
        }

        func upload(target:GL.Enum)
        {
            self.format.upload3D(target: target,
                size: Math.cast(self.size, as: GL.Int.self), pixels: self.pixbytes)
        }
    }

    static
    func create() -> GLTexture
    {
        var id:GL.UInt = 0
        glGenTextures(1, &id)
        return GLTexture(texture: id)
    }

    static
    func create(fromPNG path:String, createMipmaps:Bool = true) -> GLTexture?
    {
        guard let bitmap2D:Bitmap2D = Bitmap2D.open(fromPNG: path)
        else
        {
            return nil
        }

        let texture = GLTexture.create()
        texture.bind(to: GL.TEXTURE_2D)
        bitmap2D.upload(target: GL.TEXTURE_2D)

        if createMipmaps
        {
            glGenerateMipmap(GL.TEXTURE_2D)
        }
        else
        {
            glTexParameteri(target: GL.TEXTURE_2D, pname: GL.TEXTURE_MIN_FILTER, param: GL.LINEAR)
        }

        glBindTexture(target: GL.TEXTURE_2D, texture: 0)

        return texture
    }

    func destroy()
    {
        var id:GL.UInt = self.texture
        glDeleteTextures(1, &id)
    }

    func bind(to target:GL.Enum)
    {
        glBindTexture(target, self.texture)
    }

    static
    func unbind(from target:GL.Enum)
    {
        glBindTexture(target, 0)
    }

    func activate(onUnit unit:GL.Int, target:GL.Enum)
    {
        glActiveTexture(GL.TEXTURE0 + unit)
        glBindTexture(target, self.texture)
    }
}
