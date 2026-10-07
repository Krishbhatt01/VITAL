function r = stationToBody(rS, rDatum)
%STATIONTOBODY  Station coordinates (x aft, y right, z up) -> BFRP body axes.
%   r = diag(-1, 1, -1) (rS - rDatum), with rDatum the station coordinates
%   of the BFRP. Done once, at import (CONVENTIONS.md section 2).
vital.validate.finite(rS, 'station position');
vital.validate.finite(rDatum, 'station datum');
r = diag([-1 1 -1]) * (rS(:) - rDatum(:));
end
