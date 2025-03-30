module PlotlyBaseExt

using GeoPlottingHelpers
using PlotlyBase

function GeoPlottingHelpers.geo_plotly_trace(T::Type{<:AbstractFloat}, tracefunc::Function, item; kwargs...)
    (;lon, lat) = extract_latlon_coords(T, item)
    if tracefunc == scattergeo
        tracefunc(; lat, lon, kwargs...)
    elseif tracefunc == scatter
        tracefunc(; x = lon, y = lat, kwargs...)
    else
        throw(ArgumentError("The `tracefunc` must be either `scatter` or `scattergeo` from PlotlyBase, while $(tracefunc) was provided"))
    end
end
GeoPlottingHelpers.geo_plotly_trace(item; kwargs...) = geo_plotly_trace(scattergeo, item; kwargs...)
GeoPlottingHelpers.geo_plotly_trace(tracefunc::Function, item; kwargs...) = geo_plotly_trace(Float32, tracefunc, item; kwargs...)

end