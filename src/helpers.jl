
# These are internal function used to parse the settings to customize the behavior of `extract_latlon_coords!`.
should_insert_nan() = get(PLOT_SETTINGS[], :INSERT_NAN, NT_SETTINGS.INSERT_NAN[][])
should_shorten_lines() = get(PLOT_SETTINGS[], :OVERSAMPLE_LINES) do
    get(PLOT_SETTINGS[], :PLOT_STRAIGHT_LINES, NT_SETTINGS.OVERSAMPLE_LINES[][])
end === :SHORT
should_oversample_points() = get(PLOT_SETTINGS[], :OVERSAMPLE_LINES) do
    get(PLOT_SETTINGS[], :PLOT_STRAIGHT_LINES, NT_SETTINGS.OVERSAMPLE_LINES[][])
end ∈ (:SHORT, :NORMAL)
should_close_vectors() = get(PLOT_SETTINGS[], :CLOSE_VECTORS, NT_SETTINGS.CLOSE_VECTORS[][])
force_orientation() = get(PLOT_SETTINGS[], :FORCE_ORIENTATION, NT_SETTINGS.FORCE_ORIENTATION[][])

# For should_insert_nan we also add a method that takes lat and lon vectors and also checks if they are empty
should_insert_nan(lat::AbstractVector, lon::AbstractVector) = return should_insert_nan() && !isempty(lat) && !isempty(lon)

"""
    is_valid_point(p)

This function checks if `p` represents a valid point/coordinate for the `GeoPlottingHelpers` package.
It simply checks whether `p` has a method defined for `to_raw_lonlat` which converts it into a longitude and latitude tuple.
"""
is_valid_point(::Type{P}) where P = hasmethod(to_raw_lonlat, Tuple{P})
is_valid_point(p) = is_valid_point(typeof(p))

is_iterable_geometry(::Type{T}) where T = hasmethod(geom_iterable, Tuple{T})
is_iterable_geometry(item) = is_iterable_geometry(typeof(item))

# This function computes the latitude of the crossing of the antimeridian singularity at 180° longitude assuming flat earth (not using geodesics but flat lines in latlon)
function crossing_latitude_flat(start, stop)
    lon1, lat1 = to_raw_lonlat(start)
    lon2, lat2 = to_raw_lonlat(stop)
    Δlat = lat2 - lat1
    coeff = 180 - lon1
    den = lon2 + 360 - lon1
    if lon1 <= 0
        coeff = 180 + lon1
        den = lon1 + 360 - lon2
    end
    return lat1 + coeff * Δlat / den
end

# This is the part for computing latitude crossing using great circle geodesic. This relies on cross product and norm which are usually in LinearAlgebra but we don't want the dependency on it here, so we just reimplement those here.  
function cross(a::NTuple{3}, b::NTuple{3})
    a1, a2, a3 = a
    b1, b2, b3 = b
    return (a2 * b3 - a3 * b2, a3 * b1 - a1 * b3, a1 * b2 - a2 * b1)
end
function normalize(a::NTuple{3})
    return a ./ hypot(a...)
end
dot(a::NTuple{3}, b::NTuple{3}) = mapreduce(*, +, a, b)

function lonlat_to_xyz(p)
    lon, lat = to_raw_lonlat(p)
    slat, clat = sincosd(lat)
    slon, clon = sincosd(lon)
    return (clon * clat, slon * clat, slat)
end

function xyz_to_lonlat(xyz::NTuple{3})
    x, y, z = xyz
    lat = asind(z)
    lon = atand(y, x)
    return lon, lat
end

"""
    slerp(start, stop, t)

Compute the point on the great circle arc between two points (start and stop) at a given fraction of the way between them.

The two inputs points can be any object for which `to_raw_lonlat` is defined, and `t` must be a number between 0 and 1.

It returns a Tuple (lon, lat) with the coordinate of the point on the great circle arc between `start` and `stop` at a normalized distance `t` from `start` to `stop`.
"""
function slerp(start, stop, t)
    a = lonlat_to_xyz(start)
    b = lonlat_to_xyz(stop)
    Ω = acos(dot(a, b))
    sΩ = sin(Ω)
    xyz = @. (a * sin((1 - t) * Ω) + b * sin(t * Ω)) / sΩ
    return xyz_to_lonlat(xyz)
