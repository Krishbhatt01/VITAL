function C = quat2dcm(q)
%QUAT2DCM  C_bn from a scalar-first N->B quaternion (normalized first).
%   Matches the Aerospace Toolbox quat2dcm(q.'). See CONVENTIONS.md section 3.
q = vital.frames.quatNormalize(q);
q0 = q(1); q1 = q(2); q2 = q(3); q3 = q(4);
C = [q0^2+q1^2-q2^2-q3^2, 2*(q1*q2+q0*q3),     2*(q1*q3-q0*q2);
     2*(q1*q2-q0*q3),     q0^2-q1^2+q2^2-q3^2, 2*(q2*q3+q0*q1);
     2*(q1*q3+q0*q2),     2*(q2*q3-q0*q1),     q0^2-q1^2-q2^2+q3^2];
end
