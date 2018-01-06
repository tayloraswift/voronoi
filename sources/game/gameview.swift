import OpenGL
import MaxPNG
import func Glibc.time

enum Programs
{
    static
    let billboard   = Program.create(shaders:
            [("shaders/ui.vert", .vertex), ("shaders/ui.frag", .fragment)],
            textures: ["img"])!
    static
    let solid       = Program.create(shaders:
            [("shaders/solid.vert", .vertex), ("shaders/solid.frag", .fragment)],
            uniforms: ["matrix_model", "solidColor"])!
    static
    let vertcolor   = Program.create(shaders:
            [("shaders/vertcolor.vert", .vertex), ("shaders/vertcolor.frag", .fragment)],
            uniforms: ["matrix_model"])!
    static
    let spherecolor = Program.create(shaders:
            [("shaders/spherecolor.vert", .vertex), ("shaders/spherecolor.frag", .fragment)],
            uniforms: ["matrix_model", "sun"])!
}

extension BinaryFloatingPoint
{
    func format(decimalPlaces:Int) -> String
    {
        let i:Self = self.rounded(.down)
        let f:Self = self - i
        let fstr:String.SubSequence = String(describing: f).dropFirst(2).prefix(decimalPlaces)
        return "\(Int(i)).\(fstr)\(String(repeatElement("0", count: decimalPlaces - fstr.count)))"
    }
}

struct View3D:GameScene
{
    private
    var __debugOutput__:[String] = [],
        __debugPanel__:Billboard


    private
    let _voronoiVBO:GL.Buffer,
        _voronoiEBO:GL.Buffer,
        _voronoiVAO:GL.VertexArray,
        _voronoiSiteCount:Int,
        _voronoiFacesElemsCount:Int

    private
    var fpsCounter:Billboard,
        renderMode:GL.Enum = GL.FILL,
        zoomLevel:Int = 9,

        rig:GLCameraRig,

        size:Math<CInt>.V2

    init(frame:Math<CInt>.V2)
    {
        self.size = frame

        self.rig = GLCameraRig.create(  hscreen: Math.scale((-0.5, 0.5), by: Float(frame.x)),
                                        vscreen: Math.scale((-0.5, 0.5), by: Float(frame.y)),
                                        z: (-400, -0.10),
                                        scale: 0.0001)
        self.rig.jump(pivot: (0, 0, 0), angle: (2.21, 1.42), distance: 4.05)

        self.fpsCounter = Billboard(at: (-1, 1), size: (820, -30), frame: frame)
        // yes this is a horrible way to draw cairo text but whatever
        self.fpsCounter.context.selectFontFace("Fira Mono", weight: .bold)
        self.fpsCounter.context.setFontSize(13)

        self.__debugPanel__ = Billboard(at: (-1, -1), size: (520, 65), frame: frame)
        self.__debugPanel__.context.selectFontFace("Fira Mono")
        self.__debugPanel__.context.setFontSize(13)

        var points:[Math<Float>.V3] = []
            points.reserveCapacity(100)
        var prng = RandomXorshift(seed: 2)
        for _ in 0 ..< 100
        {
            points.append(prng.generateUnitFloat3())
        }

        let voronoiSphere = VoronoiSphere.generate(fromNormalizedPoints: points)
        let (vertexData, indices, facesOffset):([Float], [GL.UInt], Int) =
            voronoiSphere.vertexArrays()

        self._voronoiSiteCount       = facesOffset
        self._voronoiFacesElemsCount = indices.count - facesOffset

        self._voronoiVBO = GL.Buffer.generate()
        self._voronoiEBO = GL.Buffer.generate()
        self._voronoiVAO = GL.VertexArray.generate()

        self._voronoiVBO.bind(to: .array)
        {
            GL.Buffer.Target.array.data(vertexData, usage: .staticDraw)

            self._voronoiVAO.bind()
            GL.setVertexAttributeLayout(.float(.float3, false), .float(.float3, false))

            self._voronoiEBO.bind(to: .elementArray)
            {
                GL.Buffer.Target.elementArray.data(indices, usage: .staticDraw)

                self._voronoiVAO.unbind()
            }
        }
    }

    func destroy()
    {
        self.rig.destroy()

        self._voronoiVBO.destroy()
        self._voronoiEBO.destroy()
        self._voronoiVAO.destroy()

        self.fpsCounter.destroy()

        self.__debugPanel__.destroy()
    }

    mutating
    func show3D(_ dt:Double)
    {
        self.rig.activate()

        glEnable(GL.CULL_FACE)
        glEnable(GL.LINE_SMOOTH)
        glPolygonMode(face: GL.FRONT_AND_BACK, mode: self.renderMode)

        Programs.spherecolor.activate()
        Programs.spherecolor.uniform(1, vec3: Math.normalize((-1, -1, 0)))
        Programs.spherecolor.uniform(0,
            mat4: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])

        self._voronoiVAO.draw(start: self._voronoiSiteCount, count: self._voronoiFacesElemsCount, mode: GL.TRIANGLES)

        glPointSize(2)

        Programs.solid.activate()
        Programs.solid.uniform(0,
            mat4: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
        Programs.solid.uniform(1, vec4: (1, 1, 1, 1))
        self._voronoiVAO.draw(count: self._voronoiSiteCount, mode: GL.POINTS)

        self.drawText(dt: dt)
    }

