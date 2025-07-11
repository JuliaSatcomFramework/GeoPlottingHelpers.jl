module GeoPlottingHelpersUnitfulExt

using GeoPlottingHelpers: GeoPlottingHelpers, to_raw_lonlat, _LONLAT_NT
using Unitful

const Deg = Quantity{<:Real,NoDims,typeof(u"°")}
const Rad = Quantity{<:Real,NoDims,typeof(u"rad")}

const VALID_ANGLE_QUANTITIES = Union{Deg, Rad}
const VALID_VAL = Union{Real, VALID_ANGLE_QUANTITIES}
const VALID_TP = Tuple{VALID_VAL, VALID_VAL}

todeg(x::VALID_ANGLE_QUANTITIES) = uconvert(u"°", x) |> ustrip
todeg(x::Real) = x

# This convert to degrees, strip units and forward to the original function
function GeoPlottingHelpers.to_raw_lonlat(lonlat::Union{_LONLAT_NT{VALID_TP}, VALID_TP})
    # Process inputs
    lonlat = map(todeg, lonlat)
    return to_raw_lonlat(lonlat)
end

end