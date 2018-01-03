import func Glibc.asin
import func Glibc.acos
import func Glibc.atan
import func Glibc.atan2

enum Tesselate<F> where F:BinaryFloatingPoint
{
    static
    func tesselate<Index>(_ triangle:(Math<F>.V3, Math<F>.V3, Math<F>.V3),
        maxUnit:F)
        -> (vertexData:[F], indices:[Index])
        where Index:BinaryInteger, Index.Stride:SignedInteger
    {
        //           lengths.2
        //            0 ———— 2
        //  lengths.0 |  ╱  lengths.1
        //            1

        let lengths:(F, F, F) = (Math.length(Math.sub(triangle.1, triangle.0)),
                                 Math.length(Math.sub(triangle.2, triangle.1)),
                                 Math.length(Math.sub(triangle.0, triangle.2)))
        var points:[Math<F>.V3] = [triangle.0, triangle.1, triangle.2]

        let shortest:[Index],
            cw:[Index],
            ccw:[Index]
        //              cw
        //           ↑ ———→
        //  shortest |  ↗ ccw

        // length(s1) ≥ length(s2) ⇒ subdivisions(of: s1) ≥ subdivisions(of: s2)
        // yes, even through the floating point division.
        if lengths.2 < lengths.1
        {
            // side 2 is the strictly shortest side
            //           shortest
            //           0 ———→ 2
            //       ccw ↓  ↙ cw
            //           1
            if lengths.2 < lengths.0
            {
                shortest = subdivide((0, 2),
                    n: subdivisions(lengths.2, maxUnit: maxUnit), points: &points)
                cw       = subdivide((2, 1),
                    n: subdivisions(lengths.1, maxUnit: maxUnit), points: &points)
                ccw      = subdivide((0, 1),
                    n: subdivisions(lengths.0, maxUnit: maxUnit), points: &points)
            }
            // side 0 is the shortest side
            //              cw
            //           0 ———→ 2
            //  shortest ↑  ↗ ccw
            //           1
            else
            {
                shortest    = subdivide((1, 0),
                    n: subdivisions(lengths.0, maxUnit: maxUnit), points: &points)
                cw          = subdivide((0, 2),
                    n: subdivisions(lengths.2, maxUnit: maxUnit), points: &points)
                ccw         = subdivide((1, 2),
                    n: subdivisions(lengths.1, maxUnit: maxUnit), points: &points)
            }
        }
        else
        {
            // side 1 is the shortest side
            //              ccw
            //            0 ←——— 2
            //         cw ↑  ↙ shortest
            //            1
            if lengths.1 < lengths.0
            {
                shortest    = subdivide((2, 1),
                    n: subdivisions(lengths.1, maxUnit: maxUnit), points: &points)
                cw          = subdivide((1, 0),
                    n: subdivisions(lengths.0, maxUnit: maxUnit), points: &points)
                ccw         = subdivide((2, 0),
                    n: subdivisions(lengths.2, maxUnit: maxUnit), points: &points)
            }
            // side 0 is the shortest side
            //              cw
            //           0 ———→ 2
            //  shortest ↑  ↗ ccw
            //           1
            else
            {
                shortest    = subdivide((1, 0),
                    n: subdivisions(lengths.0, maxUnit: maxUnit), points: &points)
                cw          = subdivide((0, 2),
                    n: subdivisions(lengths.2, maxUnit: maxUnit), points: &points)
                ccw         = subdivide((1, 2),
                    n: subdivisions(lengths.1, maxUnit: maxUnit), points: &points)
            }
        }

        // if n ≥ m, there exists an onto function from the points on the longest
        // side of the triangle to the points on the second-longest side of the
        // triangle.
        let bridged:[Index] = bridgeTriangle(cw: cw, ccw: ccw, base: shortest,
            maxUnit: maxUnit, points: &points)

        var vertexData:[F] = []
            vertexData.reserveCapacity(points.count * 3)
        for point:Math<F>.V3 in points
        {
            vertexData.append(vector: point)
        }

        return (vertexData, bridged)
    }

    // meshes a big triangle where base, leg1, and leg2 are oriented like this:
    //        cwBoundary
    //       ↑ ———→
    //  base |  ↗ ccwBoundary

