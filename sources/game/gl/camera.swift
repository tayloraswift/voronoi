import OpenGL

struct Viewport
{
    var resolution:Math<Float>.V2,
        center:Math<Float>.V2,
        offset:Math<Float>.V2

    init(symmetric:Math<Float>.V2, offset:Math<Float>.V2 = (0, 0))
    {
        self.init(symmetric, center: Math.scale(symmetric, by: 0.5), offset: offset)
    }

    init(_ resolution:Math<Float>.V2, center:Math<Float>.V2,
        offset:Math<Float>.V2 = (0, 0))
    {
        self.resolution = resolution
        self.center     = center
        self.offset     = offset
    }
}

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

    layout(std140) uniform CameraMatrixBlock
    {
        mat4 proj;    // [ 0  ..<  64]
        mat4 view;    // [64  ..< 128]
    };

    layout(std140) uniform CameraDataBlock
    {
        mat4  world;                // [  0 ..<  64]
        vec3  position;             // [ 64 ..<  76]
        float zFar;                 // [ 76 ..<  80]
        vec3  antinormal;           // [ 80 ..<  92]
        float zNear;                // [ 92 ..<  96]
        vec2  size;                 // [ 96 ..< 104]
        vec2  center;               // [104 ..< 112]

        vec2  viewportResolution;   // [112 ..< 120]
        vec2  viewportCenter;       // [120 ..< 128]
        vec2  viewportOffset;       // [128 ..< 136]
        float scale;                // [136 ..< 140] size = 140
    };
    */

    // p0 and p1 define the dimensions of the near plane
    // of the view frustum. p0.0 and p0.1 are generally negative. the width of
    // the near plane of the view frustum in world space is x.1 - x.0, and the
    // height is y.1 - y.0. z is not stored contiguously, but is made up of
    // the aggregate {zFar, zNear}. note that both coordinates are generally
    // negative, with zFar < zNear. 0 lies at the vertex of the view pyramid.

    private static
    let blockRanges:(BlockRange, BlockRange) =
    {
        var alignment:GL.Int = 0
        glGetIntegerv(pname: GL.UNIFORM_BUFFER_OFFSET_ALIGNMENT, data: &alignment)

        var blocks:(BlockRange, BlockRange)
        blocks.0 = (0, 128)
        blocks.1 = (align(blocks.0.start + blocks.0.count, to: Int(alignment)), 140)
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
            size:Int       = Offset.world + 24,
            center:Int     = Offset.world + 26,

            viewportResolution:Int = Offset.world + 28,
            viewportCenter:Int     = Offset.world + 30,
            viewportOffset:Int     = Offset.world + 32,
            scale:Int              = Offset.world + 34,

            __count__:Int = Offset.world + 35
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

    private
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
    private
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

    private
    var size:Math<Float>.V2
    {
        get
        {
            return Math.load(from: self.block + Offset.size)
        }
        set(size)
        {
            Math.copy(size, to: self.block + Offset.size)
        }
    }

    private
    var center:Math<Float>.V2
    {
        get
        {
            return Math.load(from: self.block + Offset.center)
        }
        set(center)
        {
            Math.copy(center, to: self.block + Offset.center)
        }
    }

    private
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

    var viewport:Viewport
    {
        get
        {
            let resolution:Math<Float>.V2 =
                    Math.load(from: self.block + Offset.viewportResolution),
                center:Math<Float>.V2     =
                    Math.load(from: self.block + Offset.viewportCenter),
                offset:Math<Float>.V2     =
                    Math.load(from: self.block + Offset.viewportOffset)
            return Viewport(resolution, center: center, offset: offset)
        }
        set(v)
        {
            Math.copy(v.resolution, to: self.block + Offset.viewportResolution)
            Math.copy(v.center    , to: self.block + Offset.viewportCenter)
            Math.copy(v.offset    , to: self.block + Offset.viewportOffset)
        }
    }

    private
    var scale:Float
    {
        get
        {
            return self.block[Offset.scale]
        }
        set(v)
        {
            self.block[Offset.scale] = v
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
    func create(viewport:Viewport, focalLength:Float, z:Math<Float>.V2) -> GLCamera
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

        camera.z        = z
        camera.viewport = viewport

        camera.calculateFrustum(focalLength: focalLength)

        camera.updateProjection()
        return camera
    }

    func destroy()
    {
        self.uniformBuffer.destroy()
        self.block.deallocate(capacity: Offset.__count__)
    }

    // focal length is 35mm equivalent
    mutating
    func calculateFrustum(focalLength:Float)
    {
        self.scale    = -self.z.1 * Math.length((24, 36)) /
                (focalLength * Math.length(self.viewport.resolution))
        self.size     = Math.scale(self.viewport.resolution, by: self.scale)
        self.center   = Math.scale(self.viewport.center    , by: self.scale)
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
        //  depth  = f - n
        //
        //  note: n and f are positive quantities, but self.z is a negative
        //  tuple following the conventions of OpenGL clip space

        let depth:Float    = self.z.1 - self.z.0,
            distance:Float = self.z.1 + self.z.0

        let displacement:Math<Float>.V2 =
                Math.sub(self.center, Math.scale(self.size, by: 0.5))

        self.proj[ 0] = -2 * self.z.1 / self.size.x
        self.proj[ 5] = -2 * self.z.1 / self.size.y
        self.proj[ 8] = displacement.x / self.size.x
        self.proj[ 9] = displacement.y / self.size.y
        self.proj[10] = distance / depth
        self.proj[14] = -2 * self.z.0 * self.z.1 / depth
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
    func updateWorld()
    {
        let center:Math<Float>.V2     = self.viewport.center

        let tangent:Math<Float>.V3    = self.tangent,
            bitangent:Math<Float>.V3  = self.bitangent,
            antinormal:Math<Float>.V3 = self.antinormal

            //  [0]: k Tx   [4]: k Bx   [ 8]: -Nx   [12]: -k(Tx vx + Bx vy)
            //  [1]: k Ty   [5]: k By   [ 9]: -Ny   [13]: -k(Ty vx + By vy)
            //  [2]: k Tz   [6]: k Bz   [10]: -Nz   [14]: -k(Tz vx + Bz vy)
            //  [3]: 0      [7]: 0      [11]:  0    [15]:  1

            let k:Float = self.scale / self.z.1
            Math.copy(Math.scale(  tangent, by: k), to: self.world)
            Math.copy(Math.scale(bitangent, by: k), to: self.world + 4)
            Math.copy(antinormal,                   to: self.world + 8)
            Math.copy(Math.scale(Math.add(Math.scale(tangent  , by: center.x),
                                          Math.scale(bitangent, by: center.y)),
                                 by: -k),           to: self.world + 12)
    }

    // returns a 3 × 3 normal matrix, transpose(inverse(view × model))
    func normalMatrix(modelMatrix:Math<Float>.Mat4) -> Math<Float>.Mat3
    {
        let V:(Math<Float>.V3, Math<Float>.V3, Math<Float>.V3, Math<Float>.V3) =
        (
            Math.load(from: self.view),
            Math.load(from: self.view + 4),
            Math.load(from: self.view + 8),
            Math.load(from: self.view + 12)
        )

        let M:(Math<Float>.V4, Math<Float>.V4, Math<Float>.V4) =
        (
            modelMatrix.0,
            modelMatrix.1,
            modelMatrix.2
        )

        let X:Math<Float>.Mat3 = Math.mult(V, M)

        let invDeterminant:Float = 1 / Math.dot(X.0, Math.cross(X.1, X.2))
        return (
            Math.scale(Math.cross(X.1, X.2), by: invDeterminant),
            Math.scale(Math.cross(X.2, X.0), by: invDeterminant),
            Math.scale(Math.cross(X.0, X.1), by: invDeterminant)
        )
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
    private(set)
    var camera:GLCamera,
        focalLength:Float

    private(set)
    var distance:Float             = 0,
        angle:Math<Float>.S2       = (0, 0),
        pivot:Math<Float>.V3       = (0, 0, 0)

    private
    var originAngle:Math<Float>.S2 = (0, 0),
        originPivot:Math<Float>.V3 = (0, 0, 0)


    static
    func create(viewport:Viewport, focalLength:Float, z:Math<Float>.V2 = (-1000, -1))
        -> GLCameraRig
    {
        let camera = GLCamera.create(viewport: viewport, focalLength: focalLength, z: z)
        return GLCameraRig(camera: camera, focalLength: focalLength)
    }

    func destroy()
    {
        self.camera.destroy()
    }

    private
    init(camera:GLCamera, focalLength:Float)
    {
        self.camera      = camera
        self.focalLength = focalLength
    }

    mutating
    func setViewport(_ viewport:Viewport)
    {
        self.camera.viewport = viewport
        self.camera.calculateFrustum(focalLength: self.focalLength)
        self.camera.updateProjection()
        self.camera.updateWorld()
    }

    mutating
    func zoom(focalLength:Float)
    {
        self.focalLength = focalLength
        self.camera.calculateFrustum(focalLength: self.focalLength)
        self.camera.updateProjection()
        self.camera.updateWorld()
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
        self.camera.updateWorld()
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
