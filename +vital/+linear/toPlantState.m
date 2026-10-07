function x = toPlantState(lin, dx)
%TOPLANTSTATE  13-state plant state at x_lin = lin.x0 + dx.
%   x = vital.linear.toPlantState(lin, dx)
%     lin  a vital.linear.linearize result (uses lin.x0, 12 x 1)
%     dx   deviation of x_lin = [u v w p q r phi theta psi pN pE h] (12 x 1; SI, rad)
%     x    [v_b; w_b; q; p_n] for vital.plant.derivatives and vital.sim.run:
%          v_b = [u v w], w_b = [p q r], q = vital.frames.eul2quat(phi, theta, psi),
%          p_n = [pN; pE; -h] (NED, so the down position is -h)
%   The inverse is vital.linear.fromPlantState. Errors: vital:badInput.
arguments
    lin (1,1) struct
    dx double
end
if ~isfield(lin, 'x0') || numel(lin.x0) ~= 12
    error('vital:badInput', 'lin.x0 must have 12 elements.');
end
if numel(dx) ~= 12, error('vital:badInput', 'dx must have 12 elements, got %d.', numel(dx)); end
vital.validate.finite(dx, 'dx');
z = lin.x0(:) + dx(:);
x = [z(1:6); vital.frames.eul2quat(z(7), z(8), z(9)); z(10); z(11); -z(12)];
end