    static
    func bridgeTriangle<Index>(cw cwBoundary:[Index], ccw ccwBoundary:[Index],
    base:[Index], maxUnit:F, points:inout [Math<F>.V3]) -> [Index]
        where Index:BinaryInteger, Index.Stride:SignedInteger
    {
        //  cwBoundary: v0 ——— v1 ——— v2 ———— v3 —— ··· —— vm  (m = count - 1)
        // ccwBoundary: u0 —— u2 —— u3 —— u4 —— u5 — ··· — un  (n = count - 1)
        // where n ≥ m
        var indices:[Index] = []

        var prevFar:Int = 0,
            prevBridge:[Index]
        let parallelBase:Bool,
            near:[Index],
            far:[Index]

        if ccwBoundary.count < cwBoundary.count
        {
            prevBridge   = base.reversed()
            parallelBase = false
            (near, far)  = (cwBoundary, ccwBoundary)
        }
        else
        {
            prevBridge   = base
            parallelBase = true
            (near, far)  = (ccwBoundary, cwBoundary)
        }

        for i:Int in 1 ..< near.count - 1
        {

            let currentFar:Int = bridge(i, of: near.count - 1, to: far.count - 1)

            let edge:(Index, Index) = (near[i], far[currentFar])
            let bridgeLength:F = Math.length(Math.sub(points[Int(edge.1)],
                                                      points[Int(edge.0)]))
            let currentBridge:[Index] = subdivide(edge,
                n: subdivisions(bridgeLength, maxUnit: maxUnit), points: &points)

            points.withUnsafeBufferPointer
            {
                (pointsBuffer:UnsafeBufferPointer<Math<F>.V3>) in
                prevBridge.withUnsafeBufferPointer
                {
                    (prevBuffer:UnsafeBufferPointer<Index>) in
                    currentBridge.withUnsafeBufferPointer
                    {
                        (currentBuffer:UnsafeBufferPointer<Index>) in

                        let  cw:UnsafeBufferPointer<Index>,
                            ccw:UnsafeBufferPointer<Index>

                        (cw, ccw) = parallelBase ? (prevBuffer, currentBuffer) :
                                                   (currentBuffer, prevBuffer)

                        if currentFar == prevFar
                        {
                            meshTriangle(vertex: far[currentFar],
                                cw:  UnsafeBufferPointer(rebasing:  cw.dropLast()),
                                ccw: UnsafeBufferPointer(rebasing: ccw.dropLast()),
                                points: pointsBuffer.baseAddress!,
                                indices: &indices)
                        }
                        else
                        {
                            meshQuad(cw: cw, ccw: ccw,
                                points: pointsBuffer.baseAddress!,
                                indices: &indices)
                        }
                    }
                }
            }

            prevFar    = currentFar
            prevBridge = currentBridge
        }

        prevBridge.withUnsafeBufferPointer
        {
            (buffer:UnsafeBufferPointer<Index>) in

            if parallelBase
            {
                meshFan( cw: buffer, around: far.last!, indices: &indices)
            }
            else
            {
                meshFan(ccw: buffer, around: far.last!, indices: &indices)
            }

        }

        return indices
    }

    static
    func bridge(_ i:Int, of near:Int, to far:Int) -> Int
    {
        // never allow a bridge to land on the last point (the vertex
        // between ccwBoundary and cwBoundary) because it causes degeneracies
        let halfIndex:Int = i * far << 1 / near
        // if halfIndex is odd, we round up, otherwise we round down
        // index     : [0       ][1       ][2       ][3       ][4
        // half index: [0  ][1  ][2  ][3  ][4  ][5  ][6  ][7  ]
        print("\(i) → \(Double(i) * Double(far) / Double(near)) [\((halfIndex + halfIndex & 1) >> 1)]")
        return min((halfIndex + halfIndex & 1) >> 1, far - 1)
    }

    // returns the number of points in the subdivision that produces no fragments
    // longer than maxUnit. if no subdivisions happen it returns 2 (for the two
    // original endpoints)
    static
    func subdivisions(_ length:F, maxUnit:F) -> Int
    {
        return Int((length / maxUnit).rounded(.up)) + 1
    }

    // creates n - 2 new points evenly spaced between edge.0 and edge.1, returning
    // an n-length list of all the points along the edge, adding points to the
    // input `points` vector if needed
    static
    func subdivide<Index>(_ edge:(Index, Index), n:Int, points:inout [Math<F>.V3])
        -> [Index] where Index:BinaryInteger
    {
        guard n > 2
        else
        {
            return [edge.0, edge.1]
        }

        let v1:Math<F>.V3 = points[Int(edge.0)],
            v2:Math<F>.V3 = points[Int(edge.1)]
        var indices:[Index] = [edge.0]
            indices.reserveCapacity(n)

        let ustep:F = 1 / F(n - 1)
        var index:Index = Index(points.count)
        for i:Int in 1 ..< n - 1
        {
            indices.append(index)
            points.append(Math.lerp(v1, v2, F(i) * ustep))
            index += 1
        }

        indices.append(edge.1)
        return indices
    }

