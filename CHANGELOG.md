# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [0.1.11] - 2025-10-06
### Changed
- Updated compat of Meshes/CoordRefSystems to include 0.55/0.19 versions.

## [0.1.10] - 2025-08-26
### Fixed
- Fixed `extract_latlon_coords` not correctly inserting NaNs between two ropes, as the `geom_iterable` method for `Chain` was not returning an iterator of geometries but an iterator of points.

## [0.1.9] - 2025-08-26
### Fixed
- Fixed a typo/error in the `antimeridian_crossing_great_circle` function.
- Refactored the internals of the great circle crossing computations to be more flexible in the input types.

## [0.1.8] - 2025-08-26
### Changed
- Updated the `geom_iterable` method for `Multi` (before it was only defined for `MultiPolygon`) to allow generic auto plotting of `Multi`s.

## [0.1.7] - 2025-08-26
### Added
- Added support for `Meshes.Chain`s in `extract_latlon_coords` (via a method for `GeoPlottingHelpers.geom_iterable`)
- Added internal helper functions to compute great circle antimeridian latitude crossing and to compute points over a great circle arc between two given poitns (using the Slerp algorithm)
  - These functions are not currently exported or used internally in the latlon coordinate extraction.

## [0.1.6] - 2025-08-21

### Changed
- Refactored the method of `extract_latlon_coords` taking a vector as input to be more consistent with the intended API.

### Fixed
- Fixed `extract_latlon_coords` not respecting various settings (e.g. `OVERSAMPLE_LINES`, `CLOSE_VECTORS`) when fed a vector of different types all satisfying the `is_valid_point` interface.
  - This only used to work when checking `is_valid_point` on the `eltype` of the input vector, thus failing for vectors of heterogeneous types.
- Stopped `get_borders_trace_110` from always printing a wrong warning when called with default keyword arguments.

## [0.1.5] - 2025-07-15

### Added
- Added the possibility of customizing settings also per trace when calling `geo_plotly_trace` or via extending the `GeoPlottingHelpers.geo_plotly_trace_default_kwargs` argument. See docstrings for more details
- Added a new settings `FORCE_ORIENTATION` to force orientation of points in `Meshes.Ring` to be counterclockwise or clockwise (defaults to keep as is). 
  - This is useful because when filling polygons within plotly, rings with CCW winding (the defaults for outer rings according to GeoJSON) will actually fill towards the outside, so doing the opposite of what intended

## [0.1.4] - 2025-07-11
### Added
- Added support for `to_raw_lonlat` for the following inputs:
  - `NamedTuple` inputs with `lat` and `lon` fields (in either order)
  - `Tuple` or `NamedTuple` inputs with angles from Unitful as values (also mixed, e.g. one Real and one Unitful value)

## [0.1.3] - 2025-06-29
### Added
- Added the `get_borders_trace_110` and `get_coastlines_trace_110` functions to easily create Plotly traces for the borders and coastlines of countries at 110m resolution.

## [0.1.2] - 2025-03-31
### Added
- Added `geo_plotly_trace_default_kwargs` (non-exported) to provide default keyword arguments to `geo_plotly_trace` for custom items (and optionally different for `scatter` and `scattergeo`).

## [0.1.1] - 2025-03-30

### Added
Added `PLOT_STRAIGHT_LINES` as alias for the `OVERSAMPLE_LINES` ScopedValue (still internal) to be more consistent with the keys of the `PLOT_SETTINGS` Dict accessible via `with_settings`.

## [0.1.0] - 2025-03-30
Initial release of the `GeoPlottingHelpers.jl` package.