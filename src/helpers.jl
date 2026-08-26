
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
oversample_tol() = Float64(get(PLOT_SETTINGS[], :OVERSAMPLE_TOL, NT_SETTINGS.OVERSAMPLE_TOL[][]))

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
    xyz = slerp(a, b, t)
    return xyz_to_lonlat(xyz)
end
function slerp(a::NTuple{3}, b::NTuple{3}, t)
    Ω = acos(dot(a, b))
    sΩ = sin(Ω)
    xyz = @. (a * sin((1 - t) * Ω) + b * sin(t * Ω)) / sΩ
    return xyz
end

# The actual crossing implementation is taken from the antimeridian python implementation but is basic algebra
function antimeridian_crossing_great_circle(start, stop)
    a = lonlat_to_xyz(start)
    b = lonlat_to_xyz(stop)
    return antimeridian_crossing_great_circle(a, b)
end
function antimeridian_crossing_great_circle(a::NTuple{3}, b::NTuple{3})
    # The cross product identifies the plane passing through both points
    n1 = cross(a, b)
    # The unity Y vector identifies the perpendicular to the meridian plane. The sign of the Y coordinate to identify the normal should make the normal vector be located in the same hemisphere of the starting point.
    n2 = (0, copysign(1, a[2]), 0)
    # The intersection of both planes normalized returns the xyz coordinate of the intersection over the sphere's surface
    intersection = normalize(cross(n1, n2))
end
function crossing_latitude_great_circle(start, stop)
    intersection = antimeridian_crossing_great_circle(start, stop)
    # We are only interested in the latitude so we can just take the arcsin of the z coordinate
    return asind(intersection[3])
end

# Squared deviation in degrees between two lon/lat points, as seen on the plot. The caller compares
# it against a squared tolerance, as the square root adds cost and changes no comparison. The
# difference in longitude wraps at the antimeridian, as a point at 179 and a point at -179 are two
# degrees apart, not 358.
function sq_lonlat_deviation(p1::NTuple{2}, p2::NTuple{2})
    Δlon = p2[1] - p1[1]
    Δlon > 180 && (Δlon -= 360)
    Δlon < -180 && (Δlon += 360)
    Δlat = p2[2] - p1[2]
    return Δlon * Δlon + Δlat * Δlat
end

# Each level of subdivision doubles the number of points. The cap stops the recursion on an input
# whose deviation never goes below the tolerance, such as two ends on opposite sides of the earth.
const OVERSAMPLE_MAX_DEPTH = 12

#=
`subdivide!` adds points to `out` to make the segment `p1`-`p2` appear straight on a scattergeo
plot. A scattergeo plot draws a pair of consecutive points as a great circle arc, but a border or a
coverage area follows straight lines in lat/lon. The two paths differ most at the middle of the
segment, so the code compares the two middle points and splits the segment when they are more
than `tol` apart. This puts points only where the two paths differ.

This is the adaptive subdivision test that a 2D graphics library uses to draw a curve, and that
d3-geo uses to resample a projected line. Two references:
  - Shemanarev, "Adaptive Subdivision of Bezier Curves", 2005:
    https://agg.sourceforge.net/antigrain.com/research/adaptive_bezier/index.html
  - d3-geo `src/projection/resample.js`:
    https://github.com/d3/d3-geo/blob/main/src/projection/resample.js
d3-geo measures the distance from the middle point to the chord instead, and it holds two more
tests that a projection needs and a scattergeo trace does not.

`a` and `b` are the xyz coordinates of `p1` and `p2`. The caller passes them in, as the recursion
computes each of them once and then reuses it for both halves.
=#
function subdivide!(out, p1::NTuple{2}, p2::NTuple{2}, a::NTuple{3}, b::NTuple{3}, tol::Float64, depth::Int)
    if depth > 0
        mid = (p1 .+ p2) ./ 2
        s = a .+ b
        # `atand` ignores the length of a vector and `asind` needs only its third component, so
        # the code scales that one component instead of the whole vector.
        n2 = s[1] * s[1] + s[2] * s[2] + s[3] * s[3]
        gc = (atand(s[2], s[1]), asind(clamp(s[3] / sqrt(n2), -1, 1)))
        # The sum cancels when the two ends are on opposite sides of the earth. No single great
        # circle joins such a pair, so the code splits it without a test.
        if n2 < 1e-18 || sq_lonlat_deviation(mid, gc) > tol * tol
            mid_xyz = lonlat_to_xyz(mid)
            subdivide!(out, p1, mid, a, mid_xyz, tol, depth - 1)
            subdivide!(out, mid, p2, mid_xyz, b, tol, depth - 1)
            return out
        end
    end
    # The end point belongs to the next segment, which pushes it as its own start point.
    push!(out, p1)
    return out
end

#=
This function takes two points in lat/lon and returns a vector of points which make the line
between them appear straight on a scattergeo plot. The returned vector holds the start point but
not the end point, as the next segment pushes that one as its own start point.
=#
function line_plot_coords(start, stop)
    lon1, lat1 = to_raw_lonlat(start)
    lon2, lat2 = to_raw_lonlat(stop)
    p1 = (Float64(lon1), Float64(lat1))
    p2 = (Float64(lon2), Float64(lat2))
    out = NTuple{2,Float64}[]
    # An edge with both ends at the same pole covers no ground, as longitude does not identify a
    # place at |lat| = 90. Every point of such an edge lands in the same spot, which is waste for a
    # scattergeo trace and fatal for a consumer that triangulates the ring. The difference in
    # longitude is also meaningless there, so `subdivide!` would split the edge to the depth cap.
    # This test must stay before the antimeridian branch, which would otherwise cut such an edge
    # into two pole edges. The second half of the test keeps a pole-to-pole edge out, as that one
    # covers real ground.
    # The tolerance is absolute, in degrees, as `≈` would scale it with the eltype and widen the
    # test to 0.03 degrees for Float32 input, which the border and coastline data uses.
    if 90 - abs(p1[2]) < 1e-6 && abs(p1[2] - p2[2]) < 1e-6
        push!(out, p1)
        return out
    end
    if abs(p2[1] - p1[1]) > 180 && should_shorten_lines()
        # We have to shorten and split at antimeridian
        mid_lat = crossing_latitude_flat(p1, p2)
        append!(out, line_plot_coords(p1, (copysign(180, p1[1]), mid_lat)))
        append!(out, line_plot_coords((copysign(180, p2[1]), mid_lat), p2))
        return out
    end
    return subdivide!(out, p1, p2, lonlat_to_xyz(p1), lonlat_to_xyz(p2), oversample_tol(), OVERSAMPLE_MAX_DEPTH)
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



