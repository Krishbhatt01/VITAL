function [alpha_v, beta_v] = vaneAngles(v_air, w_b, r_vane)
%VANEANGLES  Exact angle of attack and sideslip sensed by vanes at r_vane.
%   v_loc = v_air + w_b x r_vane (r_vane: vane position relative to the CG,
%   body axes, x forward, z down). For small rates this reduces to the
%   corrected forms of CONVENTIONS.md section 5:
%     alpha_v = alpha - q x_v / V,   beta_v = beta + r x_v / V - p z_v / V
vital.validate.finite(v_air, 'air velocity');
vital.validate.finite(w_b, 'body rate');
vital.validate.finite(r_vane, 'vane position');
v = v_air(:) + cross(w_b(:), r_vane(:));
V = norm(v);
if V < 1e-6
    error('vital:airdata:zeroAirspeed', 'local airspeed at the vane is zero.');
end
alpha_v = atan2(v(3), v(1));
beta_v = asin(max(-1, min(1, v(2) / V)));
end
