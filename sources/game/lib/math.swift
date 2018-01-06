import func Glibc.asin
import func Glibc.acos
import func Glibc.atan2

protocol RandomBinaryGenerator
{
    associatedtype RandomNumber where RandomNumber:UnsignedInteger,
                                      RandomNumber:FixedWidthInteger

    mutating func generate() -> RandomNumber
    mutating func generate(lessThan:RandomNumber) -> RandomNumber
}
extension RandomBinaryGenerator
{
    mutating
    func generate(lessThan maximum:RandomNumber) -> RandomNumber
    {
        let upperBound:RandomNumber = RandomNumber.max - RandomNumber.max % maximum
        var x:RandomNumber = self.generate()
        while x >= upperBound
        {
            x = self.generate()
        }

        return x % maximum
    }

    // generates a floating number in range [0, 1)
    mutating
    func generateFloat<F>() -> F where F:BinaryFloatingPoint, RandomNumber == F.RawSignificand
    {
        return F(sign: .plus,
                 exponentBitPattern: (1.0 as F).binade.exponentBitPattern,
                 significandBitPattern: self.generate()) - 1
    }

    mutating
    func generateUnitFloat3<F>() -> Math<F>.V3 where F:BinaryFloatingPoint, RandomNumber == F.RawSignificand
    {
        let v:Math<F>.V3 = (0.5 - self.generateFloat(),
                            0.5 - self.generateFloat(),
                            0.5 - self.generateFloat())

        // this really shouldn’t go on more than a couple frames deep
        let r2:F = Math.dot(v, v)
        guard r2 > 0, r2 <= 0.25
        else
        {
            return self.generateUnitFloat3()
        }

        return Math.scale(v, by: 1 / r2.squareRoot())
    }
}

struct RandomXorshift:RandomBinaryGenerator
{
    private
    var state128:(UInt32, UInt32, UInt32, UInt32)

    init(seed:Int)
    {
        self.state128 = (1, 0, UInt32(truncatingIfNeeded: seed >> UInt32.bitWidth), UInt32(truncatingIfNeeded: seed))
    }

    mutating
    func generate() -> UInt32
    {
        var t:UInt32 = self.state128.3
        t ^= t &<< 11
        t ^= t &>> 8
        self.state128.3 = self.state128.2
        self.state128.2 = self.state128.1
        self.state128.1 = self.state128.0
        t ^= self.state128.0
        t ^= self.state128.0 &>> 19
        self.state128.0 = t
        return t
    }

    mutating
    func generateSymmetric() -> Int32
    {
        return Int32(bitPattern: self.generate())
    }
}

protocol _SwiftFloatingPoint:FloatingPoint
{
    static func sin(_:Self) -> Self
    static func cos(_:Self) -> Self
    static func asin(_:Self) -> Self
    static func acos(_:Self) -> Self
    static func atan2(_:Self, _:Self) -> Self
}
extension Float:_SwiftFloatingPoint
{
    @inline(__always)
    static
    func sin(_ x:Float) -> Float
    {
        return _sin(x)
    }

    @inline(__always)
    static
    func cos(_ x:Float) -> Float
    {
        return _cos(x)
    }

    @inline(__always)
    static
    func asin(_ x:Float) -> Float
    {
        return Glibc.asin(x)
    }

    @inline(__always)
    static
    func acos(_ x:Float) -> Float
    {
        return Glibc.acos(x)
    }

    @inline(__always)
    static
    func atan2(_ y:Float, _ x:Float) -> Float
    {
        return Glibc.atan2(y, x)
    }
}
extension Double:_SwiftFloatingPoint
{
    @inline(__always)
    static
    func sin(_ x:Double) -> Double
    {
        return _sin(x)
    }

    @inline(__always)
    static
    func cos(_ x:Double) -> Double
    {
        return _cos(x)
    }

    @inline(__always)
    static
    func asin(_ x:Double) -> Double
    {
        return Glibc.asin(x)
    }

    @inline(__always)
    static
    func acos(_ x:Double) -> Double
    {
        return Glibc.acos(x)
    }

    @inline(__always)
    static
    func atan2(_ y:Double, _ x:Double) -> Double
    {
        return Glibc.atan2(y, x)
    }
}

enum Math<N>
{
    typealias V2 = (x:N, y:N)
    typealias V3 = (x:N, y:N, z:N) 

    @inline(__always)
    static
    func copy(_ v:V2, to ptr:UnsafeMutablePointer<N>)
    {
        ptr[0] = v.x
        ptr[1] = v.y
    }
    @inline(__always)
    static
    func copy(_ v:V3, to ptr:UnsafeMutablePointer<N>)
    {
        ptr[0] = v.x
        ptr[1] = v.y
        ptr[2] = v.z
    }

