function out = simulate(AC, env, x0, u0, varargin)
%SIMULATE  Run the generated Simulink model VitalPlant with the vital.sim.run
%   contract (docs/PLAN_M9.md, ADR-039). Normal mode; the plant and the controller
%   are evaluated in MATLAB through vital.slx.kernel (one physics source).
%
%   out = vital.slx.simulate(AC, env, x0, u0, 'dt', 0.01, 'tFinal', T, ...)
%   OPTIONS
%     'dt'          base step and ode4 FixedStep (s; default 0.01)
%     'tFinal'      final time (required; an integer number of steps)
%     'Inputs'      [], or piecewise-constant specifications (vital.sim.doublet,
%                   vital.sim.stepInput, or a cell array of them), with the checks
%                   of vital.sim.run. Function handles: vital:slx:unsupportedInput.
%     'Controller'  as vital.sim.run (rate_hz, init, step); sampled by the FCS block
%                   at Ts = 1/rate_hz under ADR-026
%     'Guards'      struct with at most quatNormTol (default 1e-6; [] disables)
%     'Model'       the .slx to run (default vital.slx.modelFile())
%   x0 has 13 elements (flat-Earth [v_b; w_b; q; p_n]), u0 4 ([de da dr throttle]).
%
%   OUTPUT: t, x, u, y (V alpha beta h phi theta psi p q r quatNorm nz, recomputed
%   from the logged x and u with vital.plant.derivatives), status, stopReason,
%   stopTime, stopDetail, controller (present, rate_hz, nHold, nCalls, tSample,
%   state), dt, tFinal, nSteps, wallTime_s, slx (file, solver, fixedStep,
%   stopTime, simWall_s).
%   STOPS (status STOPPED, never exceptions): vital:sim:quatNorm (|q| guard on a
%   logged sample; log truncated there), vital:sim:nanState and
%   vital:sim:controllerError (at the controller sample t_k, which is logged with
%   the command applied up to t_k, as vital.sim.run), vital:sim:plantError,
%   vital:slx:simulinkError (other Simulink errors; the log holds the samples
%   Simulink returned).
%   ERRORS: vital:sim:badStep, vital:sim:inputNotPiecewiseConstant, vital:badInput,
%   vital:slx:unsupportedInput, vital:slx:modelMissing.
wall = tic;
opts = parseOptions(varargin);
[dt, N] = checkStep(opts.dt, opts.tFinal);
if ~(isnumeric(x0) && isreal(x0) && numel(x0) == 13 && all(isfinite(x0(:))))
    error('vital:badInput', 'x0 must be 13 finite real values [v_b; w_b; q; p_n].');
end
if ~(isnumeric(u0) && isreal(u0) && numel(u0) == 4 && all(isfinite(u0(:))))
    error('vital:badInput', 'u0 must be 4 finite real values [de; da; dr; throttle].');
end
x0 = double(x0(:)); u0 = double(u0(:)); nu = 4;
pw = prepareInputs(opts.Inputs, AC, nu, dt, N);
ctrl = prepareController(opts.Controller, dt);
qtol = guardOptions(opts.Guards);
file = opts.Model;
if isempty(file), file = vital.slx.modelFile(); end
if ~isfile(file)
    error('vital:slx:modelMissing', 'Simulink model not found: %s (generate it with vital.slx.build).', file);
end
[~, name] = fileparts(file);

% ---- context for the kernel ----------------------------------------------------------
c.AC = AC; c.env = env; c.u0 = u0; c.nu = nu; c.dt = dt; c.N = N; c.pw = pw; c.ctrl = ctrl;
c.uHeld = u0 + inputAt(pw, nu, dt, 0);               % u_ref(0) (ADR-026)
c.uLeftFinal = u0 + inputAt(pw, nu, dt, (N - 1) * dt);  % command of the last step
c.cstate = [];
if ctrl.present && isa(ctrl.init, 'function_handle'), c.cstate = ctrl.init(x0, u0);
elseif ctrl.present, c.cstate = ctrl.init;
end
c.nCalls = 0; c.tSample = zeros(1, 0); c.stop = [];
if ctrl.present, Ts = ctrl.nHold * dt; else, Ts = dt; end
vital.slx.context('set', c);
clr = onCleanup(@() vital.slx.context('clear'));