    // meshes the given triangular fill. we can’t just glue the vertex onto cw
    // or ccw and feed it to meshQuad directly because it being collinear with
    // both sets of points causes weird degeneracies.
    //  cw ×-----------→
    //      \ / \ / \ / \
    //   ccw ×-------→ --o

    // cw and ccw each contain at least two indices to distinct points
    static
    func meshTriangle<Index>(vertex:Index, cw:UnsafeBufferPointer<Index>,
        ccw:UnsafeBufferPointer<Index>, points:UnsafePointer<Math<F>.V3>,
        indices:inout [Index])
        where Index:BinaryInteger
    {
        // lop off the pointy bit and send the rest to meshQuad
        indices.append(vector: (ccw.last!, vertex, cw.last!))
        meshQuad(cw: cw, ccw: ccw, points: points, indices: &indices)
    }

    // meshes the given quadrilateral
    //  cw ×-----------→
    //      \ / \ / \ /
    //   ccw ×-------→

    // cw and ccw each contain at least two indices to distinct points
    static
    func meshQuad<Index>(cw:UnsafeBufferPointer<Index>,
        ccw:UnsafeBufferPointer<Index>, points:UnsafePointer<Math<F>.V3>,
        indices:inout [Index])
        where Index:BinaryInteger
    {
        // since cw and ccw may not have the same number of points, two
        // “maximum parallelograms” can be carved out of them

        //        0   1   2   3            0   1   2          1   2   3
        //  cw[4] ×-----------→            ×--------          --------→
        //         \ / \ / \ /         →    \ / \ / \    ,   / \ / \ /
        //   ccw[3] ×-------→                ×-------→      ×-------→
        //          0   1   2                0   1   2      0   1   2

        // (if ccw and cw are the same size, the parallelograms are identical)

        // we choose the parallelogram with the shortest long diagonal (the min-max).
        // because they share one base, this gives us the least-slanted parallelogram
        // which we can use to form a regular triangle strip. then we just fan out
        // the remaining triangles to complete the mesh.

        let minBase:Int = min(cw.count, ccw.count)

        // early exit in case the quad is already a parallelogram
        guard cw.count != ccw.count
        else
        {
            meshParallelogram(cw: cw, ccw: ccw, points: points, indices: &indices)
            return
        }

        let diagonals1:(cw:F, ccw:F),
            diagonals2:(cw:F, ccw:F)

        diagonals1.cw  = (Math.eusq(Math.sub(points[Int( cw[0          ])],
                                             points[Int(ccw[minBase - 1])])))
        diagonals1.ccw = (Math.eusq(Math.sub(points[Int(ccw[0          ])],
                                             points[Int( cw[minBase - 1])])))

        diagonals2.cw  = (Math.eusq(Math.sub(points[Int( cw[ cw.count - minBase])],
                                             points[Int(ccw[ccw.count - 1      ])])))
        diagonals2.ccw = (Math.eusq(Math.sub(points[Int(ccw[ccw.count - minBase])],
                                             points[Int( cw[ cw.count - 1      ])])))

        if max(diagonals1.cw, diagonals1.ccw) < max(diagonals2.cw, diagonals2.ccw)
        {
            meshParallelogram(cw: UnsafeBufferPointer(rebasing:  cw.prefix(minBase)),
                             ccw: UnsafeBufferPointer(rebasing: ccw.prefix(minBase)),
                points: points, indices: &indices)

            //  cw ×--------       ------→
            //      \ / \ / \   +   \ | /
            //   ccw ×-------→        →
            if ccw.count < cw.count
            {
                meshFan(cw:  UnsafeBufferPointer(rebasing:  cw.dropFirst(minBase - 1)),
                        around: ccw.last!, indices: &indices)
            }
            //    cw ×-------→        →
            //      / \ / \ /   +   / | \
            // ccw ×--------       ------→
            else
            {
                meshFan(ccw: UnsafeBufferPointer(rebasing: ccw.dropFirst(minBase - 1)),
                        around: cw.last!, indices: &indices)
            }
        }
        else
        {
            meshParallelogram(cw: UnsafeBufferPointer(rebasing:  cw.suffix(minBase)),
                             ccw: UnsafeBufferPointer(rebasing: ccw.suffix(minBase)),
                points: points, indices: &indices)

            //  cw  ×------       --------→
            //       \ | /   +   / \ / \ /
            //  ccw    ×        ×-------→
            if ccw.count < cw.count
            {
                meshFan(cw:  UnsafeBufferPointer(rebasing:  cw.dropLast(minBase - 1)),
                        around: ccw.first!, indices: &indices)
            }
            //  cw     ×        ×-------→
            //       / | \   +   \ / \ / \
            //  ccw ×------       --------→
            else
            {
                meshFan(ccw: UnsafeBufferPointer(rebasing: ccw.dropLast(minBase - 1)),
                        around: cw.first!, indices: &indices)
            }
        }
    }

