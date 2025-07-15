#= 
These are internal ScopedValues used to control the behavior of `extract_latlon_coords!`. They are mirrored by keys of the same name in the `PLOT_SETTINGS` Dict which is also a ScopedValue and should be from users to control the behavior of `extract_latlon_coords!`.

Each of these settings will control the behvior of `extract_latlon_coords!`.

- INSERT_NAN: Specify whether to insert NaN before each vector of points within the lat/lon vectors
- OVERSAMPLE_LINES: Specify whether `extract_latlon_coords!` should potentially add artificial points between each pair of input points in order to have lines appear straight on scattergeo plots. This can have a symbol and three valid values (In reality, every symbol that is not the first two will be treated as `:NONE`)
  - `:NORMAL` will add artificial points only when necessary (when distance between points is too large) and will create lines that never cross the antimeridian. This is useful for example to plot Box geometries with large areas and have them still look like boxes.
  - `:SHORT` will add artificial points like per `:NORMAL` but will also make sure the line drawn between the points is the shortest one (potentially crossing the antimeridian at 180° longitude).
  - `:NONE` will not add artificial points
- CLOSE_VECTORS: Specify whether to close the vector of points by repeating the first point at the end of the vector.
- FORCE_ORIENTATION: Specify whether to force the orientation of the rings of points. This is useful as when filling polygons (with `fill="toself"`), plotly expects rings to be oriented clockwise. Possible options are:
  - `:NONE` will not force the orientation of the rings of points.
  - `:CW` will force the orientation of the rings of points to be clockwise.
  - `:CCW` will force the orientation of the rings of points to be counter-clockwise.
=#
const NT_SETTINGS = (;
    INSERT_NAN = ScopedValue{Base.RefValue{Bool}}(Ref(true)),
    OVERSAMPLE_LINES = ScopedValue{Base.RefValue{Symbol}}(Ref(:NONE)),
    CLOSE_VECTORS = ScopedValue{Base.RefValue{Bool}}(Ref(false)),
    FORCE_ORIENTATION = ScopedValue{Base.RefValue{Symbol}}(Ref(:NONE)),
)

# This is a map of the names of the settings in the `NT_SETTINGS`. It is mostly needed as some settings are aliases of others (currently only `PLOT_STRAIGHT_LINES` is an alias of `OVERSAMPLE_LINES`).
const SETTINGS_NAMES_MAP = (;
    INSERT_NAN = :INSERT_NAN,
    OVERSAMPLE_LINES = :OVERSAMPLE_LINES,
    PLOT_STRAIGHT_LINES = :OVERSAMPLE_LINES,
    CLOSE_VECTORS = :CLOSE_VECTORS,
    FORCE_ORIENTATION = :FORCE_ORIENTATION,
)

# This is a Dict with the same settings as NT_SETTINGS but this will take priority and is what most users will set when using `with_settings`.
const PLOT_SETTINGS = ScopedValue{Dict{Symbol, Any}}(Dict{Symbol, Any}())

"""
    with_settings(f, settings::Pair{Symbol, <:Any}...)

Convenience function to change settings for plotting, and specifically for how `extract_latlon_coords!` will behave. It expects pairs of symbol as keys and values depending on the setting as explained below

The possible keys that can be provided as settings are:
- `:INSERT_NAN => Bool`: Specify whether to insert NaN before each vector of points within the lat/lon vectors.
- `:OVERSAMPLE_LINES => Symbol`: Specify whether `extract_latlon_coords!` should potentially add artificial points between each pair of input points in order to have lines appear straight on scattergeo plots. This can have a symbol and three valid values (In reality, every symbol that is not the first two will be treated as `:NONE`)
  - `:NORMAL` will add artificial points only when necessary (when distance between points is too large) and will create lines that never cross the antimeridian. This is useful for example to plot Box geometries with large areas and have them still look like boxes.
  - `:SHORT` will add artificial points like per `:NORMAL` but will also make sure the line drawn between the points is the shortest one (potentially crossing the antimeridian at 180° longitude).
  - `:NONE` will not add artificial points
- `:PLOT_STRAIGHT_LINES => Symbol`: This is just an alias for the `:OVERSAMPLE_LINES` key and they have the same effect. Note: `:OVERSAMPLE_LINES` has higher priority if both keys are provided.
- `:CLOSE_VECTORS => Bool`: Specify whether to close any vector of points by repeating the first point at the end of the vector.
- `:FORCE_ORIENTATION => Symbol`: Specify whether to force the orientation of the rings of points. This is useful as when filling polygons (with `fill="toself"`), plotly expects rings to be oriented clockwise. Possible options are:
  - `:NONE` will not force the orientation of the rings of points.
  - `:CW` will force the orientation of the rings of points to be clockwise.
  - `:CCW` will force the orientation of the rings of points to be counter-clockwise.

# Example
```julia
using GeoPlottingHelpers

with_settings(:PLOT_STRAIGHT_LINES => :NORMAL) do
    geo_plotly_trace(geometry) # This will oversample lines to make them appear straight on scattergeo plots. Only for the commands within the `with_settings` block.
end
```
"""
with_settings(f, settings::AbstractVector) = with_settings(f, settings...)
with_settings(f, settings::Pair{Symbol,<:Any}...) = with_settings(f, Dict(settings...))
function with_settings(f, settings::Dict{Symbol,<:Any})
    ScopedValues.with(PLOT_SETTINGS => settings) do
        f()
    end
end
# This is mostly internal, when passing a NamedTuple this will be used to overwrite the settings in the `NT_SETTINGS` with the values in the NamedTuple. It is useful when trying have default settings in trace default kwargs that are still going to be overriden if the user creates a `with_settings` block explicitly
function with_settings(f, settings::NamedTuple)
    # Check if unsupported settings were provided
    setdiff(keys(settings), keys(SETTINGS_NAMES_MAP)) |> isempty || @warn("Unsupported settings were provided and will be ignored: $(setdiff(keys(settings), keys(SETTINGS_NAMES_MAP)))\nThe following keys are supported: $(keys(SETTINGS_NAMES_MAP))")
    # We process the provided settings to translate the given values into pairs to use with ScopedValues.with
    ps = Pair{<:ScopedValue}[]
    for (k, v) in pairs(settings)
        k in keys(SETTINGS_NAMES_MAP) || continue
        mapped_key = SETTINGS_NAMES_MAP[k]
        sv = NT_SETTINGS[mapped_key]
        R = typeof(sv[])
        push!(ps, sv => R(v))
    end
    ScopedValues.with(ps...) do
        f()
    end
end