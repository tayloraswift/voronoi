fileprivate
struct UnmanagedBuffer<Header, Element>:Equatable
{
    // just like roundUp(_:toAlignment) in stdlib/public/core/BuiltIn.swift
    @inline(__always)
    private static
    func round_up(_ offset:UInt, to_alignment alignment:Int) -> UInt
    {
        let x = offset + UInt(bitPattern: alignment) &- 1
        return x & ~(UInt(bitPattern: alignment) &- 1)
    }

    private static
    var buffer_offset:Int
    {
        return Int(bitPattern: UnmanagedBuffer.round_up(UInt(MemoryLayout<Header>.size),
                                                        to_alignment: MemoryLayout<Element>.alignment))
    }

    let core:UnsafeMutablePointer<Header>

    var header:Header
    {
        get
        {
            return self.core.pointee
        }
        set(v)
        {
            self.core.pointee = v
        }
    }

    var buffer:UnsafeMutablePointer<Element>
    {
        let raw_ptr = UnsafeMutableRawPointer(mutating: self.core) +
                      UnmanagedBuffer<Header, Element>.buffer_offset
        return raw_ptr.assumingMemoryBound(to: Element.self)
    }

    subscript(index:Int) -> Element
    {
        get
        {
            return self.buffer[index]
        }
        set(v)
        {
            self.buffer[index] = v
        }
    }

    init(core:UnsafeMutablePointer<Header>)
    {
        self.core = core
    }

    init(mutating core:UnsafePointer<Header>)
    {
        self.core = UnsafeMutablePointer(mutating: core)
    }

    static
    func allocate(capacity:Int) -> UnmanagedBuffer<Header, Element>
    {
        let align1:Int = MemoryLayout<Header>.alignment,
            align2:Int = MemoryLayout<Element>.alignment,
            padded_size:Int = UnmanagedBuffer<Header, Element>.buffer_offset +
                              capacity * MemoryLayout<Element>.stride

        let memory = UnsafeMutableRawPointer.allocate(bytes: padded_size, alignedTo: max(align1, align2))
        return UnmanagedBuffer<Header, Element>(core: memory.assumingMemoryBound(to: Header.self))
    }

    func initialize_header(to header:Header)
    {
        self.core.initialize(to: header, count: 1)
    }
    func initialize_elements(from buffer:UnsafePointer<Element>, count:Int)
    {
        self.buffer.initialize(from: buffer, count: count)
    }

    func move_initialize_header(from unmanaged:UnmanagedBuffer<Header, Element>)
    {
        self.core.moveInitialize(from: unmanaged.core, count: 1)
    }
    func move_initialize_elements(from unmanaged:UnmanagedBuffer<Header, Element>, count:Int)
    {
        self.buffer.moveInitialize(from: unmanaged.buffer, count: count)
    }

    func deinitialize_header()
    {
        self.core.deinitialize(count: 1)
    }
    func deinitialize_elements(count:Int)
    {
        self.buffer.deinitialize(count: count)
    }

    func deallocate()
    {
        self.core.deallocate(capacity: -1) // free the entire block
    }

    static
    func == (a:UnmanagedBuffer<Header, Element>, b:UnmanagedBuffer<Header, Element>) -> Bool
    {
        return a.core == b.core
    }
}
extension UnmanagedBuffer:CustomStringConvertible
{
    var description:String
    {
        return String(describing: self.core)
    }
}

struct UnsafeSkipList<Element> where Element:Comparable
{
    struct Node
    {
        let value:Element
        var height:Int

        fileprivate
        init(value:Element, height:Int)
        {
            self.value  = value
            self.height = height
        }
    }

    private
    typealias NodePointer = UnmanagedBuffer<Node, Link>

    private // *must* be a trivial type
    struct Link
    {
        // yes, the Element is the Header, and the Link is the Element.
        // it’s confusing.
        var prev:NodePointer,
            next:NodePointer
    }

    private
    struct RandomNumberGenerator
    {
        private
        var state:UInt64

