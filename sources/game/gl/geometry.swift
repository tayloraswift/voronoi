import OpenGL

extension GL
{
    enum IntAttribute
    {
        case int, int2, int3, int4,
             uint, uint2, uint3, uint4,
             short, short2, short3, short4,
             ushort, ushort2, ushort3, ushort4,
             byte, byte2, byte3, byte4,
             ubyte, ubyte2, ubyte3, ubyte4

        var count:GL.Int
        {
            switch self
            {
            case .int, .uint, .short, .ushort, .byte, .ubyte:
                return 1
            case .int2, .uint2, .short2, .ushort2, .byte2, .ubyte2:
                return 2
            case .int3, .uint3, .short3, .ushort3, .byte3, .ubyte3:
                return 3
            case .int4, .uint4, .short4, .ushort4, .byte4, .ubyte4:
                return 4
            }
        }

        var size:Swift.Int
        {
            switch self
            {
            case .int4, .uint4:
                return 16
            case .int2, .uint2, .short4, .ushort4:
                return 8
            case .int, .uint, .short2, .ushort2, .byte4, .ubyte4:
                return 4
            case .short, .ushort, .byte2, .ubyte2:
                return 2
            case .byte, .ubyte:
                return 1
            case .byte3, .ubyte3:
                return 3
            case .short3, .ushort3:
                return 6
            case .int3, .uint3:
                return 12
            }
        }

        var typeCode:GL.Enum
        {
            switch self
            {
            case .int, .int2, .int3, .int4:
                return GL.INT
            case .uint, .uint2, .uint3, .uint4:
                return GL.UNSIGNED_INT
            case .short, .short2, .short3, .short4:
                return GL.SHORT
            case .ushort, .ushort2, .ushort3, .ushort4:
                return GL.UNSIGNED_SHORT
            case .byte, .byte2, .byte3, .byte4:
                return GL.BYTE
            case .ubyte, .ubyte2, .ubyte3, .ubyte4:
                return GL.UNSIGNED_BYTE
            }
        }

        func setPointer(index:Swift.Int, stride:Swift.Int, byteOffset:Swift.Int)
        {
            glVertexAttribIPointer( index  : GL.UInt(index),
                                    size   : self.count,
                                    type   : self.typeCode,
                                    stride : GL.Size(stride),
                                    pointer: UnsafeRawPointer(bitPattern: byteOffset))
            glEnableVertexAttribArray(GL.UInt(index))
        }
    }
    enum FloatAttribute
    {
        case double, double2, double3, double4,
             float, float2, float3, float4,
             half, half2, half3, half4,
             ushort, ushort2, ushort3, ushort4,
             rgba32, bgra32,
             normal32

        var count:GL.Int
        {
            switch self
            {
            case .double, .float, .half, .ushort:
                return 1
            case .double2, .float2, .half2, .ushort2:
                return 2
            case .double3, .float3, .half3, .ushort3:
                return 3
            case .double4, .float4, .half4, .ushort4, .rgba32, .normal32:
                return 4
            case .bgra32:
                return GL.BGRA
            }
        }

        var size:Swift.Int
        {
            switch self
            {
            case .double4:
                return 32
            case .double3:
                return 24
            case .double2, .float4:
                return 16
            case .double, .float2, .half4, .ushort4:
                return 8
            case .float, .half2, .ushort2, .rgba32, .bgra32, .normal32:
                return 4
            case .half, .ushort:
                return 2
            case .half3, .ushort3:
                return 6
            case .float3:
                return 12
            }
        }

        var typeCode:GL.Enum
        {
            switch self
            {
            case .double, .double2, .double3, .double4:
                return GL.DOUBLE
            case .float, .float2, .float3, .float4:
                return GL.FLOAT
            case .half, .half2, .half3, .half4:
                return GL.HALF_FLOAT
            case .ushort, .ushort2, .ushort3, .ushort4:
                return GL.UNSIGNED_SHORT
            case .rgba32, .bgra32:
                return GL.UNSIGNED_BYTE
            case .normal32:
                return GL.INT_2_10_10_10_REV
            }
        }

        func setPointer(index:Swift.Int, stride:Swift.Int, byteOffset:Swift.Int,
            normalized:Swift.Bool = false)
        {
            glVertexAttribPointer(  index     : GL.UInt(index),
                                    size      : self.count,
                                    type      : self.typeCode,
                                    normalized: normalized,
                                    stride    : GL.Size(stride),
                                    pointer   : UnsafeRawPointer(bitPattern: byteOffset))
            glEnableVertexAttribArray(GL.UInt(index))
        }
    }

    enum VertexAttribute
    {
        case int(IntAttribute),
             float(FloatAttribute, Swift.Bool),
             padding(Swift.Int)

        var size:Swift.Int
        {
            switch self
            {
            case .int(let intAttribute):
                return intAttribute.size

            case .float(let floatAttribute, _):
                return floatAttribute.size

            case .padding(let byteCount):
                return byteCount
            }
        }
    }

