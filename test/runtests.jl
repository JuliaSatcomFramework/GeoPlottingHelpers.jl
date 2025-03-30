using TestItemRunner

@testitem "Aqua" begin
    using Aqua
    using GeoPlottingHelpers
    Aqua.test_all(GeoPlottingHelpers)
end

@run_package_tests verbose=true