% ---- run -------------------------------------------------------------------------
cache = fullfile(tempdir, 'vital_slx_cache');
if ~isfolder(cache), mkdir(cache); end
oldCfg = Simulink.fileGenControl('getConfig');
Simulink.fileGenControl('set', 'CacheFolder', cache, 'CodeGenFolder', cache);
restoreCfg = onCleanup(@() Simulink.fileGenControl('setConfig', 'config', oldCfg));
if bdIsLoaded(name) && ~strcmpi(get_param(name, 'FileName'), file)
    close_system(name, 0);
end
if ~bdIsLoaded(name), load_system(file); end
in = Simulink.SimulationInput(name);
in = in.setVariable('x0', x0);
in = in.setVariable('dt', dt);
in = in.setVariable('Ts', Ts);
in = in.setModelParameter('StopTime', sprintf('%.17g', N * dt), 'SimulationMode', 'normal', 'CaptureErrors', 'on');
simErr = [];
ts = tic;
so = sim(in, 'ShowProgress', 'off');
simWall = toc(ts);
if ~isempty(so.ErrorMessage)
    simErr = so.ErrorMessage;
end
c = vital.slx.context('get');

% ---- logs ----------------------------------------------------------------------------
[T, X, U] = readLogs(so);
status = 'COMPLETED'; reason = ''; detail = emptyDetail();
if ~isempty(simErr)
    status = 'STOPPED';
    if ~isempty(c.stop)
        s = c.stop;
        keep = T < s.t - dt / 2;
        T = [T(keep), s.t]; X = [X(:, keep), s.x]; U = [U(:, keep), s.u];
        reason = s.reason;
        detail.identifier = s.identifier; detail.message = s.message; detail.time = s.t;
        detail.stage = 'controller sample';
    else
        if contains(simErr, {'vital:plant:nonFinite', 'vital:sim:nanState', 'not finite'})
            reason = 'vital:sim:nanState';
        else
            reason = 'vital:slx:simulinkError';
        end
        detail.identifier = reason; detail.message = simErr; detail.stage = 'simulink';
        if ~isempty(T), detail.time = T(end); end
    end
end
Y = outputs(X, U, AC, env);
% |q| guard (FC-601) on every logged sample; first violation truncates the log
if ~isempty(qtol) && ~isempty(T)
    bad = find(~(abs(Y.quatNorm - 1) <= qtol), 1);
    if ~isempty(bad)
        n = bad;
        T = T(1:n); X = X(:, 1:n); U = U(:, 1:n);
        Y = structfun(@(v) v(:, 1:n), Y, 'UniformOutput', false);
        status = 'STOPPED'; reason = 'vital:sim:quatNorm';
        detail = emptyDetail(); detail.identifier = reason; detail.time = T(n); detail.stage = 'guard';
        detail.field = 'quatNorm'; detail.value = Y.quatNorm(n); detail.limit = qtol;
        detail.message = sprintf('|q| - 1 = %.3g exceeds %.3g at t = %.6g s', Y.quatNorm(n) - 1, qtol, T(n));
    end
end
out.t = T; out.x = X; out.u = U; out.y = Y;
out.status = status;
out.stopReason = reason;
if isempty(T), out.stopTime = NaN; else, out.stopTime = T(end); end
out.stopDetail = detail;
nc = c.nCalls; tsamp = c.tSample;
if ~isempty(T), keepS = tsamp < T(end) - dt / 2 | strcmp(status, 'COMPLETED'); else, keepS = false(size(tsamp)); end
if strcmp(status, 'STOPPED'), nc = nnz(keepS); tsamp = tsamp(keepS); end
out.controller = struct('present', ctrl.present, 'rate_hz', ctrl.rate_hz, 'nHold', ctrl.nHold, ...
    'nCalls', nc, 'tSample', tsamp, 'state', c.cstate);
out.dt = dt;
out.tFinal = N * dt;
out.nSteps = numel(T) - 1;
out.slx = struct('file', file, 'solver', '', 'fixedStep', NaN, 'stopTime', NaN, 'simWall_s', simWall);
try
    si = so.SimulationMetadata.ModelInfo.SolverInfo;
    out.slx.solver = si.Solver;
    out.slx.fixedStep = si.FixedStepSize;
    out.slx.stopTime = so.SimulationMetadata.ModelInfo.StopTime;
catch
    out.slx.solver = get_param(name, 'Solver');
end
out.wallTime_s = toc(wall);
end