    // meshes the given trapezoid
    //      cw ×-----→
    //        / \ | / \
    //   ccw ×---------→

    // cw and ccw each contain at least two indices to distinct points and
    // have the same count
    static
    func meshParallelogram<Index>(cw:UnsafeBufferPointer<Index>,
        ccw:UnsafeBufferPointer<Index>, points:UnsafePointer<Math<F>.V3>,
        indices:inout [Index]) where Index:BinaryInteger
    {
        // all the shortest diagonals in the trapezoid cells begin to lean one
        // way until a certain zero-indexed cell floor(i) where they begin to lean
        // the opposite direction.

        //                  i
        //           0  1   2  3  (n = 4)
        //       a ↗---×--×———×--→ v
        //        / \ / \ | / | / \
        //       ○---×----×———×----→ u
        //        0 ..< i , i ..< n

        // where i = 1 / 2 - (an · (u + v)) / (|v|^2 - |u|^2)
        let n:Int        = cw.count - 1,
            u:Math<F>.V3 = Math.sub(points[Int(ccw[n])], points[Int(ccw[0])]),
            v:Math<F>.V3 = Math.sub(points[Int( cw[n])], points[Int( cw[0])]),
            a:Math<F>.V3 = Math.sub(points[Int( cw[0])], points[Int(ccw[0])])

        // if |v| = |u|, either there is no crossover point i or every point is
        // a crossover point. if we got 0 in the numerator, it’s the second case.
        let d:F     = Math.eusq(v) - Math.eusq(u),
            ortho:F = Math.dot(a, Math.add(u, v)),
            diagonals1:(cw:F, ccw:F),
            i:Int
        if d != 0
        {
            let k:Int = min(Int(0.5 - F(n) * ortho / d), n)
            i = k > 0 ? k : n
        }
        else
        {
            i = n
        }

        diagonals1.cw  = Math.eusq(Math.sub(points[Int(ccw[i])], points[Int( cw[0])]))
        diagonals1.ccw = Math.eusq(Math.sub(points[Int( cw[i])], points[Int(ccw[0])]))

        meshParallelogram(cw: UnsafeBufferPointer(rebasing:  cw[0 ... i]),
                         ccw: UnsafeBufferPointer(rebasing: ccw[0 ... i]),
            diagonals: diagonals1, indices: &indices)

        guard i < n
        else
        {
            return
        }

        let diagonals2:(cw:F, ccw:F)
        diagonals2.cw  = Math.eusq(Math.sub(points[Int(ccw[n])], points[Int( cw[i])]))
        diagonals2.ccw = Math.eusq(Math.sub(points[Int( cw[n])], points[Int(ccw[i])]))

        meshParallelogram(cw: UnsafeBufferPointer(rebasing:  cw[i ... n]),
                         ccw: UnsafeBufferPointer(rebasing: ccw[i ... n]),
            diagonals: diagonals2, indices: &indices)
    }
    // meshes the given parallelogram
    //      cw ×-------→
    //        / \ / \ /
    //   ccw ×-------→

    // cw and ccw each contain at least two indices to distinct points and
    // have the same count
    static
    func meshParallelogram<Index>(cw:UnsafeBufferPointer<Index>,
        ccw:UnsafeBufferPointer<Index>, diagonals:(cw:F, ccw:F),
        indices:inout [Index])
    {
        // we have two options for skinning the parallelogram, which we choose based
        // on the shortest diagonal of the parallelogram

        // option 1
        //    cw ×-------→
        //      / \ / \ /
        // ccw ×-------→

        // option 2
        //  cw ×-------→
        //      \ / \ / \
        //   ccw ×-------→

        if diagonals.cw < diagonals.ccw
        {
            for i:Int in 1 ..< ccw.count
            {
                indices.append(vector: (ccw[i - 1], ccw[i    ],  cw[i - 1]))
                indices.append(vector: ( cw[i    ],  cw[i - 1], ccw[i    ]))
            }
        }
        else
        {
            for i:Int in 1 ..< ccw.count
            {
                indices.append(vector: (ccw[i - 1], ccw[i    ],  cw[i    ]))
                indices.append(vector: ( cw[i    ],  cw[i - 1], ccw[i - 1]))
            }
        }
    }

    // meshes the given clockwise points in a fan
    //  cw ×-----→
    //      \ | /
    //        ×
    static
    func meshFan<Index>(cw:UnsafeBufferPointer<Index>, around center:Index,
        indices:inout [Index])
    {
        for i:Int in 1 ..< cw.count
        {
            indices.append(vector: (cw[i], cw[i - 1], center))
        }
    }

