@testsnippet setup_api begin
    using PlotlyBase
    using CoordRefSystems
    using Meshes
    using GeoPlottingHelpers: with_settings
    using Unitful
    f_box(l1, l2) = Box(Point(l1), Point(l2))

    using Test
end

@testitem "to_raw_lonlat" setup = [setup_api] begin
    ll = LatLon(10, 20)
    @test to_raw_lonlat(ll) == (20, 10)
    p = Point(ll)
    @test to_raw_lonlat(p) == (20, 10)
    @test to_raw_lonlat(Meshes.flat(p)) == (20, 10)

    # We test NamedTuples
    nt1 = (lat=10, lon=20)
    nt2 = (lon=20, lat=10)
    @test to_raw_lonlat(nt1) == (20, 10)
    @test to_raw_lonlat(nt2) == (20, 10)

    # We test Unitful
    todeg(x) = x * u"°"
    @test to_raw_lonlat(map(todeg, nt1)) == (20, 10)
    @test to_raw_lonlat(map(todeg, nt2)) == (20, 10)
    @test to_raw_lonlat(map(todeg, (20, 10))) == (20, 10)

    # Mixed inputs support
    @test to_raw_lonlat((20, 10 * u"°")) == (20, 10)
    @test to_raw_lonlat((deg2rad(20) * u"rad", 10 * u"°")) == (20, 10)
end

@testitem "extract_latlon_coords" setup = [setup_api] begin
    lat, lon = Float64[], Float64[]
    b1 = f_box(LatLon(10, 20), LatLon(30, 40))
    b2 = f_box(LatLon(-10, -30), LatLon(0, 0))
    b3 = f_box(LatLon(50, 30), LatLon(60, 70))

    p1 = boundary(b1) |> PolyArea
    p2 = boundary(b2) |> PolyArea
    p3 = boundary(b3) |> PolyArea
    m = Multi((p1, p2))
    g = GeometrySet([m, p3])

    test_len(op) = out -> op(out.lat |> length) && op(out.lon |> length)

    @test extract_latlon_coords(b1) |> test_len(==(5)) # We test that we have 5 points as we closed the ring
    @test extract_latlon_coords(p1) |> test_len(==(5)) # We test that we have 5 points as we closed the ring
    m_out = extract_latlon_coords(m)
    @test m_out |> test_len(==(11)) # We test that we have 10 points as we have added a NaN in the middle
    @test m_out.lat[6] |> isnan
    g_out = extract_latlon_coords(g)

    @test count(isnan, g_out.lat) == 2

    with_settings(:CLOSE_VECTORS => false) do
        @test extract_latlon_coords(b1) |> test_len(==(4)) # We test that we have 4 points as we did not close the ring
    end
    with_settings(:INSERT_NAN => false) do
        @test extract_latlon_coords(m) |> test_len(==(10)) # We test that we have 10 points as we have not added a NaN in the middle
        g_out = extract_latlon_coords(g)
        @test count(isnan, g_out.lat) == 0
    end

    # This is a box which crosses the antimeridian
    b_am = f_box(LatLon(85, 179.8), LatLon(86, -179.8))

    with_settings(:OVERSAMPLE_LINES => :NORMAL) do
        @test extract_latlon_coords(b_am) |> test_len(>(100)) # We are oversampling the line without shortening, so we have many more points than the original 4
    end

    # We test that providing directly a vector of points does not automatically close it by repeating the first point
    @test extract_latlon_coords(boundary(b_am) |> vertices) |> test_len(==(4))

    with_settings(:OVERSAMPLE_LINES => :SHORT) do
        @test extract_latlon_coords(b_am) |> test_len(==(7)) # Here we are making the line short, and since it only spans 0.4 in longitude we are simply adding 2 points at the antimeridian crossings and 1 additional point to close the ring
    end

    with_settings([:PLOT_STRAIGHT_LINES => :SHORT, :CLOSE_VECTORS => false]) do
        @test extract_latlon_coords([b_am]) |> test_len(==(6)) # Here we are making the line short, and since it only spans 0.4 in longitude we are simply adding 2 points at the antimeridian crossings
    end

    @test eltype(extract_latlon_coords(Float64, b1).lat) == Float64

    @test_throws "for which `geom_iterable` or `to_raw_lonlat` is defined" extract_latlon_coords(Sphere(rand(Point), 100))

    # We test here that vectors of valid points which are not represented by a same eltype also work correctly
    vs = [
        [(0, 0), LatLon(10, 0)],
        [LatLon(13, 13), (30, 30)]
    ]

    out = with_settings((; OVERSAMPLE_LINES=:NORMAL)) do
        extract_latlon_coords(vs)
    end
    @test count(isnan, out.lat) == 1
    @test length(out.lat) > 5 # We have 4 points and 1 NaN, so we check oversampling leading to more than 5 points

    polylike = [
        (0,0),
        LatLon(20, 0),
        LatLon(20,20),
        (20, 0)
    ]
    out = with_settings((; CLOSE_VECTORS=true)) do
        extract_latlon_coords(polylike)
    end
    @test count(isnan, out.lat) == 0
    @test length(out.lat) == length(polylike) + 1
    @test first(out.lat) == last(out.lat) && first(out.lon) == last(out.lon)

    out = with_settings((; OVERSAMPLE_LINES=:NORMAL)) do
        extract_latlon_coords(polylike)
    end
    @test count(isnan, out.lat) == 0
    @test length(out.lat) > 4 # We have 4 points but we are oversampling so we expect more
    # We check that the last lat and lon are equivalent to the ones of the last original point
    lon, lat = to_raw_lonlat(last(polylike))
    @test last(out.lat) ≈ lat
    @test last(out.lon) ≈ lon
end

@testitem "geo_plotly_trace" setup = [setup_api] begin
    b1 = f_box(LatLon(10, 20), LatLon(30, 40))

    tr = geo_plotly_trace(b1)
    @test tr isa GenericTrace
    @test tr.type === "scattergeo"
    @test eltype(tr.lat) == Float32
    @test tr.mode === "lines"

    tr = geo_plotly_trace(scatter, b1; mode="markers")
    @test tr.type === "scatter"
    @test tr.mode === "markers"

    pts = boundary(b1) |> vertices
    tr = geo_plotly_trace(Float64, scattergeo, pts)
    @test eltype(tr.lat) == Float64
    @test isempty(tr.mode) # We don't have a default for vectors of points

    @test_throws "The `tracefunc` must be either `scatter` or `scattergeo`" geo_plotly_trace(heatmap, b1)
end

@testitem "get_borders_trace_110" setup = [setup_api] begin
    tr = get_borders_trace_110(; line_color="blue")
    @test tr isa GenericTrace
    @test tr.type === "scattergeo"
    @test tr.line_color == "blue"

    tr = get_borders_trace_110(scatter; admin=["Italy", "France"])
    @test tr isa GenericTrace
    @test tr.type === "scatter"
    @test tr.mode === "lines"
    @test tr.line_color == "black"

    tr = get_borders_trace_110(scatter; admin="Spain", line_width=2)
    @test tr isa GenericTrace
    @test tr.type === "scatter"
    @test tr.mode === "lines"
    @test tr.line_width == 2

    @test_logs (:warn, r"not found") get_borders_trace_110(scatter; admin="spain")
    @test_logs (:warn, r"can't be extracted") get_borders_trace_110(scatter; admin="CoastLines")
end

@testitem "get_coastlines_trace_110" setup = [setup_api] begin
    tr = get_coastlines_trace_110()
    @test tr isa GenericTrace
    @test tr.type === "scattergeo"
    @test eltype(tr.lat) == Float32
end
