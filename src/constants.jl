const COUNTRIES_BORDERS_COASTLINES_110 = Dict{String, @NamedTuple{lat::Vector{Float32}, lon::Vector{Float32}}}()
const BORDERS_DEFAULT_KWARGS = (; mode = "lines", line_width = 1, line_color = "black", showlegend = false, hoverinfo = "none")

# This is just an helper for dispatching on valid NamedTuples for `to_raw_lonlat`
const _LONLAT_NT{T} = Union{
    NamedTuple{(:lat, :lon), <:T},
    NamedTuple{(:lon, :lat), <:T},
}