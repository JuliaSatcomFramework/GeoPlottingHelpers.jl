module GeoPlottingHelpersMeshesExt

using Meshes
using GeoPlottingHelpers
using GeoPlottingHelpers: CLOSE_VECTORS, ScopedValues

GeoPlottingHelpers.to_raw_lonlat(p::Point) = to_raw_lonlat(coords(p))

function GeoPlottingHelpers.extract_latlon_coords!(lat::Vector{T}, lon::Vector{T}, ring::Ring) where T <: AbstractFloat
    # We plot the points in the ring
    ScopedValues.with(CLOSE_VECTORS => true) do
        GeoPlottingHelpers.extract_latlon_coords!(lat, lon, vertices(ring))
    end
    return nothing
end

GeoPlottingHelpers.geom_iterable(b::Box) = (boundary(b),) # boundary on box returns a ring
GeoPlottingHelpers.geom_iterable(pol::Union{MultiPolygon,Polygon}) = rings(pol)
GeoPlottingHelpers.geom_iterable(d::Domain) = d

GeoPlottingHelpers.geo_plotly_trace_default_kwargs(item::Union{Geometry, Domain}, tracefunc) = (; mode = "lines")

end