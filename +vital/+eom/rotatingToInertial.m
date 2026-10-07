function s = rotatingToInertial(x, t, omega)
%ROTATINGTOINERTIAL  ECI position, velocity and attitude from a rotating-plant state.
%   s = vital.eom.rotatingToInertial(x, t, omega)
%     x      [r_e; v_e; q_be; w_bi] (vital.plant.derivativesRotating layout)
%     t      time since ECI and ECEF coincided (s; TM Vol II p.603: t = 0)
%     omega  Earth rotation rate (rad/s)
%   s.C_ei = R3(omega t)  (ECI -> ECEF)
%   s.r_i  = C_ei' r_e,   s.v_i = C_ei' (v_e + w x r_e),   s.C_bi = C_be C_ei
%   s.w_bi = x(11:13) (already inertial)
x = x(:);
th = omega * t;
Cei = [cos(th) sin(th) 0; -sin(th) cos(th) 0; 0 0 1];
r = x(1:3); v = x(4:6); q = x(7:10);
s.C_ei = Cei;
s.r_i = Cei.' * r;
s.v_i = Cei.' * (v + cross([0; 0; omega], r));
s.C_bi = vital.frames.quat2dcm(q / norm(q)) * Cei;
s.w_bi = x(11:13);
end
