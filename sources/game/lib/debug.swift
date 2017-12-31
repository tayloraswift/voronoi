enum Debug
{
    static
    func colorizeFg(_ string:String, code:UInt8) -> String
    {
        return "\u{001B}[38;5;\(code)m" + string + "\u{001B}[0m"
    }

    static
    func colorizeBg(_ string:String, code:UInt8) -> String
    {
        return "\u{001B}[48;5;\(code)m" + string + "\u{001B}[0m"
    }

    static
    func padLeft(_ string:String, to length:Int, with filler:Character) -> String
    {
        return repeatElement(String(filler), count: length - string.count)
            .joined(separator: "") + string
    }

    private static
    func colorHashUInt16(_ u:UInt16) -> String
    {
        let string:String = padLeft(String(u, radix: 16), to: 4, with: "0")
        return colorizeBg(string, code: UInt8(truncatingIfNeeded: (u >> 8 + 13) ^ u))
    }

    static
    func colorHashPointer<T>(_ pointer:UnsafePointer<T>?) -> String
    {
        return colorHashPointer(UnsafeRawPointer(pointer))
    }

    static
    func colorHashPointer(_ pointer:UnsafeRawPointer?) -> String
    {
        guard let pointer:UnsafeRawPointer = pointer
        else
        {
            return "//" + colorizeBg("[     NULL     ]", code: 0)
        }

        let i:UInt = UInt(bitPattern: pointer)
        let frags:(UInt16, UInt16, UInt16, UInt16) =
            (UInt16(truncatingIfNeeded: i >> 48),
             UInt16(truncatingIfNeeded: i >> 32),
             UInt16(truncatingIfNeeded: i >> 16),
             UInt16(truncatingIfNeeded: i      ))
        return "0x" + Debug.colorHashUInt16(frags.0) +
            Debug.colorHashUInt16(frags.1) +
            Debug.colorHashUInt16(frags.2) +
            Debug.colorHashUInt16(frags.3)
    }
}
