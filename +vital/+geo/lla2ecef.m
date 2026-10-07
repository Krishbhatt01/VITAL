function r = lla2ecef(lat, lon, h, K)
%LLA2ECEF  Geodetic latitude, longitude (rad) and height (m) -> ECEF position (m).
%   r = [(N + h) cos(lat) cos(lon); (N + h) cos(lat) sin(lon); (N (1 - e2) + h) sin(lat)]
%   with N = a / sqrt(1 - e2 sin^2 lat) (TM Vol II eq. 14). For the sphere
%   model e2 = 0 and this reduces to eq. 10.
vital.validate.finite([lat lon h], 'lat/lon/h');
N = K.a / sqrt(1 - K.e2 * sin(lat)^2);
r = [(N + h) * cos(lat) * cos(lon);
     (N + h) * cos(lat) * sin(lon);
     (N * (1 - K.e2) + h) * sin(lat)];
end
