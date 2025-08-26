module GeoPlottingHelpersMeshesExt

using Meshes
using GeoPlottingHelpers

GeoPlottingHelpers.to_raw_lonlat(p::Point) = to_raw_lonlat(coords(p))

function force_orientation(r::Ring)
    sym = GeoPlottingHelpers.force_orientation()
    o = orientation(r)
    if sym === :CW
        return o === CW ? r : reverse(r)
    elseif sym === :CCW
        return o === CCW ? r : reverse(r)
    else
        return r
    end
end

function GeoPlottingHelpers.extract_latlon_coords!(lat::Vector{T}, lon::Vector{T}, ring::Ring) where T <: AbstractFloat
    # We potentially force the orientation of the ring, depending on settings.
    ring = force_orientation(ring)
    # We plot the points in the ring
    with_settings((; CLOSE_VECTORS = true)) do
        GeoPlottingHelpers.extract_latlon_coords!(lat, lon, vertices(ring))
    end
    return nothing
end

GeoPlottingHelpers.geom_iterable(c::Chain) = eachvertex(c)
GeoPlottingHelpers.geom_iterable(b::Box) = (boundary(b),) # boundary on box returns a ring
GeoPlottingHelpers.geom_iterable(pol::Polygon) = rings(pol)
GeoPlottingHelpers.geom_iterable(m::Multi) = parent(m)
GeoPlottingHelpers.geom_iterable(d::Domain) = d

GeoPlottingHelpers.geo_plotly_trace_default_kwargs(item::Union{Geometry, Domain}, tracefunc) = (; mode = "lines")
end