    private
    func drawText(dt:Double)
    {
        self.fpsCounter.clear()
        self.fpsCounter.context.setSource(rgba: (0, 0, 0, 0.3))
        self.fpsCounter.context.paint()
        self.fpsCounter.context.setSource(rgba: (1, 1, 1, 1))
        self.fpsCounter.context.move(to: (10, 20))
        let renderModeStr:String
        if self.renderMode == GL.FILL
        {
            renderModeStr = "faces"
        }
        else if self.renderMode == GL.LINE
        {
            renderModeStr = "wireframe"
        }
        else
        {
            renderModeStr = "vertices"
        }
        let posStr:String = "(cx: "  + self.rig.pivot.x.format(decimalPlaces: 3) +
                            ", cy: " + self.rig.pivot.y.format(decimalPlaces: 3) +
                            ", cz: " + self.rig.pivot.z.format(decimalPlaces: 3) +
                            ", θ: "  + self.rig.angle.θ.format(decimalPlaces: 3) +
                            ", φ: "  + self.rig.angle.φ.format(decimalPlaces: 3) +
                            ", ρ: "  + self.rig.distance.format(decimalPlaces: 3) + ")"
        self.fpsCounter.context.showText("render mode: \(renderModeStr) | \(posStr) | \(Int((1/dt).rounded())) FPS")
        self.fpsCounter.update()
        glPolygonMode(face: GL.FRONT_AND_BACK, mode: GL.FILL)
        self.fpsCounter.draw()

        self.__debugPanel__.clear()
        self.__debugPanel__.context.setSource(rgba: (0, 0, 0, 0.3))
        self.__debugPanel__.context.paint()
        self.__debugPanel__.context.setSource(rgba: (1, 1, 1, 1))
        var y:Double = 20
        for line:String in self.__debugOutput__.suffix(3)
        {
            self.__debugPanel__.context.move(to: (10, y))
            self.__debugPanel__.context.showText(line)
            y += 17
        }
        self.__debugPanel__.update()
        self.__debugPanel__.draw()
    }

    mutating
    func onResize(newFrame:Math<CInt>.V2)
    {
        self.size = newFrame

        self.fpsCounter.rebase(toFrame: newFrame)
        self.__debugPanel__.rebase(toFrame: newFrame)

        self.rig.setDimensions( hscreen: Math.scale((-0.5, 0.5), by: Float(newFrame.x)),
                                vscreen: Math.scale((-0.5, 0.5), by: Float(newFrame.y)))
    }

    mutating
    func press(_ position:Math<Double>.V2, button:Interface.MouseButton)
    {
        self.__debugOutput__.append("\(position) \(button)")
    }

    mutating
    func drag(_ position:Math<Double>.V2, anchor:Interface.MouseAnchor)
    {
        let screenVector:Math<Float>.V2 = Math.castFloat(Math.sub(position, anchor.position))
        switch anchor.button
        {
        case .right:
            self.rig.orbit(displacement: Math.scale(screenVector, by: 0.005))

        case .middle:
            self.rig.track(displacement: Math.scale(screenVector, by: -0.005))

        case .left:
            break
        }
    }

    mutating
    func release()
    {
        self.rig.rebase()
    }

    mutating
    func scroll(axis:Bool, sign:Bool)
    {
        if axis
        {
            self.zoomLevel  = max(1, self.zoomLevel + (sign ? -1 : 1))
            self.rig.dolly(distance: 0.05 * Float(self.zoomLevel * self.zoomLevel))
        }
    }

    mutating
    func key(_ key:Interface.PhysicalKey)
    {
        self.__debugOutput__.append("\(key)")

        switch key
        {
        case .tab:
            if self.renderMode == GL.FILL
            {
                self.renderMode = GL.LINE
            }
            else if self.renderMode == GL.LINE
            {
                self.renderMode = GL.POINT
            }
            else
            {
                self.renderMode = GL.FILL
            }

        case .space:
            break

        case .period:
            self.rig.setPivot((0, 0, 0))

        case .four:
            self.screenshot()

        default:
            return
        }
    }

    mutating
    func screenshot()
    {
        let size:Math<Int>.V2 = Math.cast(self.size, as: Int.self),
            byteCount:Int = size.x * size.y * 4
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: byteCount)
        defer
        {
            buffer.deallocate(capacity: byteCount)
        }

        glReadPixels(0, 0, self.size.x, self.size.y, GL.RGBA, GL.UNSIGNED_BYTE, buffer)

        // flip the image back the right way up
        for y:Int in 0 ..< size.y >> 1
        {
            for i:Int in 0 ..< size.x * 4
            {
                swap(&buffer[4 * y * size.x + i], &buffer[4 * (size.y - 1 - y) * size.x + i])
            }
        }

        let filename:String = "screenshot_\(time(nil)).png"

        let properties = PNGProperties(width: size.x, height: size.y, color: .rgba8, interlaced: false)
        guard let _:Void = try? png_encode(path: filename, raw_data: UnsafeBufferPointer(start: buffer, count: byteCount), properties: properties)
        else
        {
            self.__debugOutput__.append("failed to save screenshot")
            return
        }

        self.__debugOutput__.append("screenshot saved to '\(filename)'")
    }
}
