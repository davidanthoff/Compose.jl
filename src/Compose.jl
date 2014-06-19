
require("Color")
require("Iterators")
require("JSON")


module Compose

using Color
using Iterators
using JuMP
import JSON

import Base: length, start, next, done, isempty, getindex, setindex!, writemime,
             convert, zero, isless, max, fill, size, copy

export compose, compose!, Context, UnitBox, AbsoluteBoundingBox, Rotation, ParentDrawContext,
       context, ctxpromise, table, set_units!, minwidth, minheight,
       text_extents, max_text_extents, polygon, line, rectangle, circle,
       ellipse, text, curve, bitmap, stroke, fill, strokedash, strokelinecap,
       strokelinejoin, linewidth, visible, fillopacity, strokeopacity, clip,
       font, fontsize, svgid, svgclass, svgattribute, jsinclude, jscall, Measure,
       inch, mm, cm, pt, px, cx, cy, w, h, hleft, hcenter, hright, vtop, vcenter,
       vbottom, SVG, SVGJS, PNG, PS, PDF, draw, pad, hstack, vstack

abstract Backend

include("misc.jl")
include("measure.jl")
include("list.jl")

# Every graphic in Compose consists of a tree.
abstract ComposeNode

# Used to mark null child pointers
immutable NullNode <: ComposeNode end
nullnode = NullNode()

include("form.jl")
include("property.jl")
include("container.jl")
include("table.jl")
include("stack.jl")

# How large to draw graphics when not explicitly drawing to a backend
default_graphic_width = 12cm
default_graphic_height = 12cm

# Default property values
default_font_family = "Helvetic,Arial,sans"
default_font_size = 11pt
default_line_width = 0.3mm
default_stroke_color = nothing
default_fill_color = color("black")

try
    require("Cairo")
catch
    global PNG
    global PS
    global PDF
    PNG(::String, ::MeasureOrNumber, ::MeasureOrNumber) =
        error("Cairo must be installed to use the PNG backend.")
    PS(::String, ::MeasureOrNumber, ::MeasureOrNumber) =
        error("Cairo must be installed to use the PS backend.")
    PDF(::String, ::MeasureOrNumber, ::MeasureOrNumber) =
        error("Cairo must be installed to use the PDF backend.")
end
include("cairo_backends.jl")

include("svg.jl")

# If available, pango and fontconfig are used to compute text extents and match
# fonts. Otherwise a simplistic pure-julia fallback is used.
try
    # Trigger an exception if unavailable.
    dlopen("libfontconfig")
    dlopen("libpangocairo-1.0")
    dlopen("libpango-1.0")

    pango_cairo_ctx = C_NULL

    include("fontconfig.jl")
    include("pango.jl")

    function __init__()
        global pango_cairo_ctx
        global pangolayout
        ccall((:g_type_init, Cairo._jl_libgobject), Void, ())
        pango_cairo_fm  = ccall((:pango_cairo_font_map_new, libpangocairo),
                                 Ptr{Void}, ())
        pango_cairo_ctx = ccall((:pango_font_map_create_context, libpango),
                                 Ptr{Void}, (Ptr{Void},), pango_cairo_fm)
        pangolayout = PangoLayout()
    end
catch
    include("fontfallback.jl")
end


function pad_outer(c::Context,
                   xpadding::MeasureOrNumber,
                   ypadding::MeasureOrNumber)
    xpadding = size_measure(xpadding)
    ypadding = size_measure(ypadding)
    root = context(c.box.x0, c.box.y0,
                   c.box.width + 2xpadding,
                   c.box.height + 2ypadding,
                   minwidth=c.minwidth,
                   minheight=c.minheight)
    c = copy(c)
    c.box = BoundingBox(xpadding, ypadding, 1w - 2xpadding, 1h - 2ypadding)
    return compose!(root, c)
end


function pad_outer(c::Context, padding::MeasureOrNumber)
    return pad_outer(c, padding, padding)
end


function pad_outer(cs::Vector{Context}, xpadding::MeasureOrNumber,
                   ypadding::MeasureOrNumber)
    return map(c -> pad_outer(c, xpadding, ypadding), cs)
end


function pad_outer(cs::Vector{Context}, padding::MeasureOrNumber)
    return pad_outer(cs, padding, padding)
end


const pad = pad_outer

end # module Compose


