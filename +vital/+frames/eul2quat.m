function q = eul2quat(phi, theta, psi)
%EUL2QUAT  Scalar-first quaternion (N->B) from 3-2-1 Euler angles (rad).
%   q = [q0; q1; q2; q3], consistent with vital.frames.dcm321 through
%   vital.frames.quat2dcm. See docs/CONVENTIONS.md section 3.
vital.validate.finite([phi theta psi], 'Euler angles');
cp = cos(phi/2); sp = sin(phi/2); ct = cos(theta/2); st = sin(theta/2); cy = cos(psi/2); sy = sin(psi/2);
q = [cp*ct*cy + sp*st*sy;
     sp*ct*cy - cp*st*sy;
     cp*st*cy + sp*ct*sy;
     cp*ct*sy - sp*st*cy];
if q(1) < 0, q = -q; end
end