    @inline(__always)
    static
    func load(from ptr:UnsafeMutablePointer<N>) -> V2
    {
        return (ptr[0], ptr[1])
    }
    @inline(__always)
    static
    func load(from ptr:UnsafeMutablePointer<N>) -> V3
    {
        return (ptr[0], ptr[1], ptr[2])
    }
}

extension Math where N:Numeric
{
    @inline(__always)
    static
    func sum(_ v:V2) -> N
    {
        return v.x + v.y
    }
    @inline(__always)
    static
    func sum(_ v:V3) -> N
    {
        return v.x + v.y + v.z
    }

    @inline(__always)
    static
    func add(_ v1:V2, _ v2:V2) -> V2
    {
        return (v1.x + v2.x, v1.y + v2.y)
    }
    @inline(__always)
    static
    func add(_ v1:V3, _ v2:V3) -> V3
    {
        return (v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
    }

    @inline(__always)
    static
    func sub(_ v1:V2, _ v2:V2) -> V2
    {
        return (v1.x - v2.x, v1.y - v2.y)
    }
    @inline(__always)
    static
    func sub(_ v1:V3, _ v2:V3) -> V3
    {
        return (v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)
    }

    @inline(__always)
    static
    func vol(_ v:V2) -> N
    {
        return v.x * v.y
    }
    @inline(__always)
    static
    func vol(_ v:V3) -> N
    {
        return v.x * v.y * v.z
    }

    @inline(__always)
    static
    func mult(_ v1:V2, _ v2:V2) -> V2
    {
        return (v1.x * v2.x, v1.y * v2.y)
    }
    @inline(__always)
    static
    func mult(_ v1:V3, _ v2:V3) -> V3
    {
        return (v1.x * v2.x, v1.y * v2.y, v1.z * v2.z)
    }

    @inline(__always)
    static
    func scale(_ v:V2, by c:N) -> V2
    {
        return (v.x * c, v.y * c)
    }
    @inline(__always)
    static
    func scale(_ v:V3, by c:N) -> V3
    {
        return (v.x * c, v.y * c, v.z * c)
    }

    @inline(__always)
    static
    func dot(_ v1:V2, _ v2:V2) -> N
    {
        return v1.x * v2.x + v1.y * v2.y
    }
    @inline(__always)
    static
    func dot(_ v1:V3, _ v2:V3) -> N
    {
        return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
    }

    @inline(__always)
    static
    func eusq(_ v:V2) -> N
    {
        return v.x * v.x + v.y * v.y
    }
    @inline(__always)
    static
    func eusq(_ v:V3) -> N
    {
        return v.x * v.x + v.y * v.y + v.z * v.z
    }

    @inline(__always)
    static
    func cross(_ v1:V3, _ v2:V3) -> V3
    {
        return (v1.y*v2.z - v2.y*v1.z, v1.z*v2.x - v2.z*v1.x, v1.x*v2.y - v2.x*v1.y)
    }
}

extension Math where N:SignedNumeric
{
    @inline(__always)
    static
    func neg(_ v:V2) -> V2
    {
        return (-v.x, -v.y)
    }
    @inline(__always)
    static
    func neg(_ v:V3) -> V3
    {
        return (-v.x, -v.y, -v.z)
    }
}
extension Math where N:FloatingPoint, N.Magnitude == N
{
    @inline(__always)
    static
    func abs(_ v:V2) -> V2
    {
        return (Swift.abs(v.x), Swift.abs(v.y))
    }
    @inline(__always)
    static
    func abs(_ v:V3) -> V3
    {
        return (Swift.abs(v.x), Swift.abs(v.y), Swift.abs(v.z))
    }
}
extension Math where N:SignedNumeric, N.Magnitude == N
{
    @inline(__always)
    static
    func abs(_ v:V2) -> V2
    {
        return (Swift.abs(v.x), Swift.abs(v.y))
    }
    @inline(__always)
    static
    func abs(_ v:V3) -> V3
    {
        return (Swift.abs(v.x), Swift.abs(v.y), Swift.abs(v.z))
    }
}
extension Math where N:Comparable, N:SignedNumeric
{
    @inline(__always)
    static
    func abs(_ v:V2) -> V2
    {
        return (Swift.abs(v.x), Swift.abs(v.y))
    }
    @inline(__always)
    static
    func abs(_ v:V3) -> V3
    {
        return (Swift.abs(v.x), Swift.abs(v.y), Swift.abs(v.z))
    }
}

extension Math where N:BinaryFloatingPoint
{
    @inline(__always)
    static
    func cast<I>(_ v:V2, as _:I.Type) -> Math<I>.V2 where I:BinaryInteger
    {
        return (I(v.x), I(v.y))
    }
    @inline(__always)
    static
    func cast<I>(_ v:V3, as _:I.Type) -> Math<I>.V3 where I:BinaryInteger
    {
        return (I(v.x), I(v.y), I(v.z))
    }
}
extension Math where N:BinaryInteger
{
    @inline(__always)
    static
    func cast<I>(_ v:V2, as _:I.Type) -> Math<I>.V2 where I:BinaryInteger
    {
        return (I(v.x), I(v.y))
    }
    @inline(__always)
    static
    func cast<I>(_ v:V3, as _:I.Type) -> Math<I>.V3 where I:BinaryInteger
    {
        return (I(v.x), I(v.y), I(v.z))
    }

