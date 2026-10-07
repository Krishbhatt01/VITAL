function d = crossTrack(lat, lon, h, lat0, lon0, chi0, K)
%CROSSTRACK  Distance (m, + right) of a point from a rhumb line on the ellipsoid.
%   d = vital.nesc.crossTrack(lat, lon, h, lat0, lon0, chi0, K)
%     lat, lon, h   the point (geodetic, rad, m)
%     lat0, lon0    a point of the line (rad); chi0 its true course (rad, from north)
%   Method (proposed ADR N7): in Mercator coordinates of the ellipsoid
%   (X = longitude, Y = isometric latitude psi = atanh(sin lat) - e atanh(e sin lat))
%   a rhumb line is straight and the map is conformal. The perpendicular offset
%   dm = dX cos(chi0) - dY sin(chi0) is scaled by (N + h) cos(lat) at the
%   latitude midway (in Y) between the point and the foot of the perpendicular.
%   Used for the case 13.4 lateral-offset logic (TM Vol II p.65: user-supplied).
vital.validate.finite([lat lon h lat0 lon0 chi0], 'cross-track inputs');
e = sqrt(K.e2);
iso = @(p) atanh(sin(p)) - e * atanh(e * sin(p));
dX = mod(lon - lon0 + pi, 2*pi) - pi;
Y = iso(lat); Y0 = iso(lat0);
dY = Y - Y0;
dm = dX * cos(chi0) - dY * sin(chi0);
Yf = Y + dm * sin(chi0);                % foot of the perpendicular (in Y)
latm = invIso((Y + Yf) / 2, e, lat);
N = K.a / sqrt(1 - K.e2 * sin(latm)^2);
d = dm * (N + h) * cos(latm);
end

function p = invIso(Y, e, p)
% Inverse isometric latitude by fixed-point iteration (converges in a few steps).
for it = 1:30
    pn = 2 * atan(exp(Y) * ((1 + e * sin(p)) / (1 - e * sin(p)))^(e / 2)) - pi / 2;
    if abs(pn - p) < 1e-15, p = pn; return; end
    p = pn;
end
end
