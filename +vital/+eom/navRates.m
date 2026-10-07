function nav = navRates(lat, h, v_ned, K, omega)
%NAVRATES  Angular rates of the local NED frame (NED axes), rad/s.
%   nav = vital.eom.navRates(lat, h, v_ned, K, omega)
%     lat  geodetic latitude (rad); h geometric height (m); v_ned Earth-relative
%     velocity, NED (m/s); K Earth constants; omega Earth rate (rad/s, 0 = off)
%   nav.w_ie_n  Earth rate           omega [cos(lat); 0; -sin(lat)]
%   nav.w_en_n  transport rate       [v_E/(R_N+h); -v_N/(R_M+h); -v_E tan(lat)/(R_N+h)]
%   nav.w_in_n  w_ie_n + w_en_n      (NED relative to inertial space)
%   nav.RN, nav.RM  prime-vertical and meridional radii of curvature (m)
%   A body that holds its Euler angles relative to local level has
%   w_bi = C_bn w_in_n (SIM 5's trim rate definition, TM Vol II p.228).
%   The transport rate is singular at the poles (tan(lat)); lat = +/-90 deg
%   exactly raises vital:badInput.
vital.validate.finite([lat h], 'lat/h');
vital.validate.finite(v_ned, 'NED velocity');
if abs(cos(lat)) < 1e-12
    error('vital:badInput', 'the local NED frame is undefined at the pole (lat = %g rad).', lat);
end
s2 = sin(lat)^2;
RN = K.a / sqrt(1 - K.e2 * s2);
RM = RN * (1 - K.e2) / (1 - K.e2 * s2);
v = v_ned(:);
nav.w_ie_n = omega * [cos(lat); 0; -sin(lat)];
nav.w_en_n = [v(2) / (RN + h); -v(1) / (RM + h); -v(2) * tan(lat) / (RN + h)];
nav.w_in_n = nav.w_ie_n + nav.w_en_n;
nav.RN = RN; nav.RM = RM;
end
