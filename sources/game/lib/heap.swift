struct Heap<Element> where Element:Comparable
{
    private
    var elements:[Element] = [] // first index is always unused

    private
    subscript(index:Int) -> Element
    {
        get
        {
            return self.elements[index - 1]
        }
        set(v)
        {
            self.elements[index - 1] = v
        }
    }

    var count:Int
    {
        return self.elements.count
    }

    var first:Element?
    {
        return self.elements.first
    }

    @inline(__always)
    private
    func left_child(of index:Int) -> Int
    {
        return index << 1
    }

    @inline(__always)
    private
    func right_child(of index:Int) -> Int
    {
        return index << 1 + 1
    }

    @inline(__always)
    private
    func parent(of index:Int) -> Int
    {
        return index >> 1
    }

    @inline(__always)
    private
    func highest_priority(under parent:Int) -> Int
    {
        let r:Int = self.right_child(of: parent),
            l:Int = self.left_child(of: parent)

        guard l <= self.count
        else
        {
            return parent
        }

        guard r <= self.count
        else
        {
            return self[parent] > self[l] ? parent : l
        }

        let lp_max:Int = self[parent] > self[l] ? parent : l
        return self[lp_max] > self[r] ? lp_max : r
    }

    @inline(__always)
    private mutating
    func swap_at(_ i:Int, _ j:Int)
    {
        self.elements.swapAt(i - 1, j - 1)
    }

    mutating
    func enqueue(_ element:Element)
    {
        self.elements.append(element)
        self.sift_up(element_at: self.count)
    }

    mutating
    func sift_up(element_at index:Int)
    {
        let parent:Int = self.parent(of: index)
        guard   index != 1,
                // make sure it’s not the root
                self[index] > self[parent]
                // and the element is higher than the parent
        else
        {
            return
        }

        self.swap_at(index, parent)
        self.sift_up(element_at: parent)
    }

    mutating
    func dequeue() -> Element?
    {
        guard self.count > 0
        else
        {
            return nil
        }

        let dequeued:Element
        if self.count > 1
        {
            self.swap_at(1, self.count)
            dequeued = self.elements.removeLast()
            self.sift_down(element_at: 1)
        }
        else
        {
            dequeued = self.elements.removeLast()
        }

        return dequeued
    }

    mutating
    func sift_down(element_at index:Int)
    {
        let target:Int = highest_priority(under: index)
        guard index != target
        else
        {
            return
        }
        self.swap_at(index, target)
        self.sift_down(element_at: target)
    }

    mutating
    func heapify()
    {
        for index in (1 ... self.parent(of: self.count)).reversed()
        {
            self.sift_down(element_at: index)
        }
    }
}
