"""
    lon, lat = to_raw_lonlat(p)

This function should take a single input representing a point on or around the Earth and returns a two Real numbers representing the longitude and latitude of the point expressed in degrees.

This function is used internally by other functions of `GeoPlottingHelpers` and should be expanded for custom points/types to fully utilize the features of `GeoPlottingHelpers`.
"""
to_raw_lonlat(lonlat::Tuple{Real,Real}) = lonlat

# Additional helper methods
to_raw_lonlat(lonlat::_LONLAT_NT{Tuple{Real,Real}}) = (lonlat.lon, lonlat.lat)

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

function extract_latlon_coords!(lat::Vector{T}, lon::Vector{T}, v::AbstractVector) where T<:AbstractFloat
    previous_point = false
    should_close = should_close_vectors() && all(is_valid_point, v)
    for (n, pair) in enumerate(PairIterator(v))
        p, pnext = pair
        if is_valid_point(p)
            if !previous_point && should_insert_nan(lat, lon)
                # Every time we have a point which was not preceded by another point we insert NaNs if the setting is enabled
                extract_latlon_coords!(lat, lon, (NaN, NaN))
            end
            if should_oversample_points() && is_valid_point(pnext)
                # We do eventual straightening only between couples of consecutive points
                ptrange = if should_close || n < length(v)
                    # For most cases where there is a segment between points we try to oversample the segment
                    line_plot_coords(p, pnext) 
                else
                    # In case we are at the last element and we should not close the vector, we don't try to oversample the last segment
                    (p,) 
                end
                for pt in ptrange
                    extract_latlon_coords!(lat, lon, pt)
                end
            else
                extract_latlon_coords!(lat, lon, p)
            end
            previous_point = true
        else
            # We simply call the function on the object
            extract_latlon_coords!(lat, lon, p)
            previous_point = false
        end
    end
    if should_close
        # We put back the first point
        extract_latlon_coords!(lat, lon, first(v))
    end
    return nothing
end

# This is useful to join together outputs of extract_latlon_coords
function extract_latlon_coords!(lat::Vector{T}, lon::Vector{T}, v::Union{@NamedTuple{lat::Vector{F}, lon::Vector{F}}, @NamedTuple{lon::Vector{F}, lat::Vector{F}}}) where {T<:AbstractFloat, F<:AbstractFloat}
    if should_insert_nan() && !isempty(lat) && !isempty(lon)
        extract_latlon_coords!(lat, lon, (NaN, NaN))
    end
    append!(lat, v.lat)
    append!(lon, v.lon)
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
!!! note "Customize settings"
    It is possible to customize the settings for how `extract_latlon_coords!` similarly to how it's done with `with_settings` by providing specific keywords to the [`geo_plotly_trace`](@ref) function (or to [`GeoPlottingHelpers.geo_plotly_trace_default_kwargs`](@ref)). The following keyword arguments are special and can be used for customizing or overriding settings:
    - `settings_dict`: This needs to be a `Dict{Symbol, Any}` where valid keys are the same provided to [`with_settings`](@ref) and behave as if `with_settings` was called.
    - `settings_nt`: This needs to be a `NamedTuple` where keys are again valid settings as per [`with_settings`](@ref), and the values are intended settings to be overridden compared to default ones. **Note that settings provided this way have lower priority than ones provided with either `with_settings` or with the `settings_dict` keyword argument.**
"""
function geo_plotly_trace end

"""
    geo_plotly_trace_default_kwargs(item, tracefunc)

Returns a NamedTuple with the default keyword arguments to feed the `tracefunc` function for the type of `item`.
The `tracefunc` argument is mandatory when adding methods to this function but is only used for dispatch.

This is used to have some default item specific keyword arguments when calling `geo_plotly_trace`.
!!! note
    The default keyword arguments specified with this function can still be overridden by the `kwargs...` passed directly to `geo_plotly_trace`.

!!! note "Customize settings"
    It is possible to customize the settings for how `extract_latlon_coords!` similarly to how it's done with `with_settings` by providing specific keywords to the [`geo_plotly_trace`](@ref) function (or to [`GeoPlottingHelpers.geo_plotly_trace_default_kwargs`](@ref)). The following keyword arguments are special and can be used for customizing or overriding settings:
    - `settings_dict`: This needs to be a `Dict{Symbol, Any}` where valid keys are the same provided to [`with_settings`](@ref) and behave as if `with_settings` was called.
    - `settings_nt`: This needs to be a `NamedTuple` where keys are again valid settings as per [`with_settings`](@ref), and the values are intended settings to be overridden compared to default ones. **Note that settings provided this way have lower priority than ones provided with either `with_settings` or with the `settings_dict` keyword argument.**

    The `geo_plotly_trace_default_kwargs` function should always use the `settings_nt` keyword argument when customizing settings so that explicitly provided settings given via `with_settings` takes precedence.
