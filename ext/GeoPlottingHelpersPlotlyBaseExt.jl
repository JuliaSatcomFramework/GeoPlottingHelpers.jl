module GeoPlottingHelpersPlotlyBaseExt

using GeoPlottingHelpers: GeoPlottingHelpers, geo_plotly_trace, geo_plotly_trace_default_kwargs, extract_latlon_coords, get_borders_trace_110, get_coastlines_trace_110, PLOT_SETTINGS, with_settings
using PlotlyBase

function GeoPlottingHelpers.geo_plotly_trace(T::Type{<:AbstractFloat}, tracefunc::Function, item; kwargs...)
    tracefunc in (scattergeo, scatter) || throw(ArgumentError("The `tracefunc` must be either `scatter` or `scattergeo` from PlotlyBase, while $(tracefunc) was provided"))
    default_kwargs = geo_plotly_trace_default_kwargs(item, tracefunc)
    nt_kwargs = (; default_kwargs..., kwargs...)
    # We try to extract custom per-trace settings. We have both settings_dict and settings_nt depending on priority of the settings. NamedTuple settings have lower priority
    settings_dict = @something get(nt_kwargs, :settings_dict, nothing) PLOT_SETTINGS[] # This falls back to the existing high priority settings
    settings_nt = @something get(nt_kwargs, :settings_nt, nothing) (;) # This falls back to empty NamedTuple which is using low priority default values
    (;lon, lat) = with_settings(settings_dict) do
        with_settings(settings_nt) do
            extract_latlon_coords(T, item)
        end
    end
    # We remove settings from the kwargs as they are not needed for plotly
    valid_keys = setdiff(keys(nt_kwargs), (:settings_dict, :settings_nt)) |> Tuple
    nt_kwargs = NamedTuple{valid_keys}(nt_kwargs)
    latlon_kwargs = if tracefunc == scattergeo
        (; lat, lon)
    else
        (; x = lon, y = lat)
    end
    tracefunc(; latlon_kwargs..., nt_kwargs...)
end
GeoPlottingHelpers.geo_plotly_trace(item; kwargs...) = geo_plotly_trace(scattergeo, item; kwargs...)
GeoPlottingHelpers.geo_plotly_trace(tracefunc::Function, item; kwargs...) = geo_plotly_trace(Float32, tracefunc, item; kwargs...)

GeoPlottingHelpers.get_borders_trace_110(; kwargs...) = get_borders_trace_110(scattergeo; kwargs...)
GeoPlottingHelpers.get_coastlines_trace_110(; kwargs...) = get_coastlines_trace_110(scattergeo; kwargs...)

end