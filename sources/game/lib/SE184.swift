extension UnsafeMutableBufferPointer
{
    static
    func allocate(capacity:Int) -> UnsafeMutableBufferPointer<Element>
    {
        return UnsafeMutableBufferPointer(start:
                UnsafeMutablePointer<Element>.allocate(capacity: capacity),
                count: capacity)
    }
}