    // meshes the given counterclockwise points in a fan
    //        ×
    //      / | \
    // ccw ×-----→
    static
    func meshFan<Index>(ccw:UnsafeBufferPointer<Index>, around center:Index,
        indices:inout [Index])
    {
        for i:Int in 1 ..< ccw.count
        {
            indices.append(vector: (ccw[i - 1], ccw[i], center))
        }
    }
}

// TODO: make this a generic FloatingPoint struct
struct VoronoiSphere
{
    struct Cell
    {
        let center:Math<Float>.V3,
            vertexIndices:[Int]
    }

    private
    var cells:[Cell],
        vertices:[Math<Float>.V3]

    func vertexArrays<Index>()
        -> (vertexData:[Float], indices:[Index], edgesOffset:Int, facesOffset:Int)
        where Index:BinaryInteger, Index.Stride:SignedInteger
    {
        var vertexData:[Float] = [],
            centers:[Index]    = [],
            edges:[Index]      = [],
            faces:[Index]      = []

        var base:Index = 0
        var _prng = RandomXorshift(seed: 1389)
        for cell:Cell in self.cells
        {
            // generate the vertex buffer data
            // we split vertices creating duplicates per face so that
            // they can be colored differently

            //let color:Math<Float>.V3 = Math.scale(Math.add(center, (1, 1, 1)), by: 0.5)
            let color:Math<Float>.V3 = (_prng.generateFloat(),
                                        _prng.generateFloat(),
                                        _prng.generateFloat())
            vertexData.append(vector: cell.center)
            vertexData.append(vector: color)
            for vertexIndex:Int in cell.vertexIndices
            {
                vertexData.append(vector: self.vertices[vertexIndex])
                vertexData.append(vector: color)
            }

            // generate the element buffer data
            let n:Index = Index(cell.vertexIndices.count)
            for i:Index in 1 ..< n
            {
                faces.append(base)
                faces.append(base + i)
                faces.append(base + i + 1)

                edges.append(base + i)
                edges.append(base + i + 1)
            }
            faces.append(base)
            faces.append(base + n)
            faces.append(base + 1)

            edges.append(base + n)
            edges.append(base + 1)

            centers.append(base)

            base += 1 + n
        }

        return (vertexData,
                centers + edges + faces,
                centers.count,
                centers.count + edges.count)
    }

    static
    func generate(fromNormalizedPoints points:[Math<Float>.V3]) -> VoronoiSphere
    {
        var sites:[Site] = points.map(Math.spherical(_:)).map(Site.init(_:))
        let vertices:[Math<Float>.V3] = sites.withUnsafeMutableBufferPointer
        {
            return generateVertices(sites: $0)
        }

        // vertexBuffer split vertices creating duplicates per face so that
        // they can be colored differently
        let cells:[Cell] = sites.map
        {
            (site:Site) in

            let center:Math<Float>.V3 = Math.cartesian(site.location)
            return Cell(center: center,
                        vertexIndices: sortCounterClockwise(site.vertexIndicies,
                                        around: center, vertices: vertices))
        }

        return VoronoiSphere(cells: cells, vertices: vertices)
    }

    private static
    func generateVertices(sites:UnsafeMutableBufferPointer<Site>) -> [Math<Float>.V3]
    {
        guard let siteBase:UnsafeMutablePointer<Site> = sites.baseAddress
        else
        {
            return [] // happens if site list is empty
        }

        var vertices:[Math<Float>.V3] = []
        var wavefront = UnsafeBalancedTree<Arc>(),
            events    = UnsafeBalancedTree<Event>()
        defer
        {
            wavefront.destroy()
            events.destroy()
        }

        for i:Int in 0 ..< sites.count
        {
            events.insort(.site(SiteEvent(site: siteBase + i)))
        }

        while let eventNode:EventNode = events.first()
        {
            let event:Event = eventNode.element
            events.remove(eventNode)

            switch event
            {
            case .site(let siteEvent):
                siteEvent.handle(wavefront: &wavefront, eventQueue: &events)

            case .circle(let circleEvent):
                circleEvent.handle(wavefront: &wavefront, eventQueue: &events,
                    vertices: &vertices)
            }
        }

        return vertices
    }

