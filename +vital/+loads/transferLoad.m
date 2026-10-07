function [F_B, M_B] = transferLoad(F_A, M_A, rB_inA, C_BA)
%TRANSFERLOAD  Move a load from frame A's origin to frame B's origin.
%   F_B = C_BA F_A
%   M_B = C_BA (M_A + (r_A - r_B) x F_A) = C_BA (M_A - rB_inA x F_A)
%   rB_inA : origin of B expressed in A coordinates (m)
%   C_BA   : A -> B direction-cosine matrix
%   (docs/CONVENTIONS.md section 6)
vital.validate.finite(F_A, 'force');
vital.validate.finite(M_A, 'moment');
vital.validate.finite(rB_inA, 'offset');
vital.validate.finite(C_BA, 'DCM');
F_A = F_A(:); M_A = M_A(:); rB_inA = rB_inA(:);
F_B = C_BA * F_A;
M_B = C_BA * (M_A - cross(rB_inA, F_A));
end
