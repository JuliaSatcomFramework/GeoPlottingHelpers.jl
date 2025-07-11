# These are internal ScopedValues used to control the behavior of `extract_latlon_coords!`. They are mirrored by keys of the same name in the `PLOT_SETTINGS` Dict which is also a ScopedValue and should be from users to control the behavior of `extract_latlon_coords!`.
# Specify whether to insert NaN before each vector of points within the lat/lon vectors
const INSERT_NAN = ScopedValue{Bool}(true)
#= 
Specify whether `extract_latlon_coords!` should potentially add artificial points between each pair of input points in order to have lines appear straight on scattergeo plots. This can have a symbol and three valid values (In reality, every symbol that is not the first two will be treated as `:NONE`)
- `:NORMAL` will add artificial points only when necessary (when distance between points is too large) and will create lines that never cross the antimeridian. This is useful for example to plot Box geometries with large areas and have them still look like boxes.
- `:SHORT` will add artificial points like per `:NORMAL` but will also make sure the line drawn between the points is the shortest one (potentially crossing the antimeridian at 180° longitude).
- `:NONE` will not add artificial points
=#
const OVERSAMPLE_LINES = ScopedValue{Symbol}(:NONE)
const PLOT_STRAIGHT_LINES = OVERSAMPLE_LINES
#= 
Specify whether to close the vector of points by repeating the first point at the end of the vector.
=#
const CLOSE_VECTORS = ScopedValue{Bool}(false)

"""
    PLOT_SETTINGS

ScopedValue that contains the settings for `extract_latlon_coords!`. It is a Dict with keys as symbol which can be used to customize the behavior of `extract_latlon_coords!`.

Check the docstring of [`with_settings`](@ref) for the possible keys accepted for this Dict.
"""
const PLOT_SETTINGS = ScopedValue{Dict{Symbol, Any}}(Dict{Symbol, Any}())

const COUNTRIES_BORDERS_COASTLINES_110 = Dict{String, @NamedTuple{lat::Vector{Float32}, lon::Vector{Float32}}}()
const BORDERS_DEFAULT_KWARGS = (; mode = "lines", line_width = 1, line_color = "black", showlegend = false, hoverinfo = "none")

# This is just an helper for dispatching on valid NamedTuples for `to_raw_lonlat`
const _LONLAT_NT{T} = Union{
    NamedTuple{(:lat, :lon), <:T},
    NamedTuple{(:lon, :lat), <:T},
}