# GeoPlottingHelpers.jl

[![Build Status](https://github.com/JuliaSatcomFramework/GeoPlottingHelpers.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaSatcomFramework/GeoPlottingHelpers.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSatcomFramework/GeoPlottingHelpers.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSatcomFramework/GeoPlottingHelpers.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Helper functions for plotting geographic geometries and points on Earth using
[PlotlyBase.jl](https://github.com/JuliaPlots/PlotlyBase.jl).
Supports plain tuples, `CoordRefSystems.LatLon`, `Meshes` geometries, and
`Unitful` angles out of the box, and is easy to extend for custom types.

## Installation

```julia
using Pkg
Pkg.add("GeoPlottingHelpers")
```

PlotlyBase, Meshes, CoordRefSystems, and Unitful are optional dependencies —
install only what you need alongside GeoPlottingHelpers.

## Quick start

```julia
using GeoPlottingHelpers, PlotlyBase

# Coastlines + country borders in two lines
coastlines = get_coastlines_trace_110()
borders    = get_borders_trace_110()
Plot([coastlines, borders])
```

```julia
# Plot a (lon, lat) point
trace = geo_plotly_trace((2.35, 48.85); mode = "markers", name = "Paris")
Plot([get_coastlines_trace_110(), trace])
```

## Core concepts

### Point types

`geo_plotly_trace` and `extract_latlon_coords` accept any type for which
`to_raw_lonlat` is defined. Built-in support covers:

| Type | Convention |
|------|-----------|
| `(lon, lat)` plain tuple | lon first |
| `(lon=…, lat=…)` NamedTuple | either field order |
| `CoordRefSystems.LatLon` | lat first (CoordRefSystems convention) |
| `(lon_deg * u"°", lat_deg * u"°")` Unitful | lon first, degrees or radians |
| `Meshes` geometries (`Ring`, `PolyArea`, `Box`, `Rope`, `Multi`, …) | — |

A `Vector` of any of the above produces a single trace with NaN separators
between sub-geometries.

### Settings

Several behaviours can be tuned with `with_settings`:

| Key | Values | Default | Effect |
|-----|--------|---------|--------|
| `:INSERT_NAN` | `Bool` | `true` | Insert NaN between sub-geometries |
| `:OVERSAMPLE_LINES` | `:NONE` / `:NORMAL` / `:SHORT` | `:NONE` | Add interpolated points so edges look straight on `scattergeo` |
| `:CLOSE_VECTORS` | `Bool` | `false` | Repeat first point at end of each vector |
| `:FORCE_ORIENTATION` | `:NONE` / `:CW` / `:CCW` | `:NONE` | Force ring winding order (use `:CW` with Plotly's `fill="toself"`) |

```julia
# Apply settings for a single trace
with_settings(:OVERSAMPLE_LINES => :NORMAL) do
    geo_plotly_trace(big_box_geometry; name = "Corrected box")
end

# Or pass per-trace via keyword (lower priority than with_settings)
geo_plotly_trace(geom; settings_dict = Dict(:FORCE_ORIENTATION => :CW))
```

## Examples

### Filled polygon (satellite footprint)

```julia
using GeoPlottingHelpers, PlotlyBase, Meshes, CoordRefSystems

n = 60
ring = Ring([Point(LatLon(10 + 20*sind(θ), 13 + 20*cosd(θ)))
             for θ in range(0, 360; length=n+1)[1:n]])
footprint = PolyArea(ring)

trace = with_settings(:FORCE_ORIENTATION => :CW) do
    geo_plotly_trace(footprint;
        fill       = "toself",
        fillcolor  = "rgba(255,100,0,0.3)",
        mode       = "lines",
        line_color = "darkorange",
        name       = "Coverage",
    )
end

Plot([get_coastlines_trace_110(; line_color = "gray"), trace])
```

### Multiple disjoint regions (`Multi`)

```julia
using GeoPlottingHelpers, PlotlyBase, Meshes, CoordRefSystems

make_box(lat1, lon1, lat2, lon2) =
    PolyArea(Ring([Point(LatLon(lat1,lon1)), Point(LatLon(lat1,lon2)),
                   Point(LatLon(lat2,lon2)), Point(LatLon(lat2,lon1))]))

regions = Multi([make_box(10,-20,30,0), make_box(35,10,50,40)])

trace = geo_plotly_trace(regions;
    fill = "toself", fillcolor = "rgba(200,50,50,0.3)",
    mode = "lines", line_color = "darkred", name = "Regions")

Plot([get_coastlines_trace_110(; line_color = "gray"), trace])
```

### Route as a `Rope` (open polyline)

```julia
using GeoPlottingHelpers, PlotlyBase, Meshes, CoordRefSystems

route = Rope([Point(LatLon(51.5,-0.1)), Point(LatLon(48.9,2.4)),
              Point(LatLon(41.9,12.5)), Point(LatLon(25.2,55.3))])

trace = with_settings(:OVERSAMPLE_LINES => :NORMAL) do
    geo_plotly_trace(route; mode = "lines+markers", line_color = "royalblue",
                             name = "Route")
end

Plot([get_coastlines_trace_110(; line_color = "lightgray"), trace],
     Layout(geo = attr(projection_type = "natural earth")))
```

## Extending for custom types

Implement one or more of these functions to teach GeoPlottingHelpers about a
new type:

- `GeoPlottingHelpers.to_raw_lonlat(p) -> (lon, lat)` — for point-like types.
- `GeoPlottingHelpers.geom_iterable(g)` — returns an iterable of sub-geometries
  or points for geometry types.
- `GeoPlottingHelpers.geo_plotly_trace_default_kwargs(item, tracefunc)` — returns
  a `NamedTuple` of default Plotly kwargs for a type.

Check each function's docstring for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).