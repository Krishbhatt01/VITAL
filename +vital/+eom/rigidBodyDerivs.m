function xdot = rigidBodyDerivs(v, w, q, F_b, M_cg, m, J, h_rot, hdot_rot)
%RIGIDBODYDERIVS  Flat-earth rigid-body state derivative about the CG.
%   xdot = vital.eom.rigidBodyDerivs(v, w, q, F_b, M_cg, m, J)
%   xdot = vital.eom.rigidBodyDerivs(..., h_rot, hdot_rot)
%     v     body-axis velocity of the CG (m/s)       w  body rates (rad/s)
%     q     scalar-first N->B quaternion              F_b total force incl. gravity (N)
%     M_cg  moment about the CG (N m)                 m, J mass (kg), inertia tensor (kg m^2)
%     h_rot, hdot_rot  angular momentum of spinning parts and its rate (default 0)
%   Returns xdot = [vdot; wdot; qdot; pdot_n] (13x1):
%     vdot  = F_b/m - w x v
%     wdot  = J \ (M_cg - w x (J w + h_rot) - hdot_rot)
%     qdot  = 1/2 Omega(w) q + k (1 - q'q) q,  k = 1 1/s (constraint stabilization)
%     pdot_n = C_bn' v
%   Flat, non-rotating Earth: gravity (with centrifugal) is inside F_b
%   (CONVENTIONS.md sections 4 and 6). d'Alembert terms are not loads.
if nargin < 8, h_rot = zeros(3,1); end
if nargin < 9, hdot_rot = zeros(3,1); end
vital.validate.finite(v, 'velocity');
vital.validate.finite(w, 'body rate');
vital.validate.finite(q, 'quaternion');
vital.validate.finite(F_b, 'force');
vital.validate.finite(M_cg, 'moment');
vital.validate.finite([m; J(:); h_rot(:); hdot_rot(:)], 'mass properties');
v = v(:); w = w(:); q = q(:);
nq = norm(q);
if nq == 0
    error('vital:badInput', 'zero quaternion.');
end
C = vital.frames.quat2dcm(q / nq);
p = w(1); qq = w(2); r = w(3);
Om = [0 -p -qq -r; p 0 r -qq; qq -r 0 p; r qq -p 0];
vdot = F_b(:) / m - cross(w, v);
wdot = J \ (M_cg(:) - cross(w, J*w + h_rot(:)) - hdot_rot(:));
qdot = 0.5 * Om * q + 1.0 * (1 - q.'*q) * q;
pdot = C.' * v;
xdot = [vdot; wdot; qdot; pdot];
end
