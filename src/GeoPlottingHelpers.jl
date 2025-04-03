module GeoPlottingHelpers

using ScopedValues: ScopedValues, ScopedValue
using TOML
using Artifacts: Artifacts, @artifact_str

include("constants.jl")
include("api.jl")
export with_settings, to_raw_lonlat, extract_latlon_coords, geo_plotly_trace, extract_latlon_coords!, geom_iterable, get_borders_trace_110, get_coastlines_trace_110

include("helpers.jl")

end
