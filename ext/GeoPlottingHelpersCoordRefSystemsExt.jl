module GeoPlottingHelpersCoordRefSystemsExt

using CoordRefSystems: CoordRefSystems, Cartesian2D, WGS84Latest, LatLon, raw
using GeoPlottingHelpers

GeoPlottingHelpers.to_raw_lonlat(p::LatLon{WGS84Latest}) = raw(p)
GeoPlottingHelpers.to_raw_lonlat(p::Cartesian2D) = raw(p)

end