"""
function geo_plotly_trace_default_kwargs(item, tracefunc)
    @nospecialize
    return (;)
end

"""
    get_borders_trace_110(tracefunc::Function; admin = nothing, kwargs...)

Returns a PlotlyBase trace (using [`geo_plotly_trace`](@ref)) for the borders of the countries obtained from the NaturalEarth dataset with 110m resolution.
By default this returns a trace with borders of all the countries, but the list
of countries to consider can be specified using the `admin` keyword argument.

## Arguments
- `tracefunc::Function`: The function to use to construct the trace, it can only be `scatter` or `scattergeo` and is forwarded to `geo_plotly_trace`. Defaults to `scattergeo`.

## Keyword Arguments
- `admin`: If provided as a vector of `String` objects, it will be used to downselect the countries to plot in the trace interpreting the elements of `admin` as country admin names to keep (case sensitive).
- `kwargs...`: All the remaining keyword arguments are forwarded to the `geo_plotly_trace` function used internally.

## Note
The resulting trace will have the following default attributes (which can be overridden using the `kwargs...` argument):
- `mode = "lines"`
- `line_width = 1`
- `line_color = "black"`
- `showlegend = false`
- `hoverinfo = "none"`

## Examples
```julia
using GeoPlottingHelpers
using PlotlyBase

# Plot the borders of all countries, with blue as linecolor using a `scattergeo` trace
get_borders_trace_110(; line_color = "blue") |> PlotlyBase.Plot

# Plot the borders on a plain `scatter` trace just for italy and france
get_borders_trace_110(scatter; admin = ["Italy", "France"]) |> PlotlyBase.Plot
```

See also: [`geo_plotly_trace`](@ref), [`get_coastlines_trace_110`](@ref)
"""
function get_borders_trace_110(tracefunc::Function; admin = nothing, kwargs...)
    ensure_borders_loaded() # Make sure the Dict is loaded
    admins = if admin === nothing
        filter(k -> k !== "CoastLines", keys(COUNTRIES_BORDERS_COASTLINES_110))
    elseif admin isa AbstractString
        (admin,)
    else
        admin
    end
    function f(key) 
        if key === "CoastLines"
            @warn "You provided the `CoastLines` key but coastlines can't be extracted using `get_borders_trace_110`, use `get_coastlines_trace_110` instead"
            return nothing
        end
        return get(COUNTRIES_BORDERS_COASTLINES_110, key) do
            @warn "Country `$key` not found in the list of countries, remember that keys are case sensitive"
            return nothing
        end
    end
    selected = filter(!isnothing, [f(key) for key in admins])
    return geo_plotly_trace(tracefunc, selected; BORDERS_DEFAULT_KWARGS..., kwargs...)
end

"""
    get_coastlines_trace_110(tracefunc::Function; kwargs...)

Returns a PlotlyBase trace (using [`geo_plotly_trace`](@ref)) for the coastlines of the Earth obtained from the NaturalEarth dataset with 110m resolution.

## Arguments
- `tracefunc::Function`: The function to use to construct the trace, it can only be `scatter` or `scattergeo` and is forwarded to `geo_plotly_trace`. Defaults to `scattergeo`.

## Keyword Arguments
- `kwargs...`: All the remaining keyword arguments are forwarded to the `geo_plotly_trace` function used internally.

## Note
The resulting trace will have the following default attributes (which can be overridden using the `kwargs...` argument):
- `mode = "lines"`
- `line_width = 1`
- `line_color = "black"`
- `showlegend = false`
- `hoverinfo = "none"`

## Examples
```julia
using GeoPlottingHelpers
using PlotlyBase

# Plot the coastlines using a `scattergeo` trace and a red line color
get_coastlines_trace_110(; line_color = "red") |> PlotlyBase.Plot

# Plot the coastlines on a plain `scatter` trace
get_coastlines_trace_110(scatter) |> PlotlyBase.Plot
```

See also: [`geo_plotly_trace`](@ref), [`get_borders_trace_110`](@ref)
"""
function get_coastlines_trace_110(tracefunc::Function; kwargs...)
    ensure_borders_loaded() # Make sure the Dict is loaded
    return geo_plotly_trace(tracefunc, COUNTRIES_BORDERS_COASTLINES_110["CoastLines"]; BORDERS_DEFAULT_KWARGS..., kwargs...)
end