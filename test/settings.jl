@testsnippet setup_settings begin
    using CoordRefSystems
    using Meshes
    using PlotlyBase
    using GeoPlottingHelpers: with_settings, should_close_vectors, should_insert_nan, force_orientation, should_shorten_lines, nan_as_nothing, NT_SETTINGS
end

@testitem "with_settings" setup = [setup_settings] begin
    r = rand(Ring; crs = LatLon)
    r_cw = orientation(r) === CW ? r : reverse(r) # Force this to be CW
    r_ccw = reverse(r_cw)
    ll = extract_latlon_coords(r_cw)
    # We test that by default the orientation is not forced
    llr = extract_latlon_coords(r_ccw)
    @test ll.lat == reverse(llr.lat) && ll.lon == reverse(llr.lon)
    # We test forcing the orientation to be CCW
    with_settings(:FORCE_ORIENTATION => :CCW) do
        @test extract_latlon_coords(r_cw) == llr
    end

    # We test that settings provided as NamedTuple are lower priority than the one provided as Dict
    with_settings(:FORCE_ORIENTATION => :CCW) do
        with_settings((; FORCE_ORIENTATION = :CW)) do # This is inner but lower priority
            @test extract_latlon_coords(r_cw) == llr
        end
    end

    # Test that passing custom settings to the trace is respected
    @test geo_plotly_trace(r_cw).lat == ll.lat # This is the reference behavior without custom settings
    @test geo_plotly_trace(r_cw; settings_nt = (; FORCE_ORIENTATION = :CCW)).lat == llr.lat # This is the reference behavior without custom settings
    # We test that if both dict and settings are provided, the dict ones are used
    @test geo_plotly_trace(r_cw; settings_nt = (; FORCE_ORIENTATION = :CCW), settings_dict = Dict(:FORCE_ORIENTATION => :CW)).lat == ll.lat # This is the reference behavior without custom settings
end

@testitem "NAN_AS_NOTHING setting" setup = [setup_settings] begin
    r1 = rand(Ring; crs = LatLon)
    r2 = rand(Ring; crs = LatLon)

    # extract_latlon_coords always returns plain float vectors regardless of NAN_AS_NOTHING
    @test nan_as_nothing() == false
    ll = extract_latlon_coords([r1, r2])
    @test eltype(ll.lat) <: AbstractFloat
    @test any(isnan, ll.lat)

    with_settings(:NAN_AS_NOTHING => true) do
        @test nan_as_nothing() == true
        ll = extract_latlon_coords([r1, r2])
        @test eltype(ll.lat) <: AbstractFloat  # unaffected — still plain floats with NaN
        @test any(isnan, ll.lat)
    end

    # geo_plotly_trace replaces `NaN` with `nothing` when NAN_AS_NOTHING = true
    ll_trace = geo_plotly_trace([r1, r2]; settings_dict = Dict(:NAN_AS_NOTHING => true))
    @test any(isnothing, ll_trace.lat)
    @test all(x -> isnothing(x) || !isnan(x), ll_trace.lat)

    # Default geo_plotly_trace still produces NaN separators
    ll_trace_default = geo_plotly_trace([r1, r2])
    @test any(isnan, ll_trace_default.lat)
    @test !any(isnothing, ll_trace_default.lat)

    # NAN_AS_NOTHING via settings_nt keyword (lower priority than settings_dict)
    ll_trace_nt = geo_plotly_trace([r1, r2]; settings_nt = (; NAN_AS_NOTHING = true))
    @test any(isnothing, ll_trace_nt.lat)

    # settings_dict takes priority over settings_nt
    ll_trace_prio = geo_plotly_trace([r1, r2]; settings_nt = (; NAN_AS_NOTHING = true), settings_dict = Dict(:NAN_AS_NOTHING => false))
    @test any(isnan, ll_trace_prio.lat)
    @test !any(isnothing, ll_trace_prio.lat)

    # Setting reverts to default outside with_settings block
    @test nan_as_nothing() == false
end