    private static
    func sortCounterClockwise(_ indices:[Int], around center:Math<Float>.V3,
        vertices:[Math<Float>.V3]) -> [Int]
    {
        //  pick an arbitrary point to serve as the twelve o’clock reference
        let r:Math<Float>.V3 = Math.sub(vertices[indices[0]], center),
        //  center is also the normal on a sphere so this is really r × n
            p:Math<Float>.V3 = Math.cross(r, center)
        //  sort the points in increasing counterclockwise order
        return indices.sorted
        {
            let a:Math<Float>.V3 = Math.sub(vertices[$0], center),
                b:Math<Float>.V3 = Math.sub(vertices[$1], center)

            let α:Float = Math.dot(a, p),
                β:Float = Math.dot(b, p)

            // let a < b if a is clockwise of b (a is less counterclockwise
            // than b) relative to the zero reference. then if

            //          β > 0   β = 0   β < 0
            //          —————   —————   —————
            //  α > 0 |   *     a > b   a > b
            //  α = 0 | a < b     †       *
            //  α < 0 | a < b     *       *

            //  *   means we can use the triple product because the (cylindrical)
            //      angle between a and b is less than π

            //  †   means a and b are either 0 or π around from the zero reference
            //      in which case a < b only if
            //      a · r > 0 ∧ b · r < 0

            if      β <= 0 && α > 0
            {
                return false
            }
            else if α <= 0 && β > 0
            {
                return true
            }
            else if α == 0 && β == 0
            {
                return Math.dot(a, r) > 0 && Math.dot(b, r) < 0
            }
            else
            {
                // this is really (a × b) · n
                return Math.dot(Math.cross(a, b), center) > 0
            }
        }
    }

    private
    typealias ArcNode   = UnsafeBalancedTree<Arc>.Node
    private
    typealias EventNode = UnsafeBalancedTree<Event>.Node

    private
    struct Site
    {
        let location:Math<Float>.S2
        var vertexIndicies:[Int] = []

        init(_ location:Math<Float>.S2)
        {
            self.location  = location
        }
    }

    private
    struct Arc:CustomStringConvertible
    {
        let site:UnsafeMutablePointer<Site>
        var circleEvent:EventNode? = nil

        init(site:UnsafeMutablePointer<Site>)
        {
            self.site = site
        }

        mutating
        func addCircleEvent(_ circleEvent:CircleEvent,
            to queue:inout UnsafeBalancedTree<Event>)
        {
            self.circleEvent = queue.insort(.circle(circleEvent))
        }

        mutating
        func clearCircleEvent(from queue:inout UnsafeBalancedTree<Event>)
        {
            guard let circleEvent:EventNode = self.circleEvent
            else
            {
                return
            }

            queue.remove(circleEvent)
            self.circleEvent = nil
        }

        var description:String
        {
            return String(describing: self.site.pointee.location)
        }
    }

    private
    struct SiteEvent
    {
        let site:UnsafeMutablePointer<Site>

        var priority:Float
        {
            return self.site.pointee.location.θ
        }

        private static
        func findArcs(in wavefront:UnsafeBalancedTree<Arc>,
            around location:Math<Float>.S2) -> (ArcNode, ArcNode, ArcNode)?
        {
            //VoronoiSphere.printWavefront(wavefront, ξ: location.θ)
            //print()

            guard var node:ArcNode  = wavefront.root,
                  let first:ArcNode = wavefront.first(),
                  let last:ArcNode  = wavefront.last(),
                  first != last
            else
            {
                // wavefront contains 1 or fewer arcs
                return nil
            }

            let ξ:Float = location.θ

            // adding this shift
            // value to φ and taking the modulus against 2π aligns our tree with
            // the discontinuity so we can use it as a binary search tree
            // range: [-7π/2 ... 3π/2]
            let shift:Float  = -intersect(last.element, first.element, ξ: ξ)

            @inline(__always)
            func β(_ φ:Float) -> Float
            {
                // parameter φ range: [-3π/2 ... 7π/2], same as intersect(_:_:ξ:)
                // range. minimum value for φ + shift is then -5π, so an offset
                // of 6π should be enough to make all these values positive, at
                // the loss of a little precision around 0
                assert(φ + shift + 6 * Float.pi >= 0)
                return (φ + shift + 6 * Float.pi)
                    .truncatingRemainder(dividingBy: 2 * Float.pi)
            }

            /*
            func _checkBST(_ n:ArcNode?) -> Bool
            {
                guard let n:ArcNode = n
                else
                {
                    return true
                }

                let pred = n.predecessor() ?? last,
                    succ = n.successor() ?? first
                let φ1:Float = intersect(pred.element, n.element, ξ: ξ),
                    φ2:Float = intersect(n.element, succ.element, ξ: ξ)
                let β1:Float = β(φ1),
                    β2:Float = β(φ2)

                guard pred != succ
                else
                {
                    print("wavefront n = 2")
                    return true
                }

                guard β1 <= β2 || n == last
                else
                {
                    print("intersecting \(pred.element.site.pointee.location) × \(n.element.site.pointee.location) × \(succ.element.site.pointee.location)")
                    print("inverted main {\(φ1), \(φ2)} →[\(-shift)] {\(β1), \(β2)}")
                    return false
                }

                if let lchild:ArcNode = n.lchild
                {
                    let βleft2:Float =
                        β(intersect(lchild.element, (lchild.successor() ?? first).element, ξ: ξ))

                    guard βleft2 <= β1
                    else
                    {
                        print("bst property violated")
                        return false
                    }
                }

                if let rchild:ArcNode = n.rchild
                {
                    let βright1:Float =
                        β(intersect((rchild.predecessor() ?? last).element, rchild.element, ξ: ξ))

                    guard β2 <= βright1
                    else
                    {
                        print("bst property violated")
                        return false
                    }
                }

                return _checkBST(n.lchild) && _checkBST(n.rchild)
            }
            */

            // if we use the formula β = (φ + shift) mod 2π, then the left β bound
            // of the first arc is always 0, and the right β bound of the last arc
            // is always 0 (though conceptually we should regard it as 2π)
            let βsite:Float = β(location.φ)
            while true
            {
                let predecessor:ArcNode? = node.predecessor(),
                    successor:ArcNode?   = node.successor()

                if      let predecessor:ArcNode = predecessor,
                        let lchild:ArcNode      = node.lchild,
                    βsite < β(intersect(predecessor.element, node.element, ξ: ξ))
                {
                    node = lchild
                    continue
                }
                else if let successor:ArcNode   = successor,
                        let rchild:ArcNode      = node.rchild,
                    βsite > β(intersect(node.element, successor.element, ξ: ξ))
                {
                    node = rchild
                    continue
                }

                return (predecessor ?? last, node, successor ?? first)
            }
        }

