@testsnippet setup_settings begin
    using CoordRefSystems
    using Meshes
    using PlotlyBase
    using GeoPlottingHelpers: with_settings, should_close_vectors, should_insert_nan, force_orientation, should_shorten_lines, NT_SETTINGS
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