end

# The actual crossing implementation is taken from the antimeridian python implementation but is basic algebra
function crossing_latitude_great_circle(start, stop)
    # We transform the two points into xyz coordinates over the sphere
    a = lonlat_to_xyz(start)
    b = lonlat_to_xyz(stop)
    # The cross product identifies the plane passing through both points
    n1 = cross(a, b)
    # The unity Y vector identifies the meridian plane
    n2 = (0, 1, 0)
    # The intersection of both planes 
    intersection = normalize(cross(n1, n2))
    # We are only interested in the latitude so we can just take the arcsin of the z coordinate
    return asind(intersection[3])
end

#= 
This function will take two points in lat/lon and return a generator which produces more points to simulate straight lines on scattergeo plots. It has denser points closer to the poles as the distortion from scattergeo are more pronounced there.
This function is also extremely heuristic, and can probably be improved significantly in terms of the algorithm
=#
function line_plot_coords(start, stop)
    lon1, lat1 = to_raw_lonlat(start)
    lon2, lat2 = to_raw_lonlat(stop)
    Δlat = lat2 - lat1
    Δlon = lon2 - lon1
    if Δlon ≈ 0
        return (start,)
    end
    if abs(Δlon) > 180 && should_shorten_lines()
        # We have to shorten and split at antimeridian
        mid_lat = crossing_latitude_flat((lon1, lat1), (lon2, lat2))
        return Iterators.flatten((
            line_plot_coords((lon1, lat1), (copysign(180, lon1), mid_lat)),
            line_plot_coords((copysign(180, lon2), mid_lat), (lon2, lat2))
        ))
    end
    nrm = hypot(Δlat, Δlon)
    should_split = nrm > 10
    min_length = if should_split
        10
    else
        maxlat = max(abs(lat1), abs(lat2))
        val = (100 / max(maxlat, 10))
        if maxlat > 65
            val /= 2
        end
        if maxlat > 80
            val /= 2
        end
        val
    end
    npts = ceil(Int, nrm / min_length)
    lat_step = Δlat / npts
    lon_step = Δlon / npts
    f(n) = (lon1 + n * lon_step, lat1 + n * lat_step)
    ns = 0:(npts-1)
    if should_split
        Iterators.flatten(line_plot_coords(f(n), f(n + 1)) for n in ns)
    else
        (f(n) for n in 0:(npts-1))
    end
end

# This function makes sure that the Dict with borders and coastlines has been loaded
function ensure_borders_loaded(; force=false)
    isempty(COUNTRIES_BORDERS_COASTLINES_110) || force || return
    # We load the dictionary
    toml_dict = TOML.parsefile(joinpath(artifact"borders_110m", "borders_110m.toml"))
    for (key, value) in toml_dict
        lat = map(Float32, value["lat"])
        lon = map(Float32, value["lon"])
        COUNTRIES_BORDERS_COASTLINES_110[key] = (; lat, lon)
    end
    return nothing
end

# This is an helper struct to iterate over pair of consecutive elements within a vector, always return as last element the pair between the last and the first element
struct PairIterator{V<:AbstractVector}
    wrapped::V
end

# Iterator interface
Base.length(iter::PairIterator) = return length(iter.wrapped)
Base.eltype(::PairIterator{V}) where V = return Pair{eltype(V),eltype(V)}

function Base.iterate(iter::PairIterator, state=1)
    L = length(iter)
    state <= L || return nothing
    (; wrapped) = iter
    item = if state == L
        wrapped[end] => wrapped[1]
    else
        wrapped[state] => wrapped[state+1]
    end
    return item, state + 1
end



