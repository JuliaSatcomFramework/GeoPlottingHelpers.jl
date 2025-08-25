@testitem "PairIterator" begin
    using Test
    using GeoPlottingHelpers: PairIterator

    @test length(PairIterator([1,2,3])) == 3
    @test length(PairIterator([1,2,3,4])) == 4

    @test eltype(PairIterator([1,2,3])) == Pair{Int, Int}

    @test collect(PairIterator([1,2,3])) == [(1 => 2), (2 => 3), (3 => 1)]
end

@testitem "Great Circle crossing" begin
    using GeoPlottingHelpers: crossing_latitude_great_circle, slerp

    p1 = (150, 20)
    p2 = (-150, 20)
    pt = slerp(p1, p2, 0.5)
    gc_lat = crossing_latitude_great_circle(p1, p2)
    @test pt[2] ≈ gc_lat atol=1e-6
end