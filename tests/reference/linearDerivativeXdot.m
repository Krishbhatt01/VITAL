function [xd, F, M] = linearDerivativeXdot(P, x, u)
%LINEARDERIVATIVEXDOT  Closed-form xdot of the analytic linear-derivative aircraft
%   (tests/reference/linearDerivativeAircraft.m; TEST HELPER, increment I1).
%   [xd, F, M] = linearDerivativeXdot(P, x, u)
%     P  the parameter struct of linearDerivativeAircraft; x the 13-state
%        [v_b; w_b; q (N->B, scalar first); p_n]; u = [de da dr throttle];
%        ZERO WIND (the air-relative velocity and rates are x(1:3), x(4:6)).
%     xd the 6-DOF equations written out (the same algebra as class header 1 of
%        tests/M9/i0/tI0LinearDerivativeAircraft.m): the loads of
%        LinearDerivativeComponent at the CG, gravity m g C_bn [0; 0; 1], the
%        rigid-body equations with J = [Ixx 0 -Ixz; 0 Iyy 0; -Ixz 0 Izz].
%     F, M the component force and moment (body axes, about the CG = the
%        component origin), i.e. what y.F_aero / y.M_aero must read when the
%        component is classified as aerodynamic.
a = P.a; g = P.g; m = P.m_kg;
du = x(1) - P.Ue; v = x(2); dw = x(3) - P.We; p = x(4); q = x(5); r = x(6);
dde = u(1) - P.de_e; da = u(2); dr = u(3); dt = u(4) - P.t_e;
F = m * [P.Xe / m + a.Xu * du + a.Xw * dw + a.Xq * q + a.Xde * dde + a.Xt * dt;
         a.Yv * v + a.Yp * p + a.Yr * r + a.Yda * da + a.Ydr * dr;
         P.Ze / m + a.Zu * du + a.Zw * dw + a.Zq * q + a.Zde * dde + a.Zt * dt];
M = [P.Ixx * (a.Lv * v + a.Lp * p + a.Lr * r + a.Lda * da + a.Ldr * dr);
     P.Iyy * (a.Mu * du + a.Mw * dw + a.Mq * q + a.Mde * dde + a.Mt * dt);
     P.Izz * (a.Nv * v + a.Np * p + a.Nr * r + a.Nda * da + a.Ndr * dr)];
J = [P.Ixx 0 -P.Ixz; 0 P.Iyy 0; -P.Ixz 0 P.Izz];
e = x(7:10) / norm(x(7:10));               % C_bn written out (Stevens & Lewis 2003, eq. 1.3-33)
q0 = e(1); q1 = e(2); q2 = e(3); q3 = e(4);
Cbn = [q0^2 + q1^2 - q2^2 - q3^2, 2 * (q1 * q2 + q0 * q3), 2 * (q1 * q3 - q0 * q2);
       2 * (q1 * q2 - q0 * q3), q0^2 - q1^2 + q2^2 - q3^2, 2 * (q2 * q3 + q0 * q1);
       2 * (q1 * q3 + q0 * q2), 2 * (q2 * q3 - q0 * q1), q0^2 - q1^2 - q2^2 + q3^2];
w = x(4:6); vb = x(1:3); qn = x(7:10);
Om = [0 -w(1) -w(2) -w(3); w(1) 0 w(3) -w(2); w(2) -w(3) 0 w(1); w(3) w(2) -w(1) 0];
xd = [F / m + Cbn * [0; 0; g] - cross(w, vb); J \ (M - cross(w, J * w)); 0.5 * Om * qn; Cbn.' * vb];
end
