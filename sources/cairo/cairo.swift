import CCairo
import func Glibc.fputs
import var Glibc.stderr

public
enum CairoVector
{
    public
    typealias V2<N> = (x:N, y:N) where N:Numeric
    public
    typealias RGB   = (r:Double, g:Double, b:Double)
    public
    typealias RGBA  = (r:Double, g:Double, b:Double, a:Double)
}

struct StandardError:TextOutputStream
{
    mutating
    func write(_ str:String)
    {
        fputs(str, stderr)
    }
}

var standardError = StandardError()

public
enum CairoFormat
{
    case argb32,
         rgb24,
         a8,
         a1,
         rgb16_565,
         rgb30

     var cValue:cairo_format_t
     {
         switch self
         {
         case .argb32:
             return CAIRO_FORMAT_ARGB32
         case .rgb24:
             return CAIRO_FORMAT_RGB24
         case .a8:
             return CAIRO_FORMAT_A8
         case .a1:
             return CAIRO_FORMAT_A1
         case .rgb16_565:
             return CAIRO_FORMAT_RGB16_565
         case .rgb30:
             return CAIRO_FORMAT_RGB30
         }
     }
}

public
enum CairoFontSlant:UInt32
{
    case normal, italic, oblique
}

public
enum CairoFontWeight:UInt32
{
case normal, bold
}

public final
class CairoSurface
{
    private
    let surface:OpaquePointer

    private
    var ownedContexts:[CairoContext]

    private
    init?(cSurface:OpaquePointer)
    {
        let cairoStatus:cairo_status_t = cairo_surface_status(cSurface)
        guard cairoStatus == CAIRO_STATUS_SUCCESS
        else
        {
            print(String(cString: cairo_status_to_string(cairoStatus)), to: &standardError)
            return nil
        }

        self.surface       = cSurface
        self.ownedContexts = []
    }

    public convenience
    init?(format:CairoFormat, width:Int, height:Int)
    {
        self.init(cSurface: cairo_image_surface_create(format.cValue, CInt(width), CInt(height)))
    }

    public convenience
    init?(format:CairoFormat, size:CairoVector.V2<CInt>)
    {
        self.init(cSurface: cairo_image_surface_create(format.cValue, size.x, size.y))
    }

    public
    func create() -> CairoContext
    {
        let cr:CairoContext = CairoContext(self.surface)
        self.ownedContexts.append(cr)
        return cr
    }

    public
    var width:Int
    {
        return Int(cairo_image_surface_get_width(self.surface))
    }

    public
    var stride:Int
    {
        return Int(cairo_image_surface_get_stride(self.surface))
    }

    public
    var height:Int
    {
        return Int(cairo_image_surface_get_height(self.surface))
    }

    public
    func withData<Result>(_ f:(UnsafeMutableBufferPointer<UInt8>) -> Result) -> Result
    {
        return withExtendedLifetime(self,
        {
            let start:UnsafeMutablePointer<UInt8>? = cairo_image_surface_get_data(self.surface)
            return f(UnsafeMutableBufferPointer<UInt8>(start: start, count: self.stride * self.height))
        })
    }

    public
    func withData<Result>(_ f:(UnsafeBufferPointer<UInt8>) -> Result) -> Result
    {
        return withExtendedLifetime(self,
        {
            let start:UnsafeMutablePointer<UInt8> = cairo_image_surface_get_data(self.surface)
            return f(UnsafeBufferPointer<UInt8>(start: start, count: self.stride * self.height))
        })
    }

    deinit
    {
        cairo_surface_destroy(self.surface)
        for cr in self.ownedContexts
        {
            cr.destroy()
        }
    }
}

public
struct CairoContext
{
    private
    let cr:OpaquePointer

    init(_ c_surface:OpaquePointer)
    {
        self.cr = cairo_create(c_surface)
    }

    public
    func move(to point:CairoVector.V2<Double>)
    {
        cairo_move_to(self.cr, point.x, point.y)
    }

    public
    func move(by offset:CairoVector.V2<Double>)
    {
        cairo_rel_move_to(self.cr, offset.x, offset.y)
    }

    public
    func arc(center:CairoVector.V2<Double>, r:Double,
        start:Double = 0, end:Double = 2*Double.pi)
    {
        cairo_arc(self.cr, center.x, center.y, r, start, end)
    }

    public
    func setSource(rgb:CairoVector.RGB)
    {
        cairo_set_source_rgb(self.cr, rgb.r, rgb.g, rgb.b)
    }

    public
    func setSource(rgba:CairoVector.RGBA)
    {
        cairo_set_source_rgba(self.cr, rgba.r, rgba.g, rgba.b, rgba.a)
    }

    public
    func fill()
    {
        cairo_fill(self.cr)
    }

    public
    func paint()
    {
        cairo_paint(self.cr)
    }

    public
    func selectFontFace(_ fontname:String,
        slant:CairoFontSlant = .normal, weight:CairoFontWeight = .normal)
    {
        cairo_select_font_face(self.cr, fontname,
            cairo_font_slant_t(slant.rawValue), cairo_font_weight_t(weight.rawValue))
    }

    public
    func setFontSize(_ size:Double)
    {
        cairo_set_font_size(self.cr, size)
    }

    public
    func showText(_ text:String)
    {
        cairo_show_text(self.cr, text)
    }

    func destroy()
    {
        cairo_destroy(self.cr)
    }
}