    @inline(__always)
    static
    func idiv(_ dividend:V2, by divisor:V2) -> Math<(N, N)>.V2
    {
        return (dividend.x.quotientAndRemainder(dividingBy: divisor.x),
                dividend.y.quotientAndRemainder(dividingBy: divisor.y))
    }
    @inline(__always)
    static
    func idiv(_ dividend:V3, by divisor:V3) -> Math<(N, N)>.V3
    {
        return (dividend.x.quotientAndRemainder(dividingBy: divisor.x),
                dividend.y.quotientAndRemainder(dividingBy: divisor.y),
                dividend.z.quotientAndRemainder(dividingBy: divisor.z))
    }
}
extension Math where N == Int32
{
    @inline(__always)
    static
    func castFloat(_ v:V2) -> Math<Float>.V2
    {
        return (Float(v.x), Float(v.y))
    }
    @inline(__always)
    static
    func castFloat(_ v:V3) -> Math<Float>.V3
    {
        return (Float(v.x), Float(v.y), Float(v.z))
    }

    @inline(__always)
    static
    func castDouble(_ v:V2) -> Math<Double>.V2
    {
        return (Double(v.x), Double(v.y))
    }
    @inline(__always)
    static
    func castDouble(_ v:V3) -> Math<Double>.V3
    {
        return (Double(v.x), Double(v.y), Double(v.z))
    }
}
extension Math where N == Int
{
    @inline(__always)
    static
    func castFloat(_ v:V2) -> Math<Float>.V2
    {
        return (Float(v.x), Float(v.y))
    }
    @inline(__always)
    static
    func castFloat(_ v:V3) -> Math<Float>.V3
    {
        return (Float(v.x), Float(v.y), Float(v.z))
    }

    @inline(__always)
    static
    func castDouble(_ v:V2) -> Math<Double>.V2
    {
        return (Double(v.x), Double(v.y))
    }
    @inline(__always)
    static
    func castDouble(_ v:V3) -> Math<Double>.V3
    {
        return (Double(v.x), Double(v.y), Double(v.z))
    }
}

extension Math where N:FloatingPoint
{
    @inline(__always)
    static
    func div(_ v1:V2, _ v2:V2) -> V2
    {
        return (v1.x / v2.x, v1.y / v2.y)
    }
    @inline(__always)
    static
    func div(_ v1:V3, _ v2:V3) -> V3
    {
        return (v1.x / v2.x, v1.y / v2.y, v1.z / v2.z)
    }

    @inline(__always)
    static
    func madd(_ v1:V2, _ v2:V2, _ v3:V2) -> V2
    {
        return (v1.x.addingProduct(v2.x, v3.x), v1.y.addingProduct(v2.y, v3.y))
    }
    @inline(__always)
    static
    func madd(_ v1:V3, _ v2:V3, _ v3:V3) -> V3
    {
        return (v1.x.addingProduct(v2.x, v3.x), v1.y.addingProduct(v2.y, v3.y), v1.z.addingProduct(v2.z, v3.z))
    }

    @inline(__always)
    static
    func scadd(_ v1:V2, _ v2:V2, _ c:N) -> V2
    {
        return (v1.x.addingProduct(v2.x, c), v1.y.addingProduct(v2.y, c))
    }
    @inline(__always)
    static
    func scadd(_ v1:V3, _ v2:V3, _ c:N) -> V3
    {
        return (v1.x.addingProduct(v2.x, c), v1.y.addingProduct(v2.y, c), v1.z.addingProduct(v2.z, c))
    }

    @inline(__always)
    static
    func lerp(_ v1:V2, _ v2:V2, _ t:N) -> V2
    {
        return (v1.x.addingProduct(-t, v1.x).addingProduct(t, v2.x),
                v1.y.addingProduct(-t, v1.y).addingProduct(t, v2.y))
    }
    @inline(__always)
    static
    func lerp(_ v1:V3, _ v2:V3, _ t:N) -> V3
    {
        return (v1.x.addingProduct(-t, v1.x).addingProduct(t, v2.x),
                v1.y.addingProduct(-t, v1.y).addingProduct(t, v2.y),
                v1.z.addingProduct(-t, v1.z).addingProduct(t, v2.z))
    }

