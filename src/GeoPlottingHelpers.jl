module GeoPlottingHelpers

using ScopedValues: ScopedValues, ScopedValue
using TOML
using Artifacts: Artifacts, @artifact_str

include("constants.jl")

include("settings.jl")
export with_settings

include("api.jl")
export to_raw_lonlat, extract_latlon_coords, geo_plotly_trace, extract_latlon_coords!, geom_iterable, get_borders_trace_110, get_coastlines_trace_110

include("helpers.jl")

end
