function q = dcm2quat(C)
%DCM2QUAT  Scalar-first quaternion (q0 >= 0) from C_bn, by Shepperd's method.
%   The largest of q0^2..q3^2 is taken from the diagonal first, so the
%   result stays accurate for any rotation (no division by a small q0).
vital.validate.finite(C, 'DCM');
t = [1 + C(1,1) + C(2,2) + C(3,3);
     1 + C(1,1) - C(2,2) - C(3,3);
     1 - C(1,1) + C(2,2) - C(3,3);
     1 - C(1,1) - C(2,2) + C(3,3)];
[~, k] = max(t);
s = 2 * sqrt(t(k));                 % s = 4 * q_k
switch k
    case 1
        q = [s/4; (C(2,3)-C(3,2))/s; (C(3,1)-C(1,3))/s; (C(1,2)-C(2,1))/s];
    case 2
        q = [(C(2,3)-C(3,2))/s; s/4; (C(1,2)+C(2,1))/s; (C(1,3)+C(3,1))/s];
    case 3
        q = [(C(3,1)-C(1,3))/s; (C(1,2)+C(2,1))/s; s/4; (C(2,3)+C(3,2))/s];
    case 4
        q = [(C(1,2)-C(2,1))/s; (C(1,3)+C(3,1))/s; (C(2,3)+C(3,2))/s; s/4];
end
if q(1) < 0, q = -q; end
q = q / norm(q);
end
