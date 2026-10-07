function dx = fromPlantState(lin, X)
%FROMPLANTSTATE  Deviations dx = x_lin - lin.x0 of 13-state plant states.
%   dx = vital.linear.fromPlantState(lin, X)
%     lin  a vital.linear.linearize result (uses lin.x0)
%     X    13 x n plant states [v_b; w_b; q; p_n] (e.g. vital.sim.run out.x)
%     dx   12 x n: [u v w p q r phi theta psi pN pE h] - lin.x0, with the Euler
%          angles from vital.frames.dcm2eul (3-2-1, CONVENTIONS 3), h = -p_n(3),
%          and the angle deviations wrapped to (-pi, pi]. The quaternion is
%          normalized first, as vital.plant.derivatives does (an integrated
%          quaternion drifts from unit norm by ~1e-10; M5-B NOTES 1)
%   Inverse of vital.linear.toPlantState. Errors: vital:badInput.
arguments
    lin (1,1) struct
    X double
end
if ~isfield(lin, 'x0') || numel(lin.x0) ~= 12
    error('vital:badInput', 'lin.x0 must have 12 elements.');
end
if size(X, 1) ~= 13
    error('vital:badInput', 'X must have 13 rows (plant states), got %d.', size(X, 1));
end
vital.validate.finite(X, 'X');
n = size(X, 2);
dx = zeros(12, n);
x0 = lin.x0(:);
for k = 1:n
    q = X(7:10, k); nq = norm(q);
    if nq == 0, error('vital:badInput', 'zero quaternion in sample %d.', k); end
    e = vital.frames.dcm2eul(vital.frames.quat2dcm(q / nq));
    dx(:, k) = [X(1:6, k); e; X(11, k); X(12, k); -X(13, k)] - x0;
end
dx(7:9, :) = -mod(-dx(7:9, :) + pi, 2 * pi) + pi;      % wrap to (-pi, pi]
end
