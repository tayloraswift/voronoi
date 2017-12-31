import func Glibc.asin
import func Glibc.acos
import func Glibc.atan
import func Glibc.atan2

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
