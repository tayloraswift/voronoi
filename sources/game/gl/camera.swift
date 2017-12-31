import OpenGL

struct GLCamera
{
    private static
    func align<T>(_ x:T, to multiple:T) -> T where T:BinaryInteger
    {
        let remainder = x % multiple
        return remainder == 0 ? x : x + multiple - remainder
    }

    private
    typealias BlockRange = (start:Int, count:Int)
    /*
    standard camera uniform blocks

    layout (std140) uniform CameraMatrixBlock
    {
        mat4 proj;    // [ 0  ..<  64]
        mat4 view;    // [64  ..< 128]
    };

    layout (std140) uniform CameraDataBlock
    {
        mat4  world;        // [  0 ..<  64]
        vec3  position;     // [ 64 ..<  76]
        float zFar;         // [ 76 ..<  80]
        vec3  antinormal;   // [ 80 ..<  92]
        float zNear;        // [ 92 ..<  96]
        vec2  vspan;        // [ 96 ..< 104]
        vec2  hspan;        // [104 ..< 112] size = 112
    };
    */

    /*
                +-------------------+-----------+
            ↑   |                   |           |
        vspan.1 |                   |           |
            ↓   |                   |           |
                +-------------------+-----------+
            ↑   |                   |           |
                |                   |           |
        vspan.0 |                   |           |
                |                   |           |
            ↓   |                   |           |
                +-------------------+-----------+
                 ←     hspan.0     → ← hspan.1 →

                 ←   -hscreen.0    → ←hscreen.1→
                +-------------------+-----------+
            ↑   |                   |           |
      vscreen.1 |                   |           |
            ↓   |                   |           |
                +-------------------+-----------+
            ↑   |                   |           |
                |                   |           |
     -vscreen.0 |                   |           |
                |                   |           |
            ↓   |                   |           |
                +-------------------+-----------+
    */

    private static
    let blockRanges:(BlockRange, BlockRange) =
    {
        var alignment:GL.Int = 0
        glGetIntegerv(pname: GL.UNIFORM_BUFFER_OFFSET_ALIGNMENT, data: &alignment)

        var blocks:(BlockRange, BlockRange)
        blocks.0 = (0, 128)
        blocks.1 = (align(blocks.0.start + blocks.0.count, to: Int(alignment)), 112)
        return blocks
    }()

    private
    enum Offset
    {
        static
        let proj:Int       = 0,
            view:Int       = 16,

            world:Int      = blockRanges.1.start >> 2,
            position:Int   = Offset.world + 16,
            zFar:Int       = Offset.world + 19,
            antinormal:Int = Offset.world + 20,
            zNear:Int      = Offset.world + 23,
            vspan:Int      = Offset.world + 24,
            hspan:Int      = Offset.world + 26,

            __count__:Int = Offset.world + 28
    }

    private
    var block:UnsafeMutablePointer<Float>

    private
    let uniformBuffer:GL.Buffer

    private
    var rawBlockData:UnsafeRawBufferPointer
    {
        return UnsafeRawBufferPointer(UnsafeBufferPointer(start: self.block,
            count: Offset.__count__))
    }

    private
    var proj:UnsafeMutablePointer<Float>
    {
        return self.block
    }
    private
    var view:UnsafeMutablePointer<Float>
    {
        return self.block + Offset.view
    }
    private
    var world:UnsafeMutablePointer<Float>
    {
        return self.block + Offset.world
    }

    var position:Math<Float>.V3
    {
        get
        {
            return Math.load(from: self.block + Offset.position)
        }
        set(p)
        {
            Math.copy(p, to: self.block + Offset.position)
        }
    }
    var antinormal:Math<Float>.V3
    {
        get
        {
            return Math.load(from: self.block + Offset.antinormal)
        }
        set(e)
        {
            Math.copy(e, to: self.block + Offset.antinormal)
        }
    }

    var x:Math<Float>.V2
    {
        get
        {
            return Math.load(from: self.block + Offset.hspan)
        }
        set(x)
        {
            Math.copy(x, to: self.block + Offset.hspan)
        }
    }
    var y:Math<Float>.V2
    {
        get
        {
            return Math.load(from: self.block + Offset.vspan)
        }
        set(y)
        {
            Math.copy(y, to: self.block + Offset.vspan)
        }
    }
    var z:Math<Float>.V2
    {
        get
        {
            return (self.block[Offset.zFar], self.block[Offset.zNear])
        }
        set(z)
        {
            self.block[Offset.zFar]  = z.0
            self.block[Offset.zNear] = z.1
        }
    }

    var tangent:Math<Float>.V3
    {
        return (self.view[0], self.view[4], self.view[8])
    }
    var bitangent:Math<Float>.V3
    {
        return (self.view[1], self.view[5], self.view[9])
    }