    static
    func setVertexAttributeLayout(_ layout:VertexAttribute...)
    {
        let stride:Swift.Int     = layout.map{ $0.size }.reduce(0, +)
        var byteOffset:Swift.Int = 0,
            index:Swift.Int      = 0
        for attribute:VertexAttribute in layout
        {
            switch attribute
            {
            case .int(let intAttribute):
                intAttribute.setPointer(index: index, stride: stride,
                    byteOffset: byteOffset)
                byteOffset += intAttribute.size

            case .float(let floatAttribute, let normalize):
                floatAttribute.setPointer(index: index, stride: stride,
                    byteOffset: byteOffset, normalized: normalize)
                byteOffset += floatAttribute.size

            case .padding(let byteCount):
                byteOffset += byteCount
            }

            index += 1
        }
    }

    struct Buffer
    {
        fileprivate
        var id:GL.UInt

        // TODO: this is really the job of code generation, i don’t know if these
        // will change between opengl versions
        enum Usage:Enum
        {
            case staticDraw  = 0x88E4,
                 dynamicDraw = 0x88E8,
                 streamDraw  = 0x88E0
        }

        enum Target:Enum
        {
            case array        = 0x8892,
                 elementArray = 0x8893,
                 uniform      = 0x8A11

            func data<T>(_ data:[T], usage:Usage)
            {
                data.withUnsafeBufferPointer
                {
                    self.data(UnsafeRawBufferPointer($0), usage: usage)
                }
            }

            func data(_ data:UnsafeRawBufferPointer, usage:Usage)
            {
                glBufferData(target: self.rawValue, size: data.count, data: data.baseAddress, usage: usage.rawValue)
            }

            func data(reserveBytes byteCount:Swift.Int, usage:Usage)
            {
                glBufferData(target: self.rawValue, size: byteCount, data: nil, usage: usage.rawValue)
            }

            func subData<T>(_ data:[T], offset:Swift.Int = 0)
            {
                data.withUnsafeBufferPointer
                {
                    self.subData(UnsafeRawBufferPointer($0), offset: offset)
                }
            }

            func subData(_ data:UnsafeRawBufferPointer, offset:Swift.Int = 0)
            {
                glBufferSubData(target: self.rawValue, offset: offset, size: data.count, data: data.baseAddress)
            }

            func bindRange(start:Swift.Int, count:Swift.Int, of buffer:Buffer, toIndex index:GL.UInt)
            {
                glBindBufferRange(  target: self.rawValue,
                                    index : index,
                                    buffer: buffer.id,
                                    offset: start,
                                    size  : count)
            }
        }

        static
        func generate() -> Buffer
        {
            var buffer = Buffer(id: 0)
            glGenBuffers(n: 1, buffers: &buffer.id)
            return buffer
        }

        func destroy()
        {
            var id:GL.UInt = self.id
            glDeleteBuffers(n: 1, buffers: &id)
        }

        func bind<Result>(to target:Target, _ body: () -> Result)
            -> Result
        {
            glBindBuffer(target: target.rawValue, buffer: self.id)
            defer
            {
                glBindBuffer(target: target.rawValue, buffer: 0)
            }

            return body()
        }
    }

    struct VertexArray
    {
        private
        var id:GL.UInt

        static
        func generate() -> VertexArray
        {
            var array = VertexArray(id: 0)
            glGenVertexArrays(n: 1, arrays: &array.id)
            return array
        }

        func destroy()
        {
            var id:GL.UInt = self.id
            glDeleteVertexArrays(n: 1, arrays: &id)
        }

        func bind()
        {
            glBindVertexArray(self.id)
        }

        func unbind()
        {
            glBindVertexArray(0)
        }

        func bind<Result>(_ body: () -> Result) -> Result
        {
            self.bind()
            defer
            {
                self.unbind()
            }

            return body()
        }

        func draw(start:Swift.Int = 0, count:Swift.Int, mode:GL.Enum = GL.TRIANGLES)
        {
            self.bind
            {
                glDrawElements(mode: mode, count: GL.Size(count),
                    type: GL.UNSIGNED_INT, indices: UnsafeRawPointer(bitPattern: start * MemoryLayout<GL.UInt>.stride))
            }
        }
    }
}

