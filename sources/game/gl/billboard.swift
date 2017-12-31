import OpenGL
import Cairo

struct Billboard
{
    private static
    let format:GLTexture.Format = .argbPerInt32

    let surface:CairoSurface,
        context:CairoContext

    private
    let vbo:GL.Buffer,
        ebo:GL.Buffer,
        vao:GL.VertexArray,
        texture:GLTexture

    private
    let position:Math<Float>.V2,
        size:Math<CInt>.V2

    init(at position:Math<Float>.V2, size:Math<CInt>.V2, frame:Math<CInt>.V2)
    {
        self.position = position
        self.size     = size

        guard let surface = CairoSurface(format: .argb32, size: Math.abs(size))
        else
        {
            fatalError("failed to make Cairo surface")
        }

        self.surface = surface
        self.context = self.surface.create()

        self.texture = GLTexture.create()
        self.texture.bind(to: GL.TEXTURE_2D)
        self.surface.withData
        {
            Billboard.format.upload2D(target: GL.TEXTURE_2D,
                size: Math.abs(size), pixels: $0.baseAddress!)
        }

        glTexParameteri(target: GL.TEXTURE_2D, pname: GL.TEXTURE_MAG_FILTER, param: GL.NEAREST)
        glTexParameteri(target: GL.TEXTURE_2D, pname: GL.TEXTURE_MIN_FILTER, param: GL.NEAREST)
        glTexParameteri(target: GL.TEXTURE_2D, pname: GL.TEXTURE_WRAP_S    , param: GL.CLAMP_TO_EDGE)
        glTexParameteri(target: GL.TEXTURE_2D, pname: GL.TEXTURE_WRAP_T    , param: GL.CLAMP_TO_EDGE)

        GLTexture.unbind(from: GL.TEXTURE_2D)

        self.vbo = GL.Buffer.generate()
        self.ebo = GL.Buffer.generate()
        self.vao = GL.VertexArray.generate()

        self.vbo.bind(to: .array)
        {
            let coordinates:[Float] =
                Billboard.generateCoordinates(position: position,
                    size: size, frame: frame)
            GL.Buffer.Target.array.data(coordinates, usage: .staticDraw)

            self.vao.bind()
            GL.setVertexAttributeLayout(.float(.float2, false), .float(.float2, false))

            self.ebo.bind(to: .elementArray)
            {
                GL.Buffer.Target.elementArray.data([0 as GL.UInt, 1, 2, 0, 2, 3],
                    usage: .staticDraw)

                self.vao.unbind()
            }
        }
    }

    func destroy()
    {
        self.vbo.destroy()
        self.ebo.destroy()
        self.vao.destroy()
        self.texture.destroy()
    }

    mutating
    func rebase(toFrame frame:Math<CInt>.V2)
    {
        self.vbo.bind(to: .array)
        {
            let coordinates:[Float] =
                Billboard.generateCoordinates(position: self.position,
                    size: self.size, frame: frame)
            GL.Buffer.Target.array.subData(coordinates)
        }
    }

    func draw()
    {
        Shaders.billboard.activate()
        self.texture.activate(onUnit: 0, target: GL.TEXTURE_2D)
        self.vao.draw(count: 6)
        GLTexture.unbind(from: GL.TEXTURE_2D)
    }

    func update()
    {
        self.texture.bind(to: GL.TEXTURE_2D)
        self.surface.withData
        {
            Billboard.format.uploadSub2D(target: GL.TEXTURE_2D,
                size: Math.abs(self.size), pixels: $0.baseAddress!)
        }
        GLTexture.unbind(from: GL.TEXTURE_2D)
    }

    func clear()
    {
        self.surface.withData
        {
            (pixbytes:UnsafeMutableBufferPointer<UInt8>) in

            for i in stride(from: 3, to: pixbytes.count, by: 4)
            {
                pixbytes[i] = 0;
            }
        }
    }

    private static
    func generateCoordinates(position corner1:Math<Float>.V2,
        size:Math<CInt>.V2, frame:Math<CInt>.V2) -> [Float]
    {
        let corner2:Math<Float>.V2 =
            Math.add(corner1,
                    Math.div(   Math.castFloat(Math.scale(size, by: 2)),
                                Math.castFloat(frame)))

        let horizontal:Math<Float>.V2 =
            corner1.x > corner2.x ? (corner2.x, corner1.x) : (corner1.x, corner2.x)
        let vertical:Math<Float>.V2 =
            corner1.y > corner2.y ? (corner2.y, corner1.y) : (corner1.y, corner2.y)

        // reversed v coordinates because the pixbuf is upside-down
        return [horizontal.0, vertical.0, 0, 1,
                horizontal.1, vertical.0, 1, 1,
                horizontal.1, vertical.1, 1, 0,
                horizontal.0, vertical.1, 0, 0]
    }
}