    static
    func create(x:Math<Float>.V2, y:Math<Float>.V2, z:Math<Float>.V2) -> GLCamera
    {
        let uniformBuffer = GL.Buffer.generate()
        uniformBuffer.bind(to: .uniform)
        {
            GL.Buffer.Target.uniform
            .data(reserveBytes: blockRanges.1.start + blockRanges.1.count,
                usage: .dynamicDraw)
        }

        GL.Buffer.Target.uniform
        .bindRange(start: blockRanges.0.start,
            count: blockRanges.0.count, of: uniformBuffer, toIndex: 0)

        GL.Buffer.Target.uniform
        .bindRange(start: blockRanges.1.start,
            count: blockRanges.1.count, of: uniformBuffer, toIndex: 1)

        let block = UnsafeMutablePointer<Float>.allocate(capacity: Offset.__count__)
        var camera = GLCamera(block: block, uniformBuffer: uniformBuffer)
        // place appropriate zeros into matrices
        // the 32 byte overrun is meant to zero out the view matrix too, since
        // it lies directly after the projection matrix
        camera.proj.initialize(to: 0, count: 32)
        camera.proj[11] = -1 // the perspective -1 in the projection matrix formula
        camera.view[15] =  1 // the identity 1
        camera.world.initialize(to: 0, count: 16)
        camera.x = x
        camera.y = y
        camera.z = z
        camera.updateProjection()
        return camera
    }

    func destroy()
    {
        self.uniformBuffer.destroy()
        self.block.deallocate(capacity: Offset.__count__)
    }

    mutating
    func updateProjection()
    {
        //  [0]: 2n/(r - l) [4]: 0          [ 8]:  (r + l)/(r - l)  [12]: 0
        //  [1]: 0          [5]: 2n/(t - b) [ 9]:  (t + b)/(t - b)  [13]: 0
        //  [2]: 0          [6]: 0          [10]: -(f + n)/(f - n)  [14]: -2fn/(f - n)
        //  [3]: 0          [7]: 0          [11]: -1                [15]: 0
        //
        //  where
        //
        //  width  = r - l
        //  height = t - b
        //  shiftx = r + l
        //  shifty = t + b
        //  zDepth = f - n
        //
        //  note: n and f are positive quantities, but self.z is a negative
        //  tuple following the conventions of OpenGL device space

        let width:Float  = self.x.1 - self.x.0,
            height:Float = self.y.1 - self.y.0,
            zDepth:Float = self.z.1 - self.z.0

        self.proj[ 0] = -2 * self.z.1 / width
        self.proj[ 5] = -2 * self.z.1 / height
        self.proj[ 8] = (self.x.1 + self.x.0) / width
        self.proj[ 9] = (self.y.1 + self.y.0) / height
        self.proj[10] = (self.z.0 + self.z.1) / zDepth
        self.proj[14] = -2 * self.z.0 * self.z.1 / zDepth
    }

    mutating
    func updateView(normal:Math<Float>.V3, tangent:Math<Float>.V3, position:Math<Float>.V3)
    {
        self.position   = position
        self.antinormal = Math.neg(normal)

        //  bitangent
        //      ↑
        //      ·  →  tangent
        //    normal

        // no need to normalize as they are perpendicular
        let bitangent:Math<Float>.V3 = Math.cross(normal, tangent)

        //  [0]: Tx [4]: Ty [ 8]: Tz [12]: -T·P
        //  [1]: Bx [5]: By [ 9]: Bz [13]: -B·P
        //  [2]: Nx [6]: Ny [10]: Nz [14]: -N·P
        //  [3]: 0  [7]: 0  [11]: 0  [15]:  1

        Math.copy((tangent.x, bitangent.x, normal.x), to: self.view)
        Math.copy((tangent.y, bitangent.y, normal.y), to: self.view + 4)
        Math.copy((tangent.z, bitangent.z, normal.z), to: self.view + 8)
        Math.copy(( -Math.dot(tangent,   position),
                    -Math.dot(bitangent, position),
                    -Math.dot(normal,    position)),
                    to: self.view + 12)
    }

    mutating
    func updateWorld(vanishingPoint:Math<Float>.V2, scale:Float)
    {
        let tangent:Math<Float>.V3    = self.tangent,
            bitangent:Math<Float>.V3  = self.bitangent,
            antinormal:Math<Float>.V3 = self.antinormal

            //  [0]: k Tx   [4]: k Bx   [ 8]: -Nx   [12]: -k(Tx vx + Bx vy)
            //  [1]: k Ty   [5]: k By   [ 9]: -Ny   [13]: -k(Ty vx + By vy)
            //  [2]: k Tz   [6]: k Bz   [10]: -Nz   [14]: -k(Tz vx + Bz vy)
            //  [3]: 0      [7]: 0      [11]:  0    [15]:  1

            let k:Float = scale / self.z.1
            Math.copy(Math.scale(  tangent, by: k), to: self.world)
            Math.copy(Math.scale(bitangent, by: k), to: self.world + 4)
            Math.copy(antinormal,                   to: self.world + 8)
            Math.copy(Math.scale(Math.add(Math.scale(tangent  , by: vanishingPoint.x),
                                          Math.scale(bitangent, by: vanishingPoint.y)),
                                 by: -k),           to: self.world + 12)
    }