        func handle(wavefront:inout UnsafeBalancedTree<Arc>,
            eventQueue:inout UnsafeBalancedTree<Event>)
        {
            let newArc = Arc(site: self.site)
            guard let (node0, node, node3):(ArcNode, ArcNode, ArcNode) =
                SiteEvent.findArcs(in: wavefront, around: self.site.pointee.location)
            else
            {
                wavefront.append(newArc)
                return
            }

            node.element.clearCircleEvent(from: &eventQueue)

            let node1:ArcNode =                                       node,
                node2:ArcNode = wavefront.insert(node.element, after: node)
            wavefront.insert(newArc, after: node1)

            // [ node0 ][ node1 ][ new ][ node2 ][ node3 ]
            CircleEvent.addCircleEvent(arc: node1,
                predecessor: node0.element,
                successor:   newArc,
                to:         &eventQueue)

            CircleEvent.addCircleEvent(arc: node2,
                predecessor: newArc,
                successor:   node3.element,
                to:         &eventQueue)
        }
    }

    private
    struct CircleEvent
    {
        private
        var arc:ArcNode

        private
        let p1:UnsafeMutablePointer<Site>,
            p2:UnsafeMutablePointer<Site>

        private
        var p:UnsafeMutablePointer<Site>
        {
            return self.arc.element.site
        }

        let center:Math<Float>.V3,
            priority:Float

        init(arc:ArcNode, predecessor:Arc, successor:Arc)
        {
            let pi:Math<Float>.V3 = Math.cartesian(predecessor.site.pointee.location),
                pj:Math<Float>.V3 = Math.cartesian(arc.element.site.pointee.location),
                pk:Math<Float>.V3 = Math.cartesian(  successor.site.pointee.location)

            self.center   = Math.normalize(Math.cross(Math.sub(pi, pj), Math.sub(pk, pj)))
            self.priority = acos(self.center.z) + acos(Math.dot(self.center, pj))
            self.arc      = arc
            self.p1       = predecessor.site
            self.p2       = successor.site
        }

        static
        func addCircleEvent(arc:ArcNode, predecessor:Arc, successor:Arc,
            to queue:inout UnsafeBalancedTree<Event>)
        {
            let circleEvent =
                CircleEvent(arc: arc, predecessor: predecessor, successor: successor)

            arc.element.addCircleEvent(circleEvent, to: &queue)
            // theoretically if the circle event’s priority is less than ξ, then
            // the circle event is extraneous and doesn’t need to be added.
            // however floating point precision issues make this culling
            // problematic and for “normal” inputs extraneous circle events
            // seem to be extremely rare anyway
        }

