function x = rotatingState(lat, lon, h, v_ned, eul, w_bi, K)
%ROTATINGSTATE  Rotating-plant state from geodetic position, NED velocity and attitude.
%   x = vital.eom.rotatingState(lat, lon, h, v_ned, eul, w_bi, K)
%     lat, lon  geodetic latitude, longitude (rad);  h  height above the
%               reference ellipsoid or sphere (m)
%     v_ned     velocity relative to the Earth, local NED axes (m/s)
%     eul       [phi; theta; psi] 3-2-1 Euler angles relative to local geodetic
%               NED (rad)
%     w_bi      body rate relative to inertial space, body axes (rad/s)
%     K         Earth constants (vital.geo.constants or a custom struct)
%   x = [r_e; v_e; q_be; w_bi], the layout of vital.plant.derivativesRotating.
vital.validate.finite([lat lon h], 'lat/lon/h');
vital.validate.finite(v_ned, 'NED velocity');
vital.validate.finite(eul, 'Euler angles');
vital.validate.finite(w_bi, 'body rate');
r = vital.geo.lla2ecef(lat, lon, h, K);
C_ne = vital.geo.dcmEcefToNed(lat, lon);
C_bn = vital.frames.dcm321(eul(1), eul(2), eul(3));
q = vital.frames.dcm2quat(C_bn * C_ne);
x = [r; C_ne.' * v_ned(:); q; w_bi(:)];
end
