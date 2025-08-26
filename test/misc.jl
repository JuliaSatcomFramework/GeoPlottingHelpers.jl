@testitem "PairIterator" begin
    using Test
    using GeoPlottingHelpers: PairIterator

    @test length(PairIterator([1, 2, 3])) == 3
    @test length(PairIterator([1, 2, 3, 4])) == 4

    @test eltype(PairIterator([1, 2, 3])) == Pair{Int,Int}

    @test collect(PairIterator([1, 2, 3])) == [(1 => 2), (2 => 3), (3 => 1)]
end

@testitem "Great Circle crossing" begin
    using GeoPlottingHelpers: crossing_latitude_great_circle, slerp, lonlat_to_xyz, antimeridian_crossing_great_circle, dot

    p1 = (150, 20)
    p2 = (-150, 20)
    pt = slerp(p1, p2, 0.5)
    gc_lat = crossing_latitude_great_circle(p1, p2)
    @test pt[2] ≈ gc_lat atol = 1e-6

    # We test slightly different by extracting the corresponding `t` from the intersection to use slerp
    p1 = (-103.177, 27.569)
    p2 = (155.896, -33.4032)
    a = lonlat_to_xyz(p1)
    b = lonlat_to_xyz(p2)
    intersection = antimeridian_crossing_great_circle(a, b)
    # We can find the normalized distance between p1 and the intersection by finding the ratio in the angle betwwen a and intersection over the angle between a and b. This works because the intersection is by design lying on the plane containing the great circle arc between a and b.
    t = acos(dot(a, intersection)) / acos(dot(a, b))
    pt = slerp(p1, p2, t)
    gc_lat = crossing_latitude_great_circle(p1, p2)
    @test pt[2] ≈ gc_lat atol = 1e-6
end