function K = constants(model)
%CONSTANTS  Earth model constants (SI) from NASA/TM-2015-218675 Vol II Table 73 (p.93).
%   K = vital.geo.constants('wgs84')   WGS-84 ellipsoid, J2 gravitation
%   K = vital.geo.constants('sphere')  sphere of equal surface area, inverse-square
%   Fields: name, a (equatorial radius), invf, f, e2, b, mu, omega, J2, R
%   (sphere radius). Rotation on/off is chosen by the environment, not
%   here. These values take precedence over Initial_Conditions.xlsx (ADR-008).
arguments
    model (1,:) char {mustBeMember(model, {'wgs84','sphere'})}
end
K.name = model;
K.mu = 3.986004418e14;          % m^3/s^2
K.omega = 7.292115e-5;          % rad/s
K.R = 6371007.1809;             % m, sphere of equal surface area
switch model
    case 'wgs84'
        K.a = 6378137.0;
        K.invf = 298.257223563;
        K.f = 1 / K.invf;
        K.J2 = 0.00108262982;
    case 'sphere'
        K.a = K.R;
        K.invf = Inf;
        K.f = 0;
        K.J2 = 0;
end
K.e2 = K.f * (2 - K.f);
K.b = K.a * (1 - K.f);
end
