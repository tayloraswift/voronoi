struct UnsafeBalancedTree<Element>:Sequence
{
    fileprivate
    struct NodeCore
    {
        enum Color
        {
            case red, black
        }

        var parent:Node?,
            lchild:Node?,
            rchild:Node?

        var element:Element

        // arrange later to take advantage of padding space if Element produces any
        var color:Color
    }

    struct Node:Equatable
    {
        private
        var core:UnsafeMutablePointer<NodeCore>

        var address:UnsafeRawPointer
        {
            return UnsafeRawPointer(self.core)
        }

        var element:Element
        {
            get
            {
                return self.core.pointee.element
            }
            nonmutating set(v)
            {
                self.core.pointee.element = v
            }
        }

        fileprivate
        var color:NodeCore.Color
        {
            get
            {
                return self.core.pointee.color
            }
            nonmutating set(v)
            {
                self.core.pointee.color = v
            }
        }

        internal fileprivate(set)
        var parent:Node?
        {
            get
            {
                return self.core.pointee.parent
            }
            nonmutating set(v)
            {
                self.core.pointee.parent = v
            }
        }

        internal fileprivate(set)
        var lchild:Node?
        {
            get
            {
                return self.core.pointee.lchild
            }
            nonmutating set(v)
            {
                self.core.pointee.lchild = v
            }
        }

        internal fileprivate(set)
        var rchild:Node?
        {
            get
            {
                return self.core.pointee.rchild
            }
            nonmutating set(v)
            {
                self.core.pointee.rchild = v
            }
        }

        fileprivate
        func destroy()
        {
            self.core.deinitialize(count: 1)
            self.core.deallocate(capacity: 1)
        }

        fileprivate static
        func create(_ value:Element, color:NodeCore.Color = .red) -> Node
        {
            let core = UnsafeMutablePointer<NodeCore>.allocate(capacity: 1)
                core.initialize(to: NodeCore(parent: nil,
                                             lchild: nil,
                                             rchild: nil,
                                             element: value,
                                             color: color))
            return Node(core: core)
        }

        static
        func == (a:Node, b:Node) -> Bool
        {
            return a.core == b.core
        }

        // returns the inorder successor of the node in amortized O(1) time
        func successor() -> Node?
        {
            if let rchild:Node = self.rchild
            {
                return rchild.leftmost()
            }

            var current:Node = self
            while let   parent:Node = current.parent,
                        current == parent.rchild
            {
                current = parent
            }

            return current.parent
        }

        // returns the inorder predecessor of the node in amortized O(1) time
        func predecessor() -> Node?
        {
            if let lchild:Node = self.lchild
            {
                return lchild.rightmost()
            }

            var current:Node = self
            while let   parent:Node = current.parent,
                        current == parent.lchild
            {
                current = parent
            }

            return current.parent
        }

        func leftmost() -> Node
        {
            var leftmost:Node = self
            while let lchild:Node = leftmost.lchild
            {
                leftmost = lchild
            }

            return leftmost
        }

        func rightmost() -> Node
        {
            var rightmost:Node = self
            while let rchild:Node = rightmost.rchild
            {
                rightmost = rchild
            }

            return rightmost
        }
    }

    struct Iterator:IteratorProtocol
    {
        private
        var node:Node?

        fileprivate
        init(node:Node?)
        {
            self.node = node
        }

        mutating
        func next() -> Element?
        {
            guard let node:Node = self.node
            else
            {
                return nil
            }

            let value:Element = node.element
            self.node = node.successor()
            return value
        }
    }

    internal private(set)
    var root:Node? = nil

    func makeIterator() -> Iterator
    {
        return Iterator(node: self.first())
    }

    // frees the tree from memory
    func destroy()
    {
        UnsafeBalancedTree.destroyTree(self.root)
    }

    // verifies that all paths in the red-black tree have the same black height,
    // that all nodes satisfy the red property, and that the root is black
    fileprivate
    func verify() -> Bool
    {
        return  self.root?.color ?? .black == .black &&
                UnsafeBalancedTree.verify(self.root) != nil
    }

    // returns the inserted node
    @discardableResult
    mutating
    func append(_ element:Element) -> Node
    {
        if let last:Node = self.last()
        {
            return self.insert(element, after: last)
        }
        else
        {
            let root:Node = Node.create(element, color: .black)
            self.root = root
            return root
        }
    }

    // returns the inserted node
    @discardableResult
    mutating
    func insert(_ element:Element, after predecessor:Node) -> Node
    {
        let new:Node = Node.create(element)
        UnsafeBalancedTree.insert(new, after: predecessor, root: &self.root)
        return new
    }

    mutating
    func remove(_ node:Node)
    {
        UnsafeBalancedTree.remove(node, root: &self.root)
    }

    // returns the leftmost node in the tree, or nil if the tree is empty
    // complexity: O(log n)
    func first() -> Node?
    {
        return self.root?.leftmost()
    }

    // returns the rightmost node in the tree, or nil if the tree is empty
    // complexity: O(log n)
    func last() -> Node?
    {
        return self.root?.rightmost()
    }

    @inline(__always)
    private static
    func rotate(_ pivot:Node, root:inout Node?, rotation:(Node) -> Node)
    {
        guard let parent:Node = pivot.parent
        else
        {
            // updates the external root variable since the root will change
            root = rotation(pivot)
            return
        }

        if pivot == parent.lchild
        {
            parent.lchild = rotation(pivot)
        }
        else
        {
            parent.rchild = rotation(pivot)
        }
    }

    private static
    func rotateLeft(_ pivot:Node, root:inout Node?)
    {
        rotate(pivot, root: &root, rotation: rotateLeft(_:))
    }

    // performs a left rotation and returns the new vertex
    private static
    func rotateLeft(_ pivot:Node) -> Node
    {
        let newVertex:Node = pivot.rchild!

        newVertex.lchild?.parent = pivot
        newVertex.parent         = pivot.parent
        pivot.parent             = newVertex

        pivot.rchild             = newVertex.lchild
        newVertex.lchild         = pivot
        return newVertex
    }

    private static
    func rotateRight(_ pivot:Node, root:inout Node?)
    {
        rotate(pivot, root: &root, rotation: rotateRight(_:))
    }

    // performs a right rotation and returns the new vertex
    private static
    func rotateRight(_ pivot:Node) -> Node
    {
        let newVertex:Node = pivot.lchild!

        newVertex.rchild?.parent = pivot
        newVertex.parent         = pivot.parent
        pivot.parent             = newVertex

        pivot.lchild             = newVertex.rchild
        newVertex.rchild         = pivot
        return newVertex
    }

    private static
    func insert(_ node:Node, after predecessor:Node, root:inout Node?)
    {
        guard let rchild:Node = predecessor.rchild
        else
        {
            predecessor.rchild = node
            node.parent        = predecessor
            balanceInsertion(at: node, root: &root)
            return
        }

        let parent:Node = rchild.leftmost()
        parent.lchild   = node
        node.parent     = parent
        balanceInsertion(at: node, root: &root)
    }

    private static
    func balanceInsertion(at node:Node, root:inout Node?)
    {
        assert(node.color == .red)
        // case 1: the node is the root. repaint the node black
        guard let parent:Node = node.parent
        else
        {
            node.color = .black
            return
        }
        // case 2: the node’s parent is black. the tree is already valid
        if parent.color == .black
        {
            return
        }
        // from here on out, the node *must* have a grandparent because its
        // parent is red which means it cannot be the root
        let grandparent:Node = parent.parent!

        // case 3: both the parent and the uncle are red. repaint both of them
        //         black and make the grandparent red. fix the grandparent.
        if let  uncle:Node  = parent == grandparent.lchild ? grandparent.rchild :
                                                             grandparent.lchild,
                uncle.color == .red
        {
            parent.color        = .black
            uncle.color         = .black

            // recursive call
            grandparent.color   = .red
            balanceInsertion(at: grandparent, root: &root)
            // swift can tail call optimize this right?
            return
        }

        // case 4: the node’s parent is red, its uncle is black, and the node is
        //         an inner child. perform a rotation on the node’s parent.
        //         then fallthrough to case 5.
        let n:Node
        if      node   == parent.rchild,
                parent == grandparent.lchild
        {
            n = parent
            grandparent.lchild = rotateLeft(parent)
        }
        else if node   == parent.lchild,
                parent == grandparent.rchild
        {
            n = parent
            grandparent.rchild = rotateRight(parent)
        }
        else
        {
            n = node
        }

        // case 5: the node’s (n)’s parent is red, its uncle is black, and the node
        //         is an outer child. rotate on the grandparent, which is known
        //         to be black, and switch its color with the former parent’s.
        assert(n.parent != nil)

        n.parent?.color   = .black
        grandparent.color = .red
        if n == n.parent?.lchild
        {
            rotateRight(grandparent, root: &root)
        }
        else
        {
            rotateLeft(grandparent, root: &root)
        }
    }

    private static
    func remove(_ node:Node, root:inout Node?)
    {
        @inline(__always)
        func _replaceLink(to node:Node, with other:Node?, onParent parent:Node)
        {
            if node == parent.lchild
            {
                parent.lchild = other
            }
            else
            {
                parent.rchild = other
            }
        }

        if let       _:Node = node.lchild,
           let  rchild:Node = node.rchild
        {
            let replacement:Node = rchild.leftmost()

            // the replacement always lives below the node, so this shouldn’t
            // disturb any links we are modifying later
            if let parent:Node = node.parent
            {
                _replaceLink(to: node, with: replacement, onParent: parent)
            }
            else
            {
                root = replacement
            }

            // if we don’t do this check, we will accidentally double flip a link
            if node == replacement.parent
            {
                // turn the links around so they get flipped correctly in the next step
                replacement.parent = replacement
                if replacement == node.lchild
                {
                    node.lchild = node
                }
                else
                {
                    node.rchild = node
                }
            }
            else
            {
                // the replacement can never be the root, so it always has a parent
                _replaceLink(to: replacement, with: node, onParent: replacement.parent!)
            }

            // swap all container information, taking care of outgoing links
            swap(&replacement.parent, &node.parent)
            swap(&replacement.lchild, &node.lchild)
            swap(&replacement.rchild, &node.rchild)
            swap(&replacement.color , &node.color)

            // fix uplink consistency
            node.lchild?.parent        = node
            node.rchild?.parent        = node
            replacement.lchild?.parent = replacement
            replacement.rchild?.parent = replacement
        }

        if      node.color == .red
        {
            assert(node.lchild == nil && node.rchild == nil)
            // a red node cannot be the root, so it must have a parent
            _replaceLink(to: node, with: nil, onParent: node.parent!)
        }
        else if let child:Node = node.lchild ?? node.rchild,
                    child.color == .red
        {
            if let parent:Node = node.parent
            {
                _replaceLink(to: node, with: child, onParent: parent)
            }
            else
            {
                root = child
            }

            child.parent = node.parent
            child.color  = .black
        }
        else
        {
            assert(node.lchild == nil && node.rchild == nil)

            balanceDeletion(phantom: node, root: &root)
            // the root case is checked but not handled inside the
            // balanceDeletion(phantom:root:) function
            if let parent:Node = node.parent
            {
                _replaceLink(to: node, with: nil, onParent: parent)
            }
            else
            {
                root = nil
            }
        }

        node.destroy()
    }

    private static
    func balanceDeletion(phantom node:Node, root:inout Node?)
    {
        // case 1: node is the root. do nothing. don’t nil out the root because
        // we may be here on a recursive call
        guard let parent:Node = node.parent
        else
        {
            return
        }
        // the node must have a sibling, since if it did not, the sibling subtree
        // would only contribute +1 black height compared to the node’s subtree’s
        // +2 black height.
        var sibling:Node = node == parent.lchild ? parent.rchild! : parent.lchild!

        // case 2: the node’s sibling is red. (the parent must be black.)
        //         make the parent red and the sibling black. rotate on the parent.
        //         fallthrough to cases 4–6.
        if sibling.color == .red
        {
            parent.color  = .red
            sibling.color = .black
            if node == parent.lchild
            {
                rotateLeft(parent, root: &root)
            }
            else
            {
                rotateRight(parent, root: &root)
            }

            // update the sibling. the sibling must have children because it is
            // red and has a black sibling (the node we are deleting).
            sibling = node == parent.lchild ? parent.rchild! : parent.lchild!
        }
        // case 3: the parent and sibling are both black. on the first iteration,
        //         the sibling has no children or else the black property would ,
        //         not have been held. however later, the sibling may have children
        //         which must both be black. repaint the sibling red, then fix the
        //         parent.
        else if parent.color == .black,
                sibling.lchild?.color ?? .black == .black,
                sibling.rchild?.color ?? .black == .black
        {
            sibling.color = .red

            // recursive call
            balanceDeletion(phantom: parent, root: &root)
            return
        }

        // from this point on, the sibling is assumed black because of case 2
        assert(sibling.color == .black)

        // case 4: the sibling is black, but the parent is red. repaint the sibling
        //         red and the parent black.
        if      parent.color  == .red,
                sibling.lchild?.color ?? .black == .black,
                sibling.rchild?.color ?? .black == .black
        {
            sibling.color = .red
            parent.color  = .black
            return
        }
        // from this point on, the sibling is assumed to have at least one red child
        // because of cases 2–4

        // case 5: the sibling has one red inner child. (the parent’s color does
        //         not matter.) rotate on the sibling and switch its color and that
        //         of its child so that the new sibling has a red outer child.
        //         fallthrough to case 6.
        else if node == parent.lchild,
                sibling.rchild?.color ?? .black == .black
        {
            sibling.color                 = .red
            sibling.lchild!.color = .black

            // update the sibling
            sibling       = rotateRight(sibling)
            parent.rchild = sibling
        }
        else if node == parent.rchild,
                sibling.lchild?.color ?? .black == .black
        {
            sibling.color         = .red
            sibling.rchild!.color = .black

            // update the sibling
            sibling       = rotateLeft(sibling)
            parent.lchild = sibling
        }

        // case 6: the sibling has at least one red child on the outside. switch
        // the colors of the parent and the sibling, make the outer child black,
        // and rotate on the parent.
        sibling.color = parent.color
        parent.color  = .black
        if node == parent.lchild
        {
            sibling.rchild!.color = .black
            rotateLeft(parent, root: &root)
        }
        else
        {
            sibling.lchild!.color = .black
            rotateRight(parent, root: &root)
        }
    }

    // deinitializes and deallocates the node and all of its children
    private static
    func destroyTree(_ node:Node?)
    {
        guard let node:Node = node
        else
        {
            return
        }
        destroyTree(node.lchild)
        destroyTree(node.rchild)
        node.destroy()
    }

    // verifies that all paths in `node`’s subtree have the same black height,
    // and that `node` and all of its children satisfy the red property.
    private static
    func verify(_ node:Node?) -> Int?
    {
        guard let node:Node = node
        else
        {
            return 1
        }

        if node.color == .red
        {
            guard node.lchild?.color ?? .black == .black,
                  node.rchild?.color ?? .black == .black
            else
            {
                return nil
            }
        }

        guard let   l_height:Int = verify(node.lchild),
              let   r_height:Int = verify(node.rchild),
                    l_height == r_height
        else
        {
            return nil
        }

        return l_height + (node.color == .black ? 1 : 0)
    }

    static
    func listNodes(_ node:Node?)
    {
        guard let node:Node = node
        else
        {
            return
        }

        print("\(node.element) @ \(Debug.colorHashPointer(node.address)) " +
            (node.color == .black ? Debug.colorizeBg(" black ", code: 232) :
                                    Debug.colorizeBg("  red  ", code: 196)) +
        " {\(Debug.colorHashPointer(node.lchild?.address)), \(Debug.colorHashPointer(node.rchild?.address))}")
        listNodes(node.lchild)
        listNodes(node.rchild)
    }
}
extension UnsafeBalancedTree where Element:Comparable
{
    // returns the inserted node
    @discardableResult
    mutating
    func insort(_ element:Element) -> Node
    {

        guard var current:Node = self.root
        else
        {
            let root:Node = Node.create(element, color: .black)
            self.root = root
            return root
        }

        let new:Node = Node.create(element)
        while true
        {
            if element < current.element
            {
                if let next:Node = current.lchild
                {
                    current = next
                }
                else
                {
                    current.lchild = new
                    break
                }
            }
            else
            {
                if let next:Node = current.rchild
                {
                    current = next
                }
                else
                {
                    current.rchild = new
                    break
                }
            }
        }

        new.parent = current
        UnsafeBalancedTree.balanceInsertion(at: new, root: &self.root)
        return new
    }

    func binarySearch(_ element:Element) -> Node?
    {
        var node:Node? = self.root
        while let current:Node = node
        {
            if element < current.element
            {
                node = current.lchild
            }
            else if element > current.element
            {
                node = current.rchild
            }
            else
            {
                return current
            }
        }

        return nil
    }
}
