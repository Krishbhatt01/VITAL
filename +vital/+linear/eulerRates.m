function rates = eulerRates(ph, th, p, q, r)
%EULERRATES  3-2-1 Euler-angle rates from body rates (CONVENTIONS 3).
%   rates = vital.linear.eulerRates(phi, theta, p, q, r)
%     phi, theta  roll and pitch Euler angles (rad); |theta| < pi/2
%     p, q, r     body rates (rad/s)
%     rates       [phidot; thetadot; psidot] (rad/s)
%       phidot   = p + (q sin(phi) + r cos(phi)) tan(theta)
%       thetadot = q cos(phi) - r sin(phi)
%       psidot   = (q sin(phi) + r cos(phi)) / cos(theta)
%   Used by vital.linear.linearize for the kinematic rows of A. Tested
%   against quaternion kinematics at a banked, pitched state
%   (tests/M5/tLinearizeR1.m, review R1 M4). Singular at |theta| = 90 deg
%   (vital:badInput).
arguments
    ph (1,1) double
    th (1,1) double
    p (1,1) double
    q (1,1) double
    r (1,1) double
end
vital.validate.finite([ph th p q r], 'Euler angles and body rates');
if abs(cos(th)) < 1e-12
    error('vital:badInput', 'Euler rates are singular at theta = +/-90 deg.');
end
rates = [p + (q * sin(ph) + r * cos(ph)) * tan(th);
         q * cos(ph) - r * sin(ph);
         (q * sin(ph) + r * cos(ph)) / cos(th)];
end
