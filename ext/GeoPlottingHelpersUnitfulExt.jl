module GeoPlottingHelpersUnitfulExt

using GeoPlottingHelpers: GeoPlottingHelpers, to_raw_lonlat, _LONLAT_NT
using Unitful

const Deg = Quantity{<:Real,NoDims,typeof(u"°")}
const Rad = Quantity{<:Real,NoDims,typeof(u"rad")}

const VALID_ANGLE_QUANTITIES = Union{Deg, Rad}
const VALID_TP = Tuple{VALID_ANGLE_QUANTITIES, VALID_ANGLE_QUANTITIES}

# This convert to degrees, strip units and forward to the original function
function GeoPlottingHelpers.to_raw_lonlat(lonlat::Union{_LONLAT_NT{VALID_TP}, VALID_TP})
    # Process inputs
    lonlat = map(lonlat) do x
        uconvert(u"°", x) |> ustrip
    end
    return to_raw_lonlat(lonlat)
end

end