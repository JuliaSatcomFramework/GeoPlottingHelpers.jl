"""
    with_settings(f, settings::Pair{Symbol, <:Any}...)

Convenience function to set the `PLOT_SETTINGS` ScopedValue to a Dict created from the key-value pairs in `settings` and call `f` with that `PLOT_SETTINGS` set.

The possible keys that can be provided as settings are:
- `:INSERT_NAN => Bool`: Specify whether to insert NaN before each vector of points within the lat/lon vectors.
- `:OVERSAMPLE_LINES => Symbol`: Specify whether `extract_latlon_coords!` should potentially add artificial points between each pair of input points in order to have lines appear straight on scattergeo plots. This can have a symbol and three valid values (In reality, every symbol that is not the first two will be treated as `:NONE`)
  - `:NORMAL` will add artificial points only when necessary (when distance between points is too large) and will create lines that never cross the antimeridian. This is useful for example to plot Box geometries with large areas and have them still look like boxes.
  - `:SHORT` will add artificial points like per `:NORMAL` but will also make sure the line drawn between the points is the shortest one (potentially crossing the antimeridian at 180° longitude).
  - `:NONE` will not add artificial points
- `:PLOT_STRAIGHT_LINES => Symbol`: This is just an alias for the `:OVERSAMPLE_LINES` key and they have the same effect. Note: `:OVERSAMPLE_LINES` has higher priority if both keys are provided.
- `:CLOSE_VECTORS => Bool`: Specify whether to close any vector of points by repeating the first point at the end of the vector.

This is essentially a convenience wrapper for:
```julia
Base.ScopedValues.with(GeoPlottingHelpers.PLOT_SETTINGS => Dict(settings...)) do
    f()
end
```
"""
with_settings(f, settings::AbstractVector) = with_settings(f, settings...)
function with_settings(f, settings::Pair{Symbol,<:Any}...)
    ScopedValues.with(PLOT_SETTINGS => Dict(settings...)) do
        f()
    end
end

"""
    lon, lat = to_raw_lonlat(p)

This function should take a single input representing a point on or around the Earth and returns a two Real numbers representing the longitude and latitude of the point expressed in degrees.

This function is used internally by other functions of `GeoPlottingHelpers` and should be expanded for custom points/types to fully utilize the features of `GeoPlottingHelpers`.
"""
to_raw_lonlat(lonlat::Tuple{Real,Real}) = lonlat

"""
    geom_iterable(item)

This function should be used to create an iterable of geometries on which to call `extract_latlon_coords!`.

If a method for this function is implemented for a custom type, GeoPlottingHelpers will know that this type does not represent a single point but either a single geometry (in which case the returned iterable should contains elements for which `to_raw_lonlat` is defined) or a collection of geometries (in which case the returned iterable should contain other geometries for which `geom_iterable` is defined).
"""
function geom_iterable end

"""
    extract_latlon_coords!(lat::Vector{T}, lon::Vector{T}, item) where T<:AbstractFloat

Extract the lat/lon coordinates out of `item` and append them to the `lat` and `lon` vectors which are assumed to represent values in degrees.

By default, single points are inserted as is, while geometries or vectors of points are inserted separated by NaNs to appear as distinct lines within a single trace from PlotlyBase (or derivatives).

The behavior of this function can be customized by using the [`PLOT_SETTINGS`](@ref) ScopedValue, which can be more easily controlled using the unexported [`with_settings`](@ref) function.

See also: [`extract_latlon_coords`](@ref), [`geom_iterable`](@ref), [`to_raw_lonlat`](@ref), [`with_settings`](@ref)
"""
function extract_latlon_coords!(lat::Vector{T}, lon::Vector{T}, item) where T<:AbstractFloat
    if is_iterable_geometry(item)
        for geom in geom_iterable(item)
            extract_latlon_coords!(lat, lon, geom)
        end
    elseif is_valid_point(item)
        _lon, _lat = to_raw_lonlat(item)
        push!(lon, _lon)
        push!(lat, _lat)
    else
        throw(ArgumentError("The function `extract_latlon_coords!` only accepts types for which `geom_iterable` or `to_raw_lonlat` is defined."))
    end
    return nothing
end

function _extract_latlon_coords_pointvector!(lat::Vector{T}, lon::Vector{T}, els::AbstractVector) where T<:AbstractFloat
    if should_insert_nan() && !isempty(lat) && !isempty(lon)
        extract_latlon_coords!(lat, lon, (NaN, NaN))
    end
    if should_oversample_points()
        for i in eachindex(els)[1:end-1]
            start = els[i]
            stop = els[i+1]
            for pt in line_plot_coords(start, stop)
                extract_latlon_coords!(lat, lon, pt)
            end
        end
        if should_close_vectors()
            for pt in line_plot_coords(last(els), first(els))
                extract_latlon_coords!(lat, lon, pt)
            end
        else
            extract_latlon_coords!(lat, lon, last(els))
        end
    else
        for el in els
            extract_latlon_coords!(lat, lon, el)
        end
    end
    if should_close_vectors()
        extract_latlon_coords!(lat, lon, first(els))
    end
    return nothing
end

function extract_latlon_coords!(lat::Vector{T}, lon::Vector{T}, v::AbstractVector) where T<:AbstractFloat
    # If the elements are points, we simply call a specialized method for dealing with NaNs and straightening lines
    is_valid_point(eltype(v)) && return _extract_latlon_coords_pointvector!(lat, lon, v)
    # We simply call recursively on each element otherwise
    for item in v
        extract_latlon_coords!(lat, lon, item)
    end
    return nothing
end

"""
    extract_latlon_coords([T::Type{<:AbstractFloat} = Float32], item)

Returns a NamedTuple with two vectors `lat` and `lon` containing the corresponding coordinates of all the points contained within the provided `item`.

This is mostly intended to simplify creation of the `lat` and `lon` keyword arguments to provide to the `scattergeo` function from `PlotlyBase`. By default points are converted to Float32 and NaN values are inserted between each separate vector of points to allow plotting multiple geometries within a single trace.
"""
function extract_latlon_coords(T::Type{<:AbstractFloat}, item)
    lat = T[]
    lon = T[]
    extract_latlon_coords!(lat, lon, item)
    return (; lat, lon)
end
extract_latlon_coords(item) = extract_latlon_coords(Float32, item)

"""
    geo_plotly_trace([T = Float32, tracefunc = scattergeo, ]item; kwargs...)

Extracts the lat/lon coordinates from `item` using `extract_latlon_coords(T, item)` and then constructs a plotly trace with `tracefunc` using the extracted coordinates.

# Arguments
- `T::Type{<:AbstractFloat}`: The type to convert the coordinates to, which is fed to `extract_latlon_coords`. Defaults to `Float32`.
- `tracefunc::Function`: The function to use to construct the trace, it can only be `scatter` or `scattergeo`. Defaults to `scattergeo`.
- `item`: The item to extract the coordinates from.

# Keyword Arguments
- All the keyword arguments provided are forwarded to the `tracefunc` function.
"""
function geo_plotly_trace end

"""
    geo_plotly_trace_default_kwargs(item, tracefunc)

Returns a NamedTuple with the default keyword arguments to feed the `tracefunc` function for the type of `item`.
The `tracefunc` argument is mandatory when adding methods to this function but is only used for dispatch.

This is used to have some default item specific keyword arguments when calling `geo_plotly_trace`.
!!! note
    The default keyword arguments specified with this function can still be overridden by the `kwargs...` passed directly to `geo_plotly_trace`.
"""
function geo_plotly_trace_default_kwargs(item, tracefunc)
    @nospecialize
    return (;)
end