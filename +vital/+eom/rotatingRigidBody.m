function xdot = rotatingRigidBody(x, F_b, M_cg, m, J, g_e, omega)
%ROTATINGRIGIDBODY  Rigid-body state derivative over a rotating Earth (ECEF form).
%   xdot = vital.eom.rotatingRigidBody(x, F_b, M_cg, m, J, g_e, omega)
%     x      [r_e (3) m; v_e (3) m/s; q_be (4); w_bi (3) rad/s]
%            r_e   CM position, ECEF
%            v_e   CM velocity RELATIVE TO ECEF, ECEF axes
%            q_be  scalar-first quaternion ECEF -> body (C_be = quat2dcm(q_be))
%            w_bi  body angular rate relative to INERTIAL space, body axes
%     F_b    applied (non-gravitational) force, body axes (N)
%     M_cg   applied moment about the CM, body axes (N m)
%     m, J   mass (kg), inertia tensor about the CM, body axes (kg m^2)
%     g_e    gravitation (mass attraction only) at r_e, ECEF axes (m/s^2)
%     omega  Earth rotation rate about ECEF z (rad/s; 0 for a non-rotating Earth)
%   Equations (proposed ADR N1, reports/fragments/nesc/DECISIONS.md):
%     rdot_e = v_e
%     vdot_e = C_eb F_b/m + g_e - 2 w x v_e - w x (w x r_e),   w = [0 0 omega]
%     qdot   = 1/2 Omega(w_be) q + k (1 - q'q) q,  w_be = w_bi - C_be w, k = 1 1/s
%     J wdot_bi = M_cg - w_bi x (J w_bi)
%   The centrifugal and Coriolis terms come from the rotating frame, so g_e is
%   GRAVITATION, never gravity (CONVENTIONS 4). No explicit time dependence:
%   ECI is recovered by vital.eom.rotatingToInertial (ECI = ECEF at t = 0).
x = x(:);
r = x(1:3); v = x(4:6); q = x(7:10); wb = x(11:13);
nq = norm(q);
if nq == 0
    error('vital:badInput', 'zero quaternion.');
end
C = quatDcm(q / nq);                           % C_be
we = [0; 0; omega];
vdot = C.' * F_b(:) / m + g_e(:) - 2 * cross(we, v) - cross(we, cross(we, r));
wbe = wb - C * we;
p = wbe(1); qq = wbe(2); rr = wbe(3);
Om = [0 -p -qq -rr; p 0 rr -qq; qq -rr 0 p; rr qq -p 0];
qdot = 0.5 * Om * q + 1.0 * (1 - q.' * q) * q;
wdot = J \ (M_cg(:) - cross(wb, J * wb));
xdot = [v; vdot; qdot; wdot];
end

function C = quatDcm(q)
% Same formula as vital.frames.quat2dcm (q already unit).
q0 = q(1); q1 = q(2); q2 = q(3); q3 = q(4);
C = [q0^2+q1^2-q2^2-q3^2, 2*(q1*q2+q0*q3),     2*(q1*q3-q0*q2);
     2*(q1*q2-q0*q3),     q0^2-q1^2+q2^2-q3^2, 2*(q2*q3+q0*q1);
     2*(q1*q3+q0*q2),     2*(q2*q3-q0*q1),     q0^2-q1^2-q2^2+q3^2];
end