    @inline(__always)
    static
    func length(_ v:V2) -> N
    {
        return Math.eusq(v).squareRoot()
    }
    @inline(__always)
    static
    func length(_ v:V3) -> N
    {
        return Math.eusq(v).squareRoot()
    }

    @inline(__always)
    static
    func normalize(_ v:V2) -> V2
    {
        return Math.scale(v, by: 1 / Math.eusq(v).squareRoot())
    }
    @inline(__always)
    static
    func normalize(_ v:V3) -> V3
    {
        return Math.scale(v, by: 1 / Math.eusq(v).squareRoot())
    }
}
extension Math where N == Double
{
    @inline(__always)
    static
    func castFloat(_ v:V2) -> Math<Float>.V2
    {
        return (Float(v.x), Float(v.y))
    }
    @inline(__always)
    static
    func castFloat(_ v:V3) -> Math<Float>.V3
    {
        return (Float(v.x), Float(v.y), Float(v.z))
    }
}
extension Math where N == Float
{
    @inline(__always)
    static
    func castDouble(_ v:V2) -> Math<Double>.V2
    {
        return (Double(v.x), Double(v.y))
    }
    @inline(__always)
    static
    func castDouble(_ v:V3) -> Math<Double>.V3
    {
        return (Double(v.x), Double(v.y), Double(v.z))
    }
}

extension Math where N:_SwiftFloatingPoint
{
    typealias S2 = (θ:N, φ:N) // θ = latitude, φ = longitude

    @inline(__always)
    static
    func cartesian(_ s:S2) -> V3
    {
        return (N.sin(s.θ) * N.cos(s.φ), N.sin(s.θ) * N.sin(s.φ), N.cos(s.θ))
    }

    @inline(__always)
    static
    func spherical(_ c:V3) -> S2
    {
        return (N.acos(c.z / length(c)), N.atan2(c.y, c.x))
    }

    @inline(__always)
    static
    func spherical(normalized c:V3) -> S2
    {
        return (N.acos(c.z), N.atan2(c.y, c.x))
    }
}

extension Array
{
    @inline(__always)
    mutating
    func append(vector:Math<Element>.V2)
    {
        self.append(vector.x)
        self.append(vector.y)
    }

    @inline(__always)
    mutating
    func append(vector:Math<Element>.V3)
    {
        self.append(vector.x)
        self.append(vector.y)
        self.append(vector.z)
    }
}

struct Quaternion
{
    private
    let v:Math<Float>.V3,
        r:Float

    private
    var length:Float
    {
        return (Math.dot(self.v, self.v) + self.r * self.r).squareRoot()
    }

    private
    init(_ v:Math<Float>.V3, _ r:Float) // private to prevent invalid quaternions from being created
    {
        self.v = v
        self.r = r
    }

    init()
    {
        self.init((0, 0, 0), 1)
    }

    init(axis:Math<Float>.V3, θ:Float)
    {
        self.r = _cos(0.5 * θ)
        self.v = Math.scale(axis, by: _sin(0.5 * θ))
    }

    func matrix() -> [Float]
    {
        let v2:Math<Float>.V3  = Math.mult(self.v, self.v),

            xy2:Float = 2 * self.v.x * self.v.y,
            xz2:Float = 2 * self.v.x * self.v.z,
            yz2:Float = 2 * self.v.y * self.v.z,

            rv_v:Math<Float>.V3 = Math.scale(self.v, by: 2 * self.r)
        //fill in the first row
        return [1 - 2*(v2.y + v2.z) , xy2 + rv_v.z          , xz2 - rv_v.y      ,
                xy2 - rv_v.z        , 1 - 2*(v2.x + v2.z)   , yz2 + rv_v.x      ,
                xz2 + rv_v.y        , yz2 - rv_v.x          , 1 - 2*(v2.x + v2.y)]
    }

    func unit() -> Quaternion
    {
        let norm = 1 / self.length
        return Quaternion(Math.scale(self.v, by: norm), self.r * norm)
    }

    static
    func * (lhs:Quaternion, rhs:Quaternion) -> Quaternion
    {
        return Quaternion( (rhs.r*lhs.v.x + rhs.v.x*lhs.r   - rhs.v.y*lhs.v.z + rhs.v.z*lhs.v.y,
                            rhs.r*lhs.v.y + rhs.v.z*lhs.v.z + rhs.v.y*lhs.r   - rhs.v.z*lhs.v.x,
                            rhs.r*lhs.v.z - rhs.v.x*lhs.v.y + rhs.v.y*lhs.v.x + rhs.v.z*lhs.r),
                            rhs.r*lhs.r   - rhs.v.x*lhs.v.x - rhs.v.y*lhs.v.y - rhs.v.z*lhs.v.z
                          )
    }
}
