function [F_b, M_cg] = sumLoadsAtCG(F_R, M_R, r_cg, m, C_bn, g_n)
%SUMLOADSATCG  Total body-axis force and moment about the CG, with gravity.
%   F_R, M_R : 3xN component loads in body axes about the BFRP (N may be 0)
%   r_cg     : CG position in BFRP coordinates (m)
%   m, C_bn, g_n : mass (kg), NED->body DCM, gravity vector in NED (m/s^2)
%   M_cg = sum(M_R) - r_cg x sum(F_R)       (BFRP -> CG)
%   F_b  = sum(F_R) + m C_bn g_n             (gravity acts at the CG: no moment)
%   Inertial (d'Alembert) terms are NOT loads; the EOM contains them.
vital.validate.finite(F_R, 'component forces');
vital.validate.finite(M_R, 'component moments');
vital.validate.finite(r_cg, 'CG position');
vital.validate.finite(m, 'mass');
vital.validate.finite(C_bn, 'DCM');
vital.validate.finite(g_n, 'gravity');
Fc = sum(reshape(F_R, 3, []), 2);
MR = sum(reshape(M_R, 3, []), 2);
M_cg = MR - cross(r_cg(:), Fc);
F_b = Fc + m * (C_bn * g_n(:));
end
