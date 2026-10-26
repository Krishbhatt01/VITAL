function c = compare(os, om)
%COMPARE  Difference between two simulation outputs (Simulink path vs vital.sim.run),
%   with the metric of docs/PLAN_M9.md section 7:
%     e_i = max_k |x_s,i - x_m,i| / max(1, max_k |x_m,i|),  E = max_i e_i
%   c fields: e (nx x 1), E, tErr (max |t_s - t_m|), uErr (max |u_s - u_m| over
%   samples 1..N, the commands applied over each step), n (samples).
%   Errors: vital:badInput when the two logs have different sizes.
if ~isequal(size(os.x), size(om.x)) || ~isequal(size(os.t), size(om.t))
    error('vital:badInput', 'vital.slx.compare: logs differ in size (%s vs %s).', mat2str(size(os.x)), mat2str(size(om.x)));
end
sc = max(1, max(abs(om.x), [], 2));
c.e = max(abs(os.x - om.x), [], 2) ./ sc;
c.E = max(c.e);
c.tErr = max(abs(os.t - om.t));
n = size(om.u, 2);
m = max(n - 1, 1);
c.uErr = max(max(abs(os.u(:, 1:m) - om.u(:, 1:m))));
c.n = numel(om.t);
end