/*
struct GLVertexBuffer
{
    private
    let id:GL.UInt

    static
    func create() -> GLVertexBuffer
    {

    }
}


struct GLVertexArray
{
    private
    let n:GL.Size,      // vertex indices count
        raw_count:Int,  // buffer size in bytes

        VBO:GL.UInt,
        EBO:GL.UInt,
        VAO:GL.UInt

    static
    func validate(coordinates:[Float], indices:[UInt32], layout:[Int]) -> GLVertexArray?
    {
        guard layout.count <= 16
        else
        {
            print("Error: \(layout.count) attributes were given but most graphics cards only support up to 16")
            return nil
        }

        let k:Int = coordinates.count // number of coordinates stored
        let m:Int = layout.reduce(0, +) // coordinates per point
        guard (k % m) == 0 && k > 0
        else
        {
            print("Error: \(k) coordinates were given, but \(k) is not divisible into \(m)-tuples")
            return nil
        }
        let p:UInt32 = UInt32(k / m) // number of unique physical points defined

        // validate indices
        for index in indices
        {
            if index >= p
            {
                print("Error: indices contain value \(index) but there are only \(p) points")
                return nil
            }
        }

        return coordinates.withUnsafeBufferPointer
        {
            (cb:UnsafeBufferPointer<Float>) in

            return indices.withUnsafeBufferPointer
            {
                (ib:UnsafeBufferPointer<UInt32>) in
                return GLVertexArray(   coordinates: cb, indices: ib, layout: layout,
                                        stride: GL.Size(m * MemoryLayout<Float>.size))
            }
        }
    }

    static
    func create(coordinates:[Float], indices:[GL.UInt], layout:[Int])
        -> GLVertexArray
    {
        return coordinates.withUnsafeBufferPointer
        {
            (cb:UnsafeBufferPointer<Float>) in

            return indices.withUnsafeBufferPointer
            {
                (ib:UnsafeBufferPointer<GL.UInt>) in
                return GLVertexArray.create(coordinates: cb, indices: ib, layout: layout)
            }
        }
    }

    static
    func create(coordinates:UnsafeBufferPointer<Float>, indices:UnsafeBufferPointer<GL.UInt>, layout:[Int])
        -> GLVertexArray
    {
        return GLVertexArray(   coordinates: coordinates, indices: indices, layout: layout,
                                stride: GL.Size(layout.reduce(0, +) * MemoryLayout<Float>.size))
    }

    private
    init(coordinates:UnsafeBufferPointer<Float>, indices:UnsafeBufferPointer<GL.UInt>, layout:[Int], stride:GL.Size)
    {
        var VAO:GL.UInt = 0
        glGenVertexArrays(n: 1, arrays: &VAO)
        glBindVertexArray(VAO)

        var buffers:(VBO:GL.UInt, EBO:GL.UInt) = (0, 0)
        withUnsafeMutablePointer(to: &buffers)
        {
            $0.withMemoryRebound(to: UInt32.self, capacity: 2)
            {
                glGenBuffers(n: 2, buffers: $0)
            }
        }

        glBindBuffer(target: GL.ARRAY_BUFFER, buffer: buffers.VBO)
        glBufferData(   target: GL.ARRAY_BUFFER,
                        size  : coordinates.count * MemoryLayout<Float>.size,
                        data  : coordinates.baseAddress,
                        usage : GL.STATIC_DRAW)

        var offset:Int = 0,
            index:GL.UInt = 0
        for l in layout
        {
            glVertexAttribPointer(  index     : index,
                                    size      : GL.Int(l),
                                    type      : GL.FLOAT,
                                    normalized: false,
                                    stride    : stride,
                                    pointer   : UnsafeRawPointer(bitPattern: offset * MemoryLayout<Float>.size))
            glEnableVertexAttribArray(index)
            offset += l
            index  += 1
        }

        glBindBuffer(target: GL.ELEMENT_ARRAY_BUFFER, buffer: buffers.EBO)
        glBufferData(   target: GL.ELEMENT_ARRAY_BUFFER,
                        size  : indices.count * MemoryLayout<GL.UInt>.size,
                        data  : indices.baseAddress,
                        usage : GL.STATIC_DRAW)

        glBindVertexArray(0)
        // unbind buffers *after* unbinding vertex array
        glBindBuffer(target: GL.ARRAY_BUFFER, buffer: 0)
        glBindBuffer(target: GL.ELEMENT_ARRAY_BUFFER, buffer: 0)

        self.n         = GL.Size(indices.count)
        self.raw_count = coordinates.count * MemoryLayout<Float>.size
        self.VBO = buffers.VBO
        self.EBO = buffers.EBO
        self.VAO = VAO
    }

    mutating
    func assign_coordinates(from source:UnsafePointer<Float>)
    {
        glBindBuffer(target: GL.ARRAY_BUFFER, buffer: self.VBO)
        glBufferSubData(GL.ARRAY_BUFFER, 0, self.raw_count, source)
        glBindBuffer(target: GL.ARRAY_BUFFER, buffer: 0)
    }

    func deinitialize()
    {
        glDeleteBuffers(n: 2, buffers: [self.VBO, self.EBO])
        glDeleteVertexArrays(n: 1, arrays: [self.VAO])
    }

    func draw(mode:GL.Enum = GL.TRIANGLES)
    {
        glBindVertexArray(self.VAO)
        glDrawElements(mode: mode, count: self.n, type: GL.UNSIGNED_INT, indices: nil)
        glBindVertexArray(0)
    }
}
*/