    func activate()
    {
        self.uniformBuffer.bind(to: .uniform)
        {
            GL.Buffer.Target.uniform.subData(self.rawBlockData)
        }
    }
}

struct GLCameraRig
{
    private
    var camera:GLCamera,
        vanishingPoint:Math<Float>.V2,
        scale:Float

    private(set)
    var distance:Float             = 0,
        angle:Math<Float>.S2       = (0, 0),
        pivot:Math<Float>.V3       = (0, 0, 0)

    private
    var originAngle:Math<Float>.S2 = (0, 0),
        originPivot:Math<Float>.V3 = (0, 0, 0)


    static
    func create(hscreen:Math<Float>.V2, vscreen:Math<Float>.V2,
        z:Math<Float>.V2 = (-1000, -1), scale:Float = 0.001)
        -> GLCameraRig
    {
        let camera = GLCamera.create(   x: Math.scale(hscreen, by: scale),
                                        y: Math.scale(vscreen, by: scale),
                                        z: z)
        return GLCameraRig( camera: camera,
                            vanishingPoint: (-hscreen.0, -vscreen.0), scale: scale)
    }

    func destroy()
    {
        self.camera.destroy()
    }

    private
    init(camera:GLCamera, vanishingPoint:Math<Float>.V2, scale:Float)
    {
        self.camera         = camera
        self.vanishingPoint = vanishingPoint
        self.scale          = scale
    }

    mutating
    func setDimensions(hscreen:Math<Float>.V2, vscreen:Math<Float>.V2)
    {
        self.vanishingPoint = (-hscreen.0, -vscreen.0)
        self.camera.x       = Math.scale(hscreen, by: self.scale)
        self.camera.y       = Math.scale(vscreen, by: self.scale)
        self.camera.updateProjection()
        self.camera.updateWorld(vanishingPoint: self.vanishingPoint, scale: self.scale)
    }

    private mutating
    func updateVectors()
    {
        // Math.cartesian already evaluates _sin(self.angle.φ) and _cos(self.angle.φ)
        // so when it gets inlines it this method of computing tangent will get
        // factored into common sub expressions
        let normal:Math<Float>.V3  = Math.cartesian(self.angle),
            tangent:Math<Float>.V3 = (-_sin(self.angle.φ), _cos(self.angle.φ), 0)
        self.camera.updateView( normal:   normal,
                                tangent:  tangent,
                                position: Math.scadd(self.pivot, normal, self.distance))
        self.camera.updateWorld(vanishingPoint: self.vanishingPoint, scale: self.scale)
    }

    mutating
    func jump(pivot:Math<Float>.V3, angle:Math<Float>.S2, distance:Float)
    {
        self.distance = distance
        self.angle    = angle
        self.pivot    = pivot
        self.updateVectors()
        self.rebase()
    }

    mutating
    func dolly(distance:Float)
    {
        self.distance = distance
        self.updateVectors()
    }

    mutating
    func pan(displacement:Math<Float>.V2)
    {
        self.angle.φ = self.originAngle.φ + displacement.x
        self.angle.θ = self.originAngle.θ - displacement.y
        self.angle.θ = max(0, min(Float.pi, self.angle.θ))
        self.updateVectors()
    }

    mutating
    func orbit(displacement:Math<Float>.V2)
    {
        self.pan(displacement: Math.neg(displacement))
    }

    mutating
    func track(displacement:Math<Float>.V2)
    {
        let tangent:Math<Float>.V3   = self.camera.tangent,
            bitangent:Math<Float>.V3 = self.camera.bitangent

        self.pivot = Math.add(self.originPivot,
            (Math.dot(displacement, (tangent.x, bitangent.x)),
             Math.dot(displacement, (tangent.y, bitangent.y)),
             Math.dot(displacement, (tangent.z, bitangent.z))))
        self.updateVectors()
    }

    mutating
    func rebase()
    {
        self.originAngle = self.angle
        self.originPivot = self.pivot
    }

    mutating
    func setAngle(_ angle:Math<Float>.S2)
    {
        self.angle       = angle
        self.originAngle = angle
        self.updateVectors()
    }
    mutating
    func setPivot(_ pivot:Math<Float>.V3)
    {
        self.pivot       = pivot
        self.originPivot = pivot
        self.updateVectors()
    }
    mutating
    func setDistance(_ distance:Float)
    {
        self.distance = distance
        self.updateVectors()
    }

    func activate()
    {
        self.camera.activate()
    }
}