% =====================================================================================
function [T, X, U] = readLogs(so)
T = zeros(1, 0); X = zeros(13, 0); U = zeros(4, 0);
try
    yo = so.get('yout');
    tt = so.get('tout');
catch
    return
end
if isempty(yo) || isempty(tt), return; end
T = double(tt(:)');
X = toCols(yo.signals(1).values, 13, numel(T));
U = toCols(yo.signals(2).values, 4, numel(T));
end

function M = toCols(v, m, n)
v = double(v);
if ndims(v) == 3
    M = reshape(v, m, n);
elseif size(v, 1) == n && size(v, 2) == m
    M = v.';
else
    M = reshape(v, m, n);
end
end

function Y = outputs(X, U, AC, env)
f = {'V', 'alpha', 'beta', 'h', 'phi', 'theta', 'psi', 'p', 'q', 'r', 'quatNorm', 'nz'};
n = size(X, 2);
for i = 1:numel(f), Y.(f{i}) = nan(1, n); end
for k = 1:n
    try
        [~, y] = vital.plant.derivatives(X(:, k), U(:, k), AC, env);
    catch
        continue
    end
    for i = 1:numel(f), Y.(f{i})(k) = y.(f{i}); end
end
end

function du = inputAt(pw, nu, dt, tk)
du = zeros(nu, 1);
for s = 1:numel(pw)
    du(pw(s).ch) = du(pw(s).ch) + pw(s).fcn(tk + dt / 2);
end
end

function d = emptyDetail()
d = struct('identifier', '', 'message', '', 'time', NaN, 'stage', '', 'field', '', 'value', NaN, 'limit', []);
end

function opts = parseOptions(args)
names = {'dt', 'tFinal', 'Inputs', 'Controller', 'Guards', 'Model'};
opts = struct('dt', 0.01, 'tFinal', [], 'Inputs', [], 'Controller', [], 'Guards', struct(), 'Model', '');
if mod(numel(args), 2) ~= 0
    error('vital:badInput', 'options must be name-value pairs.');
end
for i = 1:2:numel(args)
    nm = args{i};
    if isstring(nm) && isscalar(nm), nm = char(nm); end
    if ischar(nm) && strcmpi(nm, 'Plant')
        error('vital:slx:unsupportedInput', 'the Simulink path runs vital.plant.derivatives only (no Plant option).');
    end
    hit = find(strcmpi(nm, names), 1);
    if ~ischar(nm) || isempty(hit)
        error('vital:badInput', 'unknown option. Valid options: %s.', strjoin(names, ', '));
    end
    opts.(names{hit}) = args{i+1};
end
end

function tol = guardOptions(G)
tol = 1e-6;
if isempty(G), return; end
if ~isstruct(G) || ~isscalar(G)
    error('vital:badInput', 'Guards must be a struct.');
end
f = fieldnames(G);
bad = setdiff(f, {'quatNormTol'});
if ~isempty(bad)
    error('vital:badInput', 'the Simulink path supports only Guards.quatNormTol (got %s).', strjoin(bad, ', '));
end
if isfield(G, 'quatNormTol')
    tol = G.quatNormTol;
    if ~isempty(tol) && ~(isnumeric(tol) && isscalar(tol) && tol > 0)
        error('vital:badInput', 'Guards.quatNormTol must be a positive scalar or [].');
    end
end
end

% ---- the vital.sim.run checks, restated (they are local functions of run.m) ---------
function [dt, N] = checkStep(dt, tFinal)
if ~(isnumeric(dt) && isscalar(dt) && isreal(dt) && isfinite(dt) && dt > 0)
    error('vital:sim:badStep', 'dt must be a finite positive scalar (s).');
end
if isempty(tFinal)
    error('vital:sim:badStep', 'tFinal is required.');
end
if ~(isnumeric(tFinal) && isscalar(tFinal) && isreal(tFinal) && isfinite(tFinal) && tFinal > 0)
    error('vital:sim:badStep', 'tFinal must be a finite positive scalar (s).');
end
dt = double(dt); Nf = double(tFinal) / dt; N = round(Nf);
if N < 1 || abs(Nf - N) > 1e-6
    error('vital:sim:badStep', 'tFinal = %g s is not an integer number of steps of dt = %g s (tFinal/dt = %.9g).', tFinal, dt, Nf);
end
end

function pw = prepareInputs(spec, AC, nu, dt, N)
pw = struct('ch', {}, 'fcn', {});
if isempty(spec), return; end
if ~iscell(spec), spec = {spec}; end
for i = 1:numel(spec)
    s = spec{i};
    if isa(s, 'function_handle')
        error('vital:slx:unsupportedInput', ['smooth function-handle inputs are not supported by the Simulink ' ...
            'path; use piecewise-constant specifications (vital.sim.doublet, vital.sim.stepInput).']);
    elseif isstruct(s)
        for j = 1:numel(s)
            e = s(j);
            if ~all(isfield(e, {'channel', 'fcn', 'breakpoints'})) || ~isa(e.fcn, 'function_handle')
                error('vital:badInput', 'an input specification needs fields channel, fcn (handle) and breakpoints.');
            end
            b = double(e.breakpoints(:));
            if any(~isfinite(b))
                error('vital:badInput', 'input breakpoints must be finite.');
            end
            r = b / dt;
            bad = abs(r - round(r)) > 1e-6;
            if any(bad)
                error('vital:sim:badStep', 'input switch at t = %.9g s is not on a step boundary (dt = %g s).', b(find(bad, 1)), dt);
            end
            checkPiecewiseConstant(e.fcn, dt, N);
            pw(end+1) = struct('ch', resolveChannel(e.channel, AC, nu), 'fcn', e.fcn); %#ok<AGROW>
        end
    else
        error('vital:badInput', 'Inputs must be [], an input specification or a cell array of them.');
    end
end
end

function checkPiecewiseConstant(fcn, dt, N)
tt = ((0:N-1) * dt) + dt * [1/4; 1/2; 3/4];
try
    v = fcn(tt);
    if ~isequal(size(v), size(tt)), error('vital:sim:notVectorised', ''); end
catch
    v = arrayfun(@(t) double(fcn(t)), tt);
end
v = double(v);
if any(~isfinite(v(:))) || ~isreal(v)
    error('vital:badInput', 'piecewise input fcn must return finite real values.');
end
bad = find(v(1, :) ~= v(2, :) | v(2, :) ~= v(3, :), 1);
if ~isempty(bad)
    error('vital:sim:inputNotPiecewiseConstant', 'piecewise input varies inside the step from t = %.6g s.', (bad - 1) * dt);
end
end

function idx = resolveChannel(ch, AC, nu)
if isstring(ch) && isscalar(ch), ch = char(ch); end
if isnumeric(ch)
    if ~(isscalar(ch) && ch >= 1 && ch <= nu && ch == round(ch))
        error('vital:badInput', 'input channel %s is not an index in 1..%d.', mat2str(ch), nu);
    end
    idx = double(ch); return
end
alias = struct('elevator', 'de', 'aileron', 'da', 'rudder', 'dr');
name = ch;
if isfield(alias, lower(name)), name = alias.(lower(name)); end
names = {};
if isstruct(AC) && isfield(AC, 'controlNames'), names = cellstr(AC.controlNames); end
idx = find(strcmpi(name, names), 1);
if isempty(idx) || idx > nu
    error('vital:badInput', 'input channel ''%s'' is not a control of this aircraft.', ch);
end
end

function c = prepareController(spec, dt)
c = struct('present', false, 'rate_hz', NaN, 'nHold', 0, 'init', [], 'step', []);
if isempty(spec), return; end
if ~(isstruct(spec) && isscalar(spec) && all(isfield(spec, {'rate_hz', 'init', 'step'})))
    error('vital:badInput', 'Controller must be a struct with fields rate_hz, init and step.');
end
if ~isa(spec.step, 'function_handle')
    error('vital:badInput', 'Controller.step must be a function handle.');
end
hz = spec.rate_hz;
if ~(isnumeric(hz) && isscalar(hz) && isreal(hz) && isfinite(hz) && hz > 0)
    error('vital:sim:badStep', 'Controller.rate_hz must be a finite positive scalar.');
end
ratio = 1 / (double(hz) * dt);
nHold = round(ratio);
if nHold < 1 || abs(ratio - nHold) > 1e-9 * nHold
    error('vital:sim:badStep', 'controller rate %g Hz with dt = %g s gives %.9g steps per sample; it must be a positive integer.', hz, dt, ratio);
end
c = struct('present', true, 'rate_hz', double(hz), 'nHold', nHold, 'init', spec.init, 'step', spec.step);
end
