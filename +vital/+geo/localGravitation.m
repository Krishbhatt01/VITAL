function gd = localGravitation(lat, lon, h, K)
%LOCALGRAVITATION  Gravitation component along local geodetic "down" (m/s^2, + down).
%   This is the quantity NESC records as localGravity (TM Vol II Table 75:
%   "Gravitational acceleration of the vehicle's CM in the local 'down'
%   direction"), i.e. without the centrifugal term.
r = vital.geo.lla2ecef(lat, lon, h, K);
gn = vital.geo.dcmEcefToNed(lat, lon) * vital.geo.gravitation(r, K);
gd = gn(3);
end
