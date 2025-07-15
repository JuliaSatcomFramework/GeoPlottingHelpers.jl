# GeoPlottingHelpers.jl

[![Build Status](https://github.com/JuliaSatcomFramework/GeoPlottingHelpers.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaSatcomFramework/GeoPlottingHelpers.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSatcomFramework/GeoPlottingHelpers.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSatcomFramework/GeoPlottingHelpers.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

This package contains some helper functions to streamling extracting geometrical coordinates from geometries/points to simplify plotting over earth using `PlotlyBase.jl` and its derivatives.

This package might in the future also be used to provide a common or closely related API to also simplify plotting via Makie.jl or Cesium.js

## Usage

The main user facing functions are:
- `extract_latlon_coords`: Used to return a NamedTuple which contains just two fields `lat` and `lon` which are vectors that can be used for use in `scattergeo` traces.
- `geo_plotly_trace`: Which can be used to create either a `scattergeo` or `scatter` trace for plotting geometries/points and relies internally on `extract_latlon_coords`.

Some details on how latlon coords are extracted can be tweaked thanks to the `with_settings` function, and lastly, adding custom extraction of latlon and custom plotting for specific types can be obtained by adding custom methods to the following functions (not all needed, check respective docstrings):
- `geom_iterable`
- `to_raw_lonlat`
- `geo_plotly_trace_default_kwargs`

Check the docstrings for more details.