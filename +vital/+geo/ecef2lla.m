function [lat, lon, h] = ecef2lla(r, K)
%ECEF2LLA  ECEF position (m) -> geodetic latitude, longitude (rad), height (m).
%   Fixed-point iteration on latitude with the pole-safe height formula
%   h = p cos(lat) + z sin(lat) - a sqrt(1 - e2 sin^2 lat); converges to
%   machine precision in a few iterations for any altitude of interest.
vital.validate.finite(r, 'ECEF position');
x = r(1); y = r(2); z = r(3);
p = hypot(x, y);
lon = atan2(y, x);
if K.e2 == 0
    lat = atan2(z, p);
    h = norm(r) - K.a;
    return
end
lat = atan2(z, p * (1 - K.e2));
for it = 1:50
    s = sin(lat);
    N = K.a / sqrt(1 - K.e2 * s^2);
    latNew = atan2(z + K.e2 * N * s, p);
    if abs(latNew - lat) < 1e-15
        lat = latNew;
        break
    end
    lat = latNew;
end
h = p * cos(lat) + z * sin(lat) - K.a * sqrt(1 - K.e2 * sin(lat)^2);
end
