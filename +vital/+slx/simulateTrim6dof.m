function out = simulateTrim6dof(P, opts)
%SIMULATETRIM6DOF  Run models/F16Trim6DOF.slx (Aerospace Blockset 6DOF) from P.
%   out = vital.slx.simulateTrim6dof(P)                      P = vital.slx.trim6dofSetup(...)
%   out = vital.slx.simulateTrim6dof(P, 'tFinal', 10, 'dt', 0.01, ...
%            'Inputs', vital.sim.doublet(1, 0.5, deg2rad(1), 'elevator'), ...
%            'NoWeight', false, 'Model', file)
%   'Inputs'  piecewise-constant perturbations du added to P.u_trim (the
%             vital.sim.doublet / stepInput specifications, channels by name or
%             index; switch times on step boundaries). Held over each step, as
%             vital.sim.run does (value of the piece that contains the step).
%   'NoWeight' true drops the weight block's force (a vacuity check only).
%   out: t (1 x N+1), sl (the SIMULINK flight-test signals logged by the model,
%   To Workspace 'sim6dof': V alpha beta mach qbar h hdot phi theta psi p q r xN xE
%   de da dr throttle Fx Fy Fz L M N, SI and rad), log (that raw log, for
%   vital.slx.plotTrim6dof), x (13 x N+1, VITAL layout [v_b; w_b; q; p_n] from the
%   6DOF block's states), y (VITAL's air data from the loads block, for tests),
%   F_total, M_total (3 x N+1, at the CG, body axes), u (4 x N+1), status,
%   wallTime_s, model.
%   The parameters reach the model as the base-workspace variable P6dof.
arguments
    P (1,1) struct
    opts.tFinal (1,1) double {mustBePositive} = P.tFinal
    opts.dt (1,1) double {mustBePositive} = P.dt
    opts.Inputs = []
    opts.NoWeight (1,1) logical = false
    opts.Model (1,:) char = ''
end
if isempty(opts.Model), opts.Model = P.model; end
if ~isfile(opts.Model)
    error('vital:slx:noModel', 'model %s not found; build it with vital.slx.buildTrim6dof.', opts.Model);
end
N = round(opts.tFinal / opts.dt);
if abs(N * opts.dt - opts.tFinal) > 1e-6 * opts.dt
    error('vital:sim:badStep', 'tFinal / dt must be an integer.');
end
P.dt = opts.dt;
P.tFinal = N * opts.dt;
P.weightOn = double(~opts.NoWeight);
P.plot = false;   % programmatic runs: the caller plots (vital.slx.plotTrim6dof)
tk = (0:N) * opts.dt;
du = zeros(4, N + 1);
spec = opts.Inputs;
if ~isempty(spec)
    if ~iscell(spec), spec = {spec}; end
    for i = 1:numel(spec)
        for e = spec{i}(:).'
            b = double(e.breakpoints(:)) / opts.dt;
            if any(abs(b - round(b)) > 1e-6)
                error('vital:sim:badStep', 'input switch times must be on step boundaries.');
            end
            k = channelIndex(e.channel, P.AC);
            du(k, :) = du(k, :) + arrayfun(@(t) double(e.fcn(t)), tk + opts.dt / 2);
        end
    end
end
P.du = [tk.', du.'];
assignin('base', 'P6dof', P);
vital.slx.f16LoadsCg('setup', P);
[~, name] = fileparts(opts.Model);
if ~bdIsLoaded(name), load_system(opts.Model); end
t0 = tic;
so = sim(name, 'ReturnWorkspaceOutputs', 'on');
out.wallTime_s = toc(t0);
out.model = opts.Model;
out.t = so.tout(:).';
sig = so.yout.signals;
g = @(k) columns(sig(k).values, numel(so.tout));
Vb = g(1); w = g(2); Xe = g(4); eul = g(5);
out.F_total = g(6); out.M_total = g(7); air = g(8); out.u = g(9); q = g(10);
out.x = [Vb; w; q; Xe];
out.log = so.sim6dof;
out.sl = vital.slx.plotTrim6dof(out.log);
out.y = struct('V', air(1, :), 'alpha', air(2, :), 'beta', air(3, :), 'mach', air(4, :), ...
    'qbar', air(5, :), 'h', air(6, :), 'phi', eul(1, :), 'theta', eul(2, :), 'psi', eul(3, :), ...
    'p', w(1, :), 'q', w(2, :), 'r', w(3, :), 'xN', Xe(1, :), 'xE', Xe(2, :));
if numel(out.t) == N + 1 && abs(out.t(end) - P.tFinal) < 1e-9
    out.status = 'COMPLETED';
else
    out.status = 'INCOMPLETE';
end
end

function v = columns(v, n)
% logged values -> one column per sample: N x w (1-D signals) or w x 1 x N / 3 x 3 x N
if ndims(v) == 3
    v = reshape(v, [], n);
else
    v = v.';
end
end

function k = channelIndex(ch, AC)
if isnumeric(ch), k = ch; return; end
alias = struct('elevator', 'de', 'aileron', 'da', 'rudder', 'dr');
ch = char(ch);
if isfield(alias, lower(ch)), ch = alias.(lower(ch)); end
k = find(strcmpi(ch, AC.controlNames), 1);
if isempty(k)
    error('vital:badInput', 'input channel ''%s'' is not a control of this aircraft.', ch);
end
end
