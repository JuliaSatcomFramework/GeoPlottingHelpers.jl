module PlotlyBaseExt

using GeoPlottingHelpers: GeoPlottingHelpers, geo_plotly_trace, geo_plotly_trace_default_kwargs, extract_latlon_coords, get_borders_trace_110, get_coastlines_trace_110
using PlotlyBase

function GeoPlottingHelpers.geo_plotly_trace(T::Type{<:AbstractFloat}, tracefunc::Function, item; kwargs...)
    tracefunc in (scattergeo, scatter) || throw(ArgumentError("The `tracefunc` must be either `scatter` or `scattergeo` from PlotlyBase, while $(tracefunc) was provided"))
    default_kwargs = geo_plotly_trace_default_kwargs(item, tracefunc)
    (;lon, lat) = extract_latlon_coords(T, item)
    latlon_kwargs = if tracefunc == scattergeo
        (; lat, lon)
    else
        (; x = lon, y = lat)
    end
    tracefunc(; latlon_kwargs..., default_kwargs..., kwargs...)
end
GeoPlottingHelpers.geo_plotly_trace(item; kwargs...) = geo_plotly_trace(scattergeo, item; kwargs...)
GeoPlottingHelpers.geo_plotly_trace(tracefunc::Function, item; kwargs...) = geo_plotly_trace(Float32, tracefunc, item; kwargs...)

GeoPlottingHelpers.get_borders_trace_110(; kwargs...) = get_borders_trace_110(scattergeo; kwargs...)
GeoPlottingHelpers.get_coastlines_trace_110(; kwargs...) = get_coastlines_trace_110(scattergeo; kwargs...)

end