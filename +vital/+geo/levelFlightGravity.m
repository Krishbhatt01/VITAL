function g = levelFlightGravity(lat, lon, h, v_ned, K)
%LEVELFLIGHTGRAVITY  Effective down-acceleration for steady level flight over a
%   rotating ellipsoidal Earth, for flat-earth trims of rotating-Earth cases.
%   g = vital.geo.levelFlightGravity(lat, lon, h, v_ned, K)
%     lat, lon  geodetic (rad);  h  geometric height (m)
%     v_ned     Earth-relative velocity, NED (m/s);  K  vital.geo.constants
%   g = down components of
%       gravitation                    (J2 or inverse square, vital.geo.gravitation)
%     + centrifugal  -w_E x (w_E x r)
%     + Coriolis     -2 w_E x v        (Eotvos effect)
%     + curvature    -(v_N^2/(R_M + h) + v_E^2/(R_N + h))
%   i.e. the specific force the wings and engine must supply, per unit mass,
%   to hold a constant geodetic height at constant velocity. With v = 0 it is
%   ordinary gravity (gravitation + centrifugal). R_N, R_M: prime-vertical
%   and meridional radii of curvature.
%   Found necessary in M4: gravity alone explains only half of the NESC-vs-
%   README pitch difference; with these terms the F-16 trim matches the NESC
%   tools to 1e-4 deg (tests/M4/tF16Trim.m).
vital.validate.finite([lat lon h], 'lat/lon/h');
vital.validate.finite(v_ned, 'velocity');
v_ned = v_ned(:);
r = vital.geo.lla2ecef(lat, lon, h, K);
C = vital.geo.dcmEcefToNed(lat, lon);
wE = [0; 0; K.omega];
grav = C * vital.geo.gravitation(r, K);
cen = C * (-cross(wE, cross(wE, r)));
cor = -2 * cross(C * wE, v_ned);
s2 = sin(lat)^2;
Rn = K.a / sqrt(1 - K.e2 * s2);
Rm = Rn * (1 - K.e2) / (1 - K.e2 * s2);
curv = -(v_ned(1)^2 / (Rm + h) + v_ned(2)^2 / (Rn + h));
g = grav(3) + cen(3) + cor(3) + curv;
end
