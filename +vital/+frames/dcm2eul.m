function e = dcm2eul(C)
%DCM2EUL  3-2-1 Euler angles [phi; theta; psi] (rad) from C_bn.
%   phi = atan2(C23, C33), theta = atan2(-C13, hypot(C11, C12)) (better
%   conditioned than -asin(C13) near 90 deg), psi = atan2(C12, C11).
%   Gimbal convention (CONVENTIONS.md section 3): when |C13| is within
%   1e-12 of 1, phi = 0 and psi carries the combined angle,
%   psi = atan2(-C21, C22).
vital.validate.finite(C, 'DCM');
if ~isequal(size(C), [3 3])
    error('vital:badInput', 'DCM must be 3x3.');
end
theta = atan2(-C(1,3), hypot(C(1,1), C(1,2)));
if abs(C(1,3)) >= 1 - 1e-12
    phi = 0;
    psi = atan2(-C(2,1), C(2,2));
else
    phi = atan2(C(2,3), C(3,3));
    psi = atan2(C(1,2), C(1,1));
end
e = [phi; theta; psi];
end
