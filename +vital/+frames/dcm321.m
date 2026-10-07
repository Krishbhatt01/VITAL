function C = dcm321(phi, theta, psi)
%DCM321  Direction-cosine matrix C_bn for 3-2-1 (yaw-pitch-roll) Euler angles.
%   C = vital.frames.dcm321(phi, theta, psi) with angles in rad returns
%   C_bn = R1(phi) R2(theta) R3(psi) (passive rotations), which maps NED
%   components to body components: v_b = C_bn v_n. Identical to the
%   Aerospace Toolbox angle2dcm(psi, theta, phi, 'ZYX').
%   See docs/CONVENTIONS.md section 3.
vital.validate.finite([phi theta psi], 'Euler angles');
cph = cos(phi); sph = sin(phi); cth = cos(theta); sth = sin(theta); cps = cos(psi); sps = sin(psi);
R1 = [1 0 0; 0 cph sph; 0 -sph cph];
R2 = [cth 0 -sth; 0 1 0; sth 0 cth];
R3 = [cps sps 0; -sps cps 0; 0 0 1];
C = R1 * R2 * R3;
end