        init(seed:Int)
        {
            self.state = UInt64(truncatingIfNeeded: seed)
        }

        mutating
        func generate() -> UInt64
        {
            self.state = self.state &* 2862933555777941757 + 3037000493
            return self.state
        }
    }

    private
    var random:RandomNumberGenerator = RandomNumberGenerator(seed: 24),
        head:[Link]                  = []

    static
    func create() -> UnsafeSkipList<Element>
    {
        return UnsafeSkipList<Element>()
    }

    func destroy()
    {
        if self.head.count > 0
        {
            let first:NodePointer   = self.head[0].next
            var current:NodePointer = first
            repeat
            {
                let old:NodePointer = current
                current = current[0].next
                old.deinitialize_header()
                old.deallocate()
            } while current != first
        }
    }

    @discardableResult
    mutating
    func insert(_ element:Element) -> UnsafePointer<Node>
    {
        let height:Int      = self.random.generate().trailingZeroBitCount + 1
        var level:Int       = self.head.count,
            new:NodePointer = NodePointer.allocate(capacity: height)

            new.initialize_header(to: Node(value: element, height: height))

        if height > level
        {
            let link:Link      = Link(prev: new, next: new),
                new_levels:Int = height - level
            (new.buffer + level).initialize       (to: link, count: new_levels)
            self.head.append(contentsOf: repeatElement(link, count: new_levels))

            // height will always be > 0, so if level <= 0, then height > level
            guard level > 0
            else
            {
                return UnsafePointer(new.core)
            }
        }

        level -= 1
        // from here on out, all of our linked lists contain at least one node

        self.head.withUnsafeMutableBufferPointer
        {
            let head_tower:UnsafeMutablePointer<Link>    = $0.baseAddress!
            var current_tower:UnsafeMutablePointer<Link> = head_tower,
                current:NodePointer?                     = nil

            while true
            {
                if  current_tower[level].next.header.value < element,
                    current_tower[level].next != head_tower[level].next ||
                                current_tower == head_tower
                    // account for the discontinuity to prevent infinite traversal
                {
                    current         = current_tower[level].next
                    current_tower   = current_tower[level].next.buffer
                    continue
                }
                else if level < height
                {
                    new[level].next                 = current_tower[level].next
                    if let current:NodePointer = current
                    {
                        new[level].prev             = current
                        new[level].next[level].prev = new
                        current_tower[level].next   = new
                    }
                    else
                    {
                        new[level].prev             = head_tower[level].next[level].prev
                        new[level].prev[level].next = new
                        new[level].next[level].prev = new

                        head_tower[level].prev      = new
                        head_tower[level].next      = new
                    }

                    // height will always be > 0, so if level == 0 then level < height
                    if level == 0
                    {
                        break
                    }
                }

                level -= 1
            }
        }

        return UnsafePointer(new.core)
    }

    mutating
    func delete(_ node:UnsafePointer<Node>)
    {
        var current:NodePointer  = NodePointer(mutating: node),
            levels_to_delete:Int = 0

        for level in (0 ..< current.header.height).reversed()
        {
            if current[level].next == current
            {
                levels_to_delete += 1
            }
            else
            {
                current[level].prev[level].next = current[level].next
                current[level].next[level].prev = current[level].prev

                if current == self.head[level].next
                {
                    self.head[level].next = current[level].next
                    self.head[level].prev = current[level].next
                }
            }
        }

        self.head.removeLast(levels_to_delete)
        current.deinitialize_header()
        current.deallocate()
    }
}
extension UnsafeSkipList:CustomStringConvertible
{
    var description:String
    {
        var output:String = ""
        for level in (0 ..< self.head.count).reversed()
        {
            output += "[\(self.head[level].prev.header) ← HEAD → \(self.head[level].next.header)]"
            let first:NodePointer   = self.head[level].next
            var current:NodePointer = first
            repeat
            {
                output += " (\(current[level].prev.header) ← \(current.header) → \(current[level].next.header))"
                current = current[level].next
            } while current != first

            if level > 0
            {
                output += "\n"
            }
        }

        return output
    }
}
