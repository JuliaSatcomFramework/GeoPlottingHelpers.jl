# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased
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