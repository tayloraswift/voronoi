// the UnsafeDequeue is backed by a vector. do not append elements to it while
// iterating with a for loop, as the buffer may move out from under you.
struct UnsafeDequeue<Element>:Collection
{
    private
    var buffer:UnsafeMutablePointer<Element>? = nil,
        zero:Int = 0

    public private(set)
    var capacity:Int = 0, // capacity always power of 2
        count:Int = 0

    var startIndex:Int
    {
        return 0
    }

    var endIndex:Int
    {
        return self.count
    }

    var isEmpty:Bool
    {
        return self.count == 0
    }

    func index(after i:Int) -> Int
    {
        _debugPrecondition(i < self.count, "can’t advance past endIndex")
        return i + 1
    }

    subscript(i:Int) -> Element
    {
        get
        {
            _debugPrecondition(i < self.count, "index out of bounds")
            return self.buffer![self.bufferPosition(of: i)]
        }
        set(v)
        {
            _debugPrecondition(i < self.count, "index out of bounds")
            self.buffer![self.bufferPosition(of: i)] = v
        }
    }

    func deallocate()
    {
        self.buffer?.deinitialize(count: self.count)
        self.buffer?.deallocate(capacity: self.capacity)
    }

    private
    func bufferPosition(of index:Int) -> Int
    {
        return (index + self.zero) & (self.capacity - 1)
    }

    private mutating
    func resizeIfNeeded()
    {
        if self.count == self.capacity
        {
            let newCapacity:Int = Swift.max(8, self.capacity << 1),
                newBuffer:UnsafeMutablePointer<Element> =
                    UnsafeMutablePointer<Element>.allocate(capacity: newCapacity)

            if let buffer:UnsafeMutablePointer<Element> = self.buffer
            {
                newBuffer              .moveInitialize( from:  buffer + self.zero,
                                                        count: self.capacity - self.zero)
                (newBuffer + self.zero).moveInitialize( from:  buffer,
                                                        count: self.zero)
                buffer.deallocate(capacity: self.capacity)
            }

            self.zero     = 0
            self.buffer   = newBuffer
            self.capacity = newCapacity
        }
    }

    mutating
    func appendBack(_ data:Element)
    {
        self.resizeIfNeeded()

        (self.buffer! + self.bufferPosition(of: self.count)).initialize(to: data)
        self.count += 1
    }

    mutating
    func appendFront(_ data:Element)
    {
        self.resizeIfNeeded()

        self.count += 1
        self.zero = self.bufferPosition(of: -1)
        (self.buffer! + self.zero).initialize(to: data)
    }

    @discardableResult
    mutating
    func popBack() -> Element?
    {
        guard self.count > 0
        else
        {
            return nil
        }

        self.count -= 1
        return (self.buffer! + self.bufferPosition(of: self.count)).move()
    }

    @discardableResult
    mutating
    func popFront() -> Element?
    {
        guard self.count > 0
        else
        {
            return nil
        }

        let dequeued:Element = (self.buffer! + self.zero).move()
        self.zero   = self.bufferPosition(of: 1)
        self.count -= 1
        return dequeued
    }
}
extension UnsafeDequeue:CustomStringConvertible
{
    var description:String
    {
        return "[" + self.map(String.init(describing:)).joined(separator: ", ") + "]"
    }
}
