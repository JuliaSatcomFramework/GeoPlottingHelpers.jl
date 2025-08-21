@testitem "PairIterator" begin
    using Test
    using GeoPlottingHelpers: PairIterator

    @test length(PairIterator([1,2,3])) == 3
    @test length(PairIterator([1,2,3,4])) == 4

    @test eltype(PairIterator([1,2,3])) == Pair{Int, Int}

    @test collect(PairIterator([1,2,3])) == [(1 => 2), (2 => 3), (3 => 1)]
end