        func handle(wavefront:inout UnsafeBalancedTree<Arc>,
            eventQueue:inout UnsafeBalancedTree<Event>,
            vertices:inout [Math<Float>.V3])
        {
            // [ node0 ][ node1 ][ self.arc ][ node2 ][ node3 ]
            let node1:ArcNode = self.arc.predecessor() ?? wavefront.last()!,
                node2:ArcNode = self.arc.successor() ?? wavefront.first()!,
                node0:ArcNode = node1.predecessor() ?? wavefront.last()!,
                node3:ArcNode = node2.successor() ?? wavefront.first()!

            vertices.append(self.center)
            let i:Int = vertices.count - 1
            self.p.pointee.vertexIndicies.append(i)
            self.p1.pointee.vertexIndicies.append(i)
            self.p2.pointee.vertexIndicies.append(i)

            // must come after accesses to self.p, for obvious reasons
            wavefront.remove(self.arc)

            node1.element.clearCircleEvent(from: &eventQueue)
            node2.element.clearCircleEvent(from: &eventQueue)

            guard node0 != node2
            else
            {
                // the algorithm returns when there are only 2 arcs left in the
                // wavefront
                return
            }

            if  node0.element.site != node1.element.site,
                node1.element.site != node2.element.site,
                node0.element.site != node2.element.site
            {
                CircleEvent.addCircleEvent(arc: node1,
                    predecessor: node0.element,
                    successor: node2.element,
                    to: &eventQueue)
            }

            if  node1.element.site != node2.element.site,
                node2.element.site != node3.element.site,
                node1.element.site != node3.element.site
            {
                CircleEvent.addCircleEvent(arc: node2,
                    predecessor: node1.element,
                    successor: node3.element,
                    to: &eventQueue)
            }
        }
    }

    private
    enum Event:Comparable
    {
        case site(SiteEvent), circle(CircleEvent)

        var priority:Float
        {
            switch self
            {
            case .site(let siteEvent):
                return siteEvent.priority

            case .circle(let circleEvent):
                return circleEvent.priority
            }
        }

        static
        func < (a:Event, b:Event) -> Bool
        {
            return a.priority < b.priority
        }

        static
        func == (a:Event, b:Event) -> Bool
        {
            return a.priority == b.priority
        }
    }

    /*
    private static // range: [0 ..< π]
    func evaluateEllipse(p:Math<Float>.S2, ξ:Float, at φ:Float) -> Float
    {
        let θ:Float = atan((_cos(ξ) - _cos(p.θ)) / (_sin(p.θ) * _cos(φ - p.φ) - _sin(ξ)))
        return θ + (θ < 0 ? Float.pi : 0)
    }
    */

    // returns the φ angle of the intersection
    private static
    func intersect(_ arc1:Arc, _ arc2:Arc, ξ:Float) -> Float
    {
        return intersect(arc1.site.pointee.location, arc2.site.pointee.location, ξ: ξ)
    }

    // returns the φ angle of the intersection
    private static
    func intersect(_ p1:Math<Float>.S2, _ p2:Math<Float>.S2, ξ:Float) -> Float
    {
        guard (p1.θ < ξ)
        else
        {
            assert(p1.θ == ξ)
            guard (p2.θ < ξ)
            else
            {
                assert(p2.θ == ξ)
                // intersection of two degenerate arcs
                return 0
            }

            return p1.φ
        }

        guard (p2.θ < ξ)
        else
        {
            assert(p2.θ == ξ)
            guard (p1.θ < ξ)
            else
            {
                assert(p1.θ == ξ)
                return 0
            }

            return p2.φ
        }

        // rotate our coordinate system around the north pole to make life easier
        let dpφ:Float  = p2.φ - p1.φ

        // if this looks different than in the paper it’s because a lot of terms
        // disappear when you rotate coordinates. wig
        let a:Float   =  (_cos(ξ) - _cos(p2.θ)) * _sin(p1.θ) -
                         (_cos(ξ) - _cos(p1.θ)) * _sin(p2.θ) * _cos(dpφ),
            b:Float   = -(_cos(ξ) - _cos(p1.θ)) * _sin(p2.θ) * _sin(dpφ),
            c:Float   =  (_cos(p1.θ) - _cos(p2.θ)) * _sin(ξ),
            // this atan2 is important, regular atan fails
            // range: [-π ... π]
            γ:Float   =  atan2(a, b)

        // range: [-3π/2 ... 7π/2]
        // the min-max clamp is because numerical stability problems sometimes
        // make values slightly outside of [-1, 1] which makes asin() sad
        return asin(min(max(c / Math.length((a, b)), -1), 1)) - γ + p1.φ
    }

    private static
    func printWavefront(_ wavefront:UnsafeBalancedTree<Arc>, ξ:Float)
    {
        var next:ArcNode? = wavefront.first()
        while let current:ArcNode = next
        {
            next = current.successor()
            let successor:ArcNode   = next ?? wavefront.first()!,
                predecessor:ArcNode = current.predecessor() ?? wavefront.last()!

            let φ1:Float = intersect(predecessor.element, current.element, ξ: ξ),
                φ2:Float = intersect(current.element, successor.element,   ξ: ξ)

            print("\(current.element.site.pointee.location) {\(φ1), \(φ2)}")
        }
    }
}
