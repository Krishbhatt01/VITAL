function g = gravitation(r, K)
%GRAVITATION  Gravitational (mass-attraction) acceleration, m/s^2, in the axes of r.
%   Inverse square when K.J2 == 0 (TM Vol II eq. 27); otherwise J2 zonal
%   gravitation (eqs. 29-31):
%     gx = -mu x / r^3 [1 - 1.5 J2 (a/r)^2 (5 z^2/r^2 - 1)]
%     gy = -mu y / r^3 [1 - 1.5 J2 (a/r)^2 (5 z^2/r^2 - 1)]
%     gz = -mu z / r^3 [1 - 1.5 J2 (a/r)^2 (5 z^2/r^2 - 3)]
%   Valid in ECEF or ECI because the zonal field is symmetric about the
%   spin axis. No centrifugal term: that comes from the rotating-frame
%   EOM (CONVENTIONS.md section 4).
vital.validate.finite(r, 'position');
r = r(:);
rr = norm(r);
if rr == 0
    error('vital:badInput', 'gravitation is undefined at the Earth centre.');
end
base = -K.mu / rr^3;
if K.J2 == 0
    g = base * r;
    return
end
k = 1.5 * K.J2 * (K.a / rr)^2;
zz = (r(3) / rr)^2;
g = base * [r(1) * (1 - k * (5*zz - 1));
            r(2) * (1 - k * (5*zz - 1));
            r(3) * (1 - k * (5*zz - 3))];
end
