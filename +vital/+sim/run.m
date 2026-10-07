function out = run(AC, env, x0, u0, varargin)
%RUN  Fixed-step RK4 time simulation with inputs, a discrete controller,
%   logging and guards (CONVENTIONS 10; docs/PLAN_M5_M8.md "M5-B sim").
%
%   out = vital.sim.run(AC, env, x0, u0, 'dt', 0.01, 'tFinal', T, ...)
%   out = vital.sim.run(..., 'Inputs', f, 'Controller', c, 'Plant', p, 'Guards', g)
%
%   AC, env  passed unchanged to the plant (for the default plant: an aircraft
%            configuration such as vital.aircraft.f16.config, and the struct
%            env with fields g, wind_n, deltaT)
%   x0       initial state, any length (the driver never assumes a layout;
%            13 states [v_b; w_b; q; p_n] only for the default plant)
%   u0       reference controls, any length nu = numel(u0) (4 = [de da dr
%            throttle] for the F-16); may be empty for a plant without controls
%
%   OPTIONS
%   'dt'       base step (s; finite, > 0; default 0.01)
%   'tFinal'   final time (s; required). tFinal/dt must be within 1e-6 of a
%              positive integer N; the run then ends exactly at t = N*dt.
%              Times are t_k = k*dt (never accumulated).
%   'Plant'    [xdot, y] = p(x, u, AC, env), default @vital.plant.derivatives.
%              xdot must have numel(x) elements; y is a struct of diagnostics.
%              Guards and logs use y fields only (layout-agnostic), so a
%              plant with another state layout (e.g. the M5-C rotating-Earth
%              plant) opts into a guard by providing its y field.
%   'Inputs'   additive control perturbation du, u = u0 + du:
%              - a function handle du = f(t) returning nu values: taken as
%                SMOOTH and evaluated at the RK4 stage times t_k, t_k+dt/2,
%                t_k+dt (4th order is kept; tSimCore rk4OrderSmoothInputThroughRun);
%              - an input specification from vital.sim.doublet / vital.sim.stepInput
%                (or any struct with fields channel, fcn (scalar du(t)) and
%                breakpoints): piecewise constant: fcn must be constant inside
%                every step (checked at t_k + dt/4, dt/2, 3dt/4 before the run;
%                vital:sim:inputNotPiecewiseConstant otherwise). Every breakpoint must be a
%                multiple of dt (within 1e-6 dt), else vital:sim:badStep. The
%                value used for ALL stages of step [t_k, t_k+dt] is fcn(t_k + dt/2),
%                the value of the piece that contains the step: stage 1 sees the
%                right limit at t_k, stage 4 the left limit at t_k+dt, so no
%                stage straddles a switch (tSimCore doubletAndStepSwitchOnStepBoundaries);
%              - a cell array of the above (summed); [] = none (default).
%   'Controller'  struct with fields
%              rate_hz  sample rate; nHold = 1/(rate_hz*dt) must be a positive
%                       integer within 1e-9 (i.e. rate_hz divides 1/dt and is not
%                       faster than the base step), else vital:sim:badStep
%              init     initial controller state (any value), or a function
%                       handle state0 = init(x0, u0)
%              step     [u, state] = step(t, x, y, u_ref, state)
%              The controller is sampled at t_k with mod(k, nHold) == 0, k < N,
%              through vital.sim.sampleController. u_ref = u0 + du(t_k) (right
%              limit of the inputs). ADR-026: y is the plant output at
%              (x_k, u_applied), u_applied = the command held over the step that
%              ENDS at t_k (at k = 0: u_ref(0) = u0 + du(0)); a sensor sampled
%              just before the ZOH update, causal, no algebraic loop. (ADR-021
%              used y(x_k, u_ref); superseded.) The returned u (nu values;
%              vital:badInput otherwise) is held (zero-order hold) across every
%              RK4 stage until the next sample. With a controller, inputs reach
%              the plant only through u_ref at the samples. A controller that
%              raises is a STOP vital:sim:controllerError (identifier and message
%              in out.stopDetail); a non-finite output is a STOP vital:sim:nanState.
%              Either stop is at t_k and logs x_k, the command applied up to t_k
%              and the y the controller saw.
%   'Guards'   struct; any subset of
%              quatNormTol  | |q| - 1 | limit on y.quatNorm (default 1e-6;
%                           [] disables)                     -> vital:sim:quatNorm (FC-601)
%              envelope     struct of y fields -> [lo hi] in the field's own
%                           (SI) units, e.g. struct('alpha', deg2rad([-10 45])).
%                           Default: alpha, beta from AC.limits.alpha_deg /
%                           beta_deg where present. Given, it REPLACES the
%                           default; struct() disables.   -> vital:sim:envelope (FC-602)
%              hMin         stop when y.h < hMin (m; default 0; [] disables)
%                                                         -> vital:sim:ground
%              stopOnOutOfEnvelope  stop when y.outOfEnvelope (clamped tables)
%                           is true (default false: recorded, not stopped;
%                           NESC case 12 runs the clamped tables)
%                                                         -> vital:sim:outOfEnvelope
%              stopOnControlLimit  stop when a command leaves its limit
%                           (default false: recorded in out.controlLimit, never
%                           clipped)                      -> vital:sim:controlLimit
%              controlLimits  struct of control name -> [lo hi] (SI) replacing
%                           the default vital.sim.controlLimits(AC) (AC.limits
%                           <name>_deg or <name>); struct() disables. Checked on
%                           every stage command of each step (y.u_applied instead
%                           when the plant reports it); NaN trips.
%              Unknown fields are an error (vital:badInput). A guard whose y
%              field is absent from the plant output is DISABLED and listed as
%              such in out.guards (never silently assumed). A NaN guard value
%              trips its guard.
%   'LogFields'  cellstr of y fields to log (default: every real numeric or
%              logical field of the first plant output)
%
%   STEP, LOG AND STOP SEMANTICS
%   Each step [t_k, t_k+dt] is classical RK4 (vital.sim.rk4Step) on the
%   continuous plant. Sample k logs x_k, the command applied at stage 1 of
%   the step from t_k, and y from that same stage-1 evaluation (so logging
%   costs no extra plant call). The final sample t_N logs the command of the
%   last stage of the last step (the left limit) and its plant output.
%   Guards are checked on every logged sample, t = 0 included: a guard that
%   fires at t_k stops the run with stopTime = t_k, the last logged sample.
%   A step whose stage state or derivative is not finite, or whose plant call
%   raises, is REJECTED: stopTime = t_k (the last accepted, finite state).
%     vital:sim:nanState    non-finite state or derivative (FC-302); includes
%                           vital:plant:nonFinite raised by the plant
%     vital:sim:plantError  any other plant error; identifier and message kept
%                           in out.stopDetail
%   If the stage-1 evaluation at the stop sample itself failed, that
%   sample's y is NaN. These stops are never exceptions.
%
%   OUTPUT out
%     t (1 x n), x (nx x n), u (nu x n), y (struct; each field m x n, one
%     column per sample), status 'COMPLETED' | 'STOPPED', stopReason ('' when
%     completed, else one of the identifiers above), stopTime (= t(end)),
%     stopDetail (identifier, message, time, stage, field, value, limit),
%     guards (struct array: name, field, limit, active, note), outOfEnvelope
%     (monitored, ever, firstTime), controlLimit (monitored, source, ever,
%     firstTime, channel, value, limit, note), controller (present, rate_hz, nHold,
%     nCalls, tSample, state), dt, tFinal, nSteps, nPlantCalls, wallTime_s, plant.
%
%   ERRORS (exceptions): vital:sim:badStep (bad dt, tFinal, input switch time
%   or controller rate; FC-301); vital:sim:inputNotPiecewiseConstant (a struct
%   input that varies inside a step); vital:badInput (bad x0/u0, bad options,
%   a controller output of the wrong size, or the first plant evaluation
%   rejects x0/u0).
%
%   Example (NESC README trim, 1 deg elevator doublet):
%     r = vital.aircraft.f16.trimLevel(565.6854, 10013);
%     AC = vital.aircraft.f16.config(); env = struct('g', 32.174*0.3048, 'wind_n', [0;0;0], 'deltaT', 0);
%     out = vital.sim.run(AC, env, r.trim.x, r.trim.u, 'dt', 0.01, 'tFinal', 5, ...
%         'Inputs', vital.sim.doublet(1, 0.5, deg2rad(1), 'elevator'));
wall = tic;
opts = parseOptions(varargin);
[dt, N] = checkStep(opts.dt, opts.tFinal);
checkVector(x0, 'x0', false);
checkVector(u0, 'u0', true);
if ~isa(opts.Plant, 'function_handle')
    error('vital:badInput', 'Plant must be a function handle [xdot, y] = p(x, u, AC, env).');
end
plant = opts.Plant;
x = double(x0(:)); u0 = double(u0(:));
nx = numel(x); nu = numel(u0);
[smooth, pw] = prepareInputs(opts.Inputs, AC, nu, dt, N);
ctrl = prepareController(opts.Controller, dt);
gopt = prepareGuardOptions(opts.Guards, AC);

T = (0:N) * dt;
X = nan(nx, N + 1); U = nan(nu, N + 1);
Y = struct(); logNames = {};
guards = [];
cstate = [];
if ctrl.present
    if isa(ctrl.init, 'function_handle'), cstate = ctrl.init(x, u0); else, cstate = ctrl.init; end
end
uHeld = u0; nCalls = 0; tSample = nan(1, ctrl.present * ceil(N / max(ctrl.nHold, 1)));
tk = 0; nPlant = 0; firstEval = true;
uLeft = u0 + inputAt(0, 0);         % u_applied before the first step: u_ref(0) (ADR-026)
uStage = repmat(uLeft, 1, 3);
oobFirst = NaN; oobMonitored = false;
cl = struct('monitored', false, 'source', '', 'ever', false, 'firstTime', NaN, 'channel', '', ...
    'value', NaN, 'limit', [], 'note', 'not evaluated: no plant output was obtained');
clLim = [];
status = 'COMPLETED'; reason = ''; detail = emptyDetail();
kStop = N;
rhs = @stageRhs;

for k = 0:N
    tk = T(k + 1);
    % ---- discrete controller sample (zero-order held until the next one) ------
    % ADR-026: the controller measures y(x_k, u_applied), u_applied = the command
    % held over the step that ends at t_k (u_ref(0) at k = 0).
    if ctrl.present && k < N && mod(k, ctrl.nHold) == 0
        uref = u0 + inputAt(tk, tk);
        X(:, k+1) = x; U(:, k+1) = uLeft;
        try
            [~, yc] = plant(x, uLeft, AC, env);
            nPlant = nPlant + 1; firstEval = false;
        catch err
            [reason, detail] = classifyError(err, tk, 'controller sample');
            kStop = k; status = 'STOPPED'; break
        end
        [uc, cnew, cstop] = vital.sim.sampleController(ctrl, tk, x, yc, uref, cstate, nu);
        if ~isempty(cstop)
            logSample(yc, k);
            reason = cstop.reason;
            detail = emptyDetail(); detail.identifier = cstop.identifier; detail.message = cstop.message;
            detail.time = tk; detail.stage = 'controller sample';
            kStop = k; status = 'STOPPED'; break
        end
        cstate = cnew;
        nCalls = nCalls + 1; tSample(nCalls) = tk;
        uHeld = uc;
    end
    % ---- commands for the stages of this step: [stage 1, stages 2-3, stage 4] --
    if k < N
        if ctrl.present
            uStage = repmat(uHeld, 1, 3);
        else
            uStage = u0 + [inputAt(tk, tk), inputAt(tk + dt/2, tk), inputAt(tk + dt, tk)];
        end
        u1 = uStage(:, 1);
    else
        u1 = uLeft;
    end
    % ---- sample k: stage-1 evaluation, log, guards ------------------------------
    X(:, k+1) = x; U(:, k+1) = u1;
    try
        [k1, y] = plant(x, u1, AC, env);
        nPlant = nPlant + 1; firstEval = false;
    catch err
        [reason, detail] = classifyError(err, tk, 'stage 1');
        kStop = k; status = 'STOPPED'; break
    end
    k1 = k1(:);
    if ~logSample(y, k), kStop = k; break; end
    if numel(k1) ~= nx || any(~isfinite(k1))
        reason = 'vital:sim:nanState';
        detail = emptyDetail(); detail.identifier = reason; detail.time = tk; detail.stage = 'stage 1';
        detail.message = sprintf('state derivative at t = %.6g s is not finite (or has %d elements, expected %d)', tk, numel(k1), nx);
        kStop = k; status = 'STOPPED'; break
    end
    if oobMonitored && y.outOfEnvelope && isnan(oobFirst), oobFirst = tk; end
    [reason, detail] = checkGuards(gopt, y, tk);
    if ~isempty(reason)
        kStop = k; status = 'STOPPED'; break
    end
    % ---- command limits (monitored, never clipped; R1 M6) ------------------------
    if cl.monitored
        if strcmp(cl.source, 'y.u_applied'), uc = double(y.u_applied(:));
        elseif k < N, uc = uStage;
        else, uc = u1;
        end
        bad = ~(uc >= clLim.lo & uc <= clLim.hi);
        if any(bad(:))
            [i, j] = find(bad, 1);
            if ~cl.ever
                cl.ever = true; cl.firstTime = tk; cl.channel = clLim.names{i};
                cl.value = uc(i, j); cl.limit = [clLim.lo(i) clLim.hi(i)];
            end
            if gopt.stopOnCL
                reason = 'vital:sim:controlLimit';
                detail = guardDetail(reason, tk, clLim.names{i}, uc(i, j), [clLim.lo(i) clLim.hi(i)], ...
                    sprintf('command %s outside AC.limits', clLim.names{i}));
                kStop = k; status = 'STOPPED'; break
            end
        end
    end
    if k == N, break; end
    % ---- stages 2-4 and the update ------------------------------------------------
    try
        xNew = vital.sim.rk4Step(rhs, tk, x, dt, k1);
    catch err
        [reason, detail] = classifyError(err, tk, 'stages 2-4');
        kStop = k; status = 'STOPPED'; break
    end
    if any(~isfinite(xNew))
        reason = 'vital:sim:nanState';
        detail = emptyDetail(); detail.identifier = reason; detail.time = tk; detail.stage = 'update';
        detail.message = sprintf('state after the step from t = %.6g s is not finite', tk);
        kStop = k; status = 'STOPPED'; break
    end
    uLeft = uStage(:, 3);
    x = xNew;
end

n = kStop + 1;
out.t = T(1:n);
out.x = X(:, 1:n);
out.u = U(:, 1:n);
for i = 1:numel(logNames)
    Y.(logNames{i}) = Y.(logNames{i})(:, 1:n);
end
out.y = Y;
out.status = status;
out.stopReason = reason;
out.stopTime = out.t(end);
out.stopDetail = detail;
if isempty(guards), guards = unevaluatedGuards(gopt); end
out.guards = guards;
out.outOfEnvelope = struct('monitored', oobMonitored, 'ever', ~isnan(oobFirst), 'firstTime', oobFirst);
out.controlLimit = cl;
out.controller = struct('present', ctrl.present, 'rate_hz', ctrl.rate_hz, 'nHold', ctrl.nHold, ...
    'nCalls', nCalls, 'tSample', tSample(1:nCalls), 'state', cstate);
out.dt = dt;
out.tFinal = N * dt;
out.nSteps = kStop;
out.nPlantCalls = nPlant;
out.wallTime_s = toc(wall);
out.plant = func2str(plant);

    % ---- nested helpers (share the loop state) -------------------------------------
    function ok = logSample(ys, kk)
        % First plant output: build the guard table, the command-limit monitor
        % and the log. Then store ys in column kk+1. A y field that disappears or
        % changes size stops the run (vital:sim:plantError).
        ok = true;
        if isempty(guards)
            [guards, gopt] = buildGuards(gopt, ys);
            oobMonitored = guards(strcmp({guards.name}, 'outOfEnvelope')).active;
            [Y, logNames] = initLog(ys, opts.LogFields, N + 1);
            [cl, clLim] = initControlLimits(gopt, AC, ys, nu);
            guards(end+1) = struct('name', 'controlLimit', 'field', cl.source, 'limit', [clLim.lo clLim.hi], ...
                'active', cl.monitored, 'note', cl.note);
        end
        for ii = 1:numel(logNames)
            f = logNames{ii};
            if ~isfield(ys, f) || numel(ys.(f)) ~= size(Y.(f), 1)
                reason = 'vital:sim:plantError';
                detail = emptyDetail(); detail.identifier = 'vital:sim:plantError'; detail.time = T(kk+1);
                detail.message = sprintf('plant output field y.%s disappeared or changed size', f);
                detail.stage = 'log'; detail.field = f;
                status = 'STOPPED'; ok = false; return
            end
            Y.(f)(:, kk+1) = double(ys.(f)(:));
        end
    end

    function xd = stageRhs(tau, xs)
        j = 1 + round(2 * (tau - tk) / dt);      % 1: t_k, 2: t_k + dt/2, 3: t_k + dt
        xd = plant(xs, uStage(:, j), AC, env);
        xd = xd(:);
        nPlant = nPlant + 1;
    end

    function du = inputAt(tau, tStep)
        % Smooth handles at the stage time tau; piecewise specifications at the
        % interior point of the step that starts at tStep.
        du = zeros(nu, 1);
        for s = 1:numel(smooth)
            v = smooth{s}(tau);
            if ~(isnumeric(v) && numel(v) == nu && isreal(v) && all(isfinite(v(:))))
                error('vital:badInput', 'input function must return %d finite real values at t = %g s.', nu, tau);
            end
            du = du + double(v(:));
        end
        tm = tStep + dt/2;
        for s = 1:numel(pw)
            du(pw(s).ch) = du(pw(s).ch) + pw(s).fcn(tm);
        end
    end

    function [r, d] = classifyError(err, t, stage)
        if firstEval && strcmp(err.identifier, 'vital:badInput')
            rethrow(err);                     % the plant rejects x0 / u0 themselves
        end
        if any(strcmp(err.identifier, {'vital:plant:nonFinite', 'vital:sim:nanState'}))
            r = 'vital:sim:nanState';
        else
            r = 'vital:sim:plantError';
        end
        d = emptyDetail();
        d.identifier = err.identifier; d.message = err.message; d.time = t; d.stage = stage;
    end
end

% =====================================================================================
function opts = parseOptions(args)
names = {'dt', 'tFinal', 'Inputs', 'Controller', 'Plant', 'Guards', 'LogFields'};
opts = struct('dt', 0.01, 'tFinal', [], 'Inputs', [], 'Controller', [], ...
    'Plant', @vital.plant.derivatives, 'Guards', struct(), 'LogFields', {{}});
if mod(numel(args), 2) ~= 0
    error('vital:badInput', 'options must be name-value pairs.');
end
for i = 1:2:numel(args)
    nm = args{i};
    if isstring(nm) && isscalar(nm), nm = char(nm); end
    hit = find(strcmpi(nm, names), 1);
    if ~ischar(nm) || isempty(hit)
        error('vital:badInput', 'unknown option. Valid options: %s.', strjoin(names, ', '));
    end
    opts.(names{hit}) = args{i+1};
end
end

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

function checkVector(v, name, allowEmpty)
ok = isnumeric(v) && isreal(v) && (isvector(v) || (allowEmpty && isempty(v)));
if ~ok || any(~isfinite(v(:)))
    error('vital:badInput', '%s must be a finite real numeric vector.', name);
end
end

function [smooth, pw] = prepareInputs(spec, AC, nu, dt, N)
smooth = {}; pw = struct('ch', {}, 'fcn', {});
if isempty(spec), return; end
if ~iscell(spec), spec = {spec}; end
for i = 1:numel(spec)
    s = spec{i};
    if isa(s, 'function_handle')
        smooth{end+1} = s; %#ok<AGROW>
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
                error('vital:sim:badStep', ['input switch at t = %.9g s is not on a step boundary (dt = %g s); ' ...
                    'switch times must be multiples of dt so that no RK4 stage straddles a switch.'], b(find(bad, 1)), dt);
            end
            checkPiecewiseConstant(e.fcn, dt, N);
            pw(end+1) = struct('ch', resolveChannel(e.channel, AC, nu), 'fcn', e.fcn); %#ok<AGROW>
        end
    else
        error('vital:badInput', 'Inputs must be [], a function handle du = f(t), an input specification or a cell array of these.');
    end
end
end

function checkPiecewiseConstant(fcn, dt, N)
% A piecewise specification is evaluated once per step (at t_k + dt/2), which is
% exact only if fcn is constant inside every step. Refuse anything else (R1
% MINOR 4): sample each step at t_k + dt/4, dt/2, 3dt/4 and require equality.
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
    error('vital:sim:inputNotPiecewiseConstant', ['piecewise input varies inside the step from t = %.6g s ' ...
        '(values %.9g, %.9g, %.9g); a struct input must be constant between its breakpoints. Pass a smooth ' ...
        'input as a function handle du = f(t) instead.'], (bad - 1) * dt, v(1, bad), v(2, bad), v(3, bad));
end
end

function [cl, lim] = initControlLimits(g, AC, y, nu)
% The surfaces the plant actually applies are checked: y.u_applied when the plant
% reports it (a plant that maps a command vector to surfaces), else the command.
if isfield(y, 'u_applied'), src = 'y.u_applied'; n = numel(y.u_applied); else, src = 'command'; n = nu; end
lim = vital.sim.controlLimits(AC, n);
note = lim.note;
if ~isempty(g.clOverride)
    names = lim.names;
    if isempty(names)
        lim.monitored = false;
        note = 'Guards.controlLimits given but AC.controlNames does not match the checked controls';
    else
        lim.lo(:) = -Inf; lim.hi(:) = Inf;
        for f = fieldnames(g.clOverride).'
            i = find(strcmp(f{1}, names), 1);
            if isempty(i)
                error('vital:badInput', 'Guards.controlLimits.%s is not a control (%s).', f{1}, strjoin(names, ', '));
            end
            v = g.clOverride.(f{1});
            lim.lo(i) = v(1); lim.hi(i) = v(2);
        end
        lim.monitored = any(isfinite([lim.lo; lim.hi]));
        if lim.monitored, note = ''; else, note = 'disabled by option (Guards.controlLimits = struct())'; end
    end
end
if lim.monitored
    if g.stopOnCL, note = 'active (stops: Guards.stopOnControlLimit)'; else, note = 'recorded, does not stop (Guards.stopOnControlLimit = false)'; end
end
cl = struct('monitored', lim.monitored, 'source', src, 'ever', false, 'firstTime', NaN, 'channel', '', ...
    'value', NaN, 'limit', [], 'note', note);
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
    error('vital:badInput', 'input channel ''%s'' is not a control of this aircraft (controls: %s).', ch, strjoin(names, ', '));
end
end

function c = prepareController(spec, dt)
c = struct('present', false, 'rate_hz', NaN, 'nHold', 0, 'init', [], 'step', []);
if isempty(spec), return; end
if ~(isstruct(spec) && isscalar(spec) && all(isfield(spec, {'rate_hz', 'init', 'step'})))
    error('vital:badInput', 'Controller must be a struct with fields rate_hz, init and step.');
end
if ~isa(spec.step, 'function_handle')
    error('vital:badInput', 'Controller.step must be a function handle [u, state] = step(t, x, y, u_ref, state).');
end
hz = spec.rate_hz;
if ~(isnumeric(hz) && isscalar(hz) && isreal(hz) && isfinite(hz) && hz > 0)
    error('vital:sim:badStep', 'Controller.rate_hz must be a finite positive scalar.');
end
ratio = 1 / (double(hz) * dt);
nHold = round(ratio);
if nHold < 1 || abs(ratio - nHold) > 1e-9 * nHold
    error('vital:sim:badStep', ['controller rate %g Hz with dt = %g s gives %.9g steps per sample; ' ...
        'it must be a positive integer (nothing runs faster than the base step).'], hz, dt, ratio);
end
c = struct('present', true, 'rate_hz', double(hz), 'nHold', nHold, 'init', spec.init, 'step', spec.step);
end

function g = prepareGuardOptions(G, AC)
if isempty(G), G = struct(); end
if ~(isstruct(G) && isscalar(G))
    error('vital:badInput', 'Guards must be a struct.');
end
allowed = {'quatNormTol', 'envelope', 'hMin', 'stopOnOutOfEnvelope', 'stopOnControlLimit', 'controlLimits'};
bad = setdiff(fieldnames(G), allowed);
if ~isempty(bad)
    error('vital:badInput', 'unknown guard option(s) %s (valid: %s).', strjoin(bad, ', '), strjoin(allowed, ', '));
end
g.quatNormTol = 1e-6; g.quatNote = '';
if isfield(G, 'quatNormTol')
    v = G.quatNormTol;
    if isempty(v)
        g.quatNormTol = []; g.quatNote = 'disabled by option (Guards.quatNormTol = [])';
    elseif isnumeric(v) && isscalar(v) && isfinite(v) && v > 0
        g.quatNormTol = double(v);
    else
        error('vital:badInput', 'Guards.quatNormTol must be a positive finite scalar or [].');
    end
end
g.hMin = 0; g.hNote = '';
if isfield(G, 'hMin')
    v = G.hMin;
    if isempty(v)
        g.hMin = []; g.hNote = 'disabled by option (Guards.hMin = [])';
    elseif isnumeric(v) && isscalar(v) && isfinite(v)
        g.hMin = double(v);
    else
        error('vital:badInput', 'Guards.hMin must be a finite scalar (m) or [].');
    end
end
g.stopOnOOB = false;
if isfield(G, 'stopOnOutOfEnvelope')
    v = G.stopOnOutOfEnvelope;
    if ~((islogical(v) || isnumeric(v)) && isscalar(v))
        error('vital:badInput', 'Guards.stopOnOutOfEnvelope must be a logical scalar.');
    end
    g.stopOnOOB = logical(v);
end
g.stopOnCL = false;
if isfield(G, 'stopOnControlLimit')
    v = G.stopOnControlLimit;
    if ~((islogical(v) || isnumeric(v)) && isscalar(v))
        error('vital:badInput', 'Guards.stopOnControlLimit must be a logical scalar.');
    end
    g.stopOnCL = logical(v);
end
g.clOverride = [];
if isfield(G, 'controlLimits')
    C = G.controlLimits;
    if ~(isstruct(C) && isscalar(C))
        error('vital:badInput', 'Guards.controlLimits must be a struct of control name -> [lo hi] (SI).');
    end
    for f = fieldnames(C).'
        v = C.(f{1});
        if ~(isnumeric(v) && numel(v) == 2 && ~any(isnan(v)) && v(1) <= v(2))
            error('vital:badInput', 'Guards.controlLimits.%s must be [lo hi] with lo <= hi.', f{1});
        end
    end
    g.clOverride = C;
end
g.env = struct('field', {}, 'limit', {});
if isfield(G, 'envelope')
    E = G.envelope;
    if ~(isstruct(E) && isscalar(E))
        error('vital:badInput', 'Guards.envelope must be a struct of y field -> [lo hi].');
    end
    for f = fieldnames(E).'
        lim = E.(f{1});
        if ~(isnumeric(lim) && numel(lim) == 2 && ~any(isnan(lim)) && lim(1) <= lim(2))
            error('vital:badInput', 'Guards.envelope.%s must be [lo hi] with lo <= hi.', f{1});
        end
        g.env(end+1) = struct('field', f{1}, 'limit', double(lim(:).'));
    end
    if isempty(g.env), g.envNote = 'disabled by option (Guards.envelope = struct())'; else, g.envNote = ''; end
else
    g.envNote = 'no envelope declared (AC.limits has no alpha_deg or beta_deg and Guards.envelope is not given)';
    if isstruct(AC) && isfield(AC, 'limits') && isstruct(AC.limits)
        for p = {'alpha', 'beta'}
            key = [p{1} '_deg'];
            if isfield(AC.limits, key)
                g.env(end+1) = struct('field', p{1}, 'limit', deg2rad(double(AC.limits.(key)(:).')));
            end
        end
    end
end
end

function [G, g] = buildGuards(g, y)
G = struct('name', {}, 'field', {}, 'limit', {}, 'active', {}, 'note', {});
G(end+1) = entry('quatNorm', 'quatNorm', g.quatNormTol, g.quatNote);
for i = 1:numel(g.env)
    G(end+1) = entry(['envelope:' g.env(i).field], g.env(i).field, g.env(i).limit, ''); %#ok<AGROW>
end
if isempty(g.env)
    G(end+1) = struct('name', 'envelope', 'field', '', 'limit', [], 'active', false, 'note', g.envNote);
end
G(end+1) = entry('ground', 'h', g.hMin, g.hNote);
G(end+1) = entry('outOfEnvelope', 'outOfEnvelope', g.stopOnOOB, '');
if G(end).active && ~g.stopOnOOB
    G(end).note = 'recorded, does not stop (Guards.stopOnOutOfEnvelope = false)';
end
g.useQuat = G(1).active;
g.useGround = G(strcmp({G.name}, 'ground')).active;
g.useOOB = G(end).active && g.stopOnOOB;
keep = false(1, numel(g.env));
for i = 1:numel(g.env), keep(i) = G(strcmp({G.name}, ['envelope:' g.env(i).field])).active; end
g.envActive = g.env(keep);
    function e = entry(name, field, limit, note)
        if ~isempty(note)
            e = struct('name', name, 'field', field, 'limit', limit, 'active', false, 'note', note);
        elseif ~isfield(y, field)
            e = struct('name', name, 'field', field, 'limit', limit, 'active', false, ...
                'note', sprintf('y.%s absent from the plant output: guard disabled', field));
        else
            e = struct('name', name, 'field', field, 'limit', limit, 'active', true, 'note', 'active');
        end
    end
end

function G = unevaluatedGuards(g)
% The run stopped before any plant output existed: no guard could be evaluated.
G = struct('name', {'quatNorm', 'envelope', 'ground', 'outOfEnvelope'}, ...
    'field', {'quatNorm', '', 'h', 'outOfEnvelope'}, 'limit', {g.quatNormTol, [], g.hMin, g.stopOnOOB}, ...
    'active', false, 'note', 'not evaluated: no plant output was obtained');
end

function [Y, names] = initLog(y, want, n)
Y = struct();
if isempty(want)
    names = {};
    for f = fieldnames(y).'
        v = y.(f{1});
        if (isnumeric(v) || islogical(v)) && isreal(v) && ~isempty(v)
            names{end+1} = f{1}; %#ok<AGROW>
        end
    end
else
    names = cellstr(want);
    miss = names(~isfield(y, names));
    if ~isempty(miss)
        error('vital:badInput', 'LogFields not in the plant output: %s.', strjoin(miss, ', '));
    end
end
for i = 1:numel(names)
    Y.(names{i}) = nan(numel(y.(names{i})), n);
end
end

function [r, d] = checkGuards(g, y, t)
% Order: quaternion norm, envelope, ground, clamped tables. NaN trips a guard.
r = ''; d = emptyDetail();
if g.useQuat && ~(abs(y.quatNorm - 1) <= g.quatNormTol)
    r = 'vital:sim:quatNorm';
    d = guardDetail(r, t, 'quatNorm', y.quatNorm, g.quatNormTol, '| |q| - 1 | exceeds the tolerance');
    return
end
for i = 1:numel(g.envActive)
    f = g.envActive(i).field; lim = g.envActive(i).limit; v = double(y.(f));
    if ~(all(v(:) >= lim(1)) && all(v(:) <= lim(2)))
        r = 'vital:sim:envelope';
        d = guardDetail(r, t, f, v, lim, sprintf('y.%s outside the declared envelope', f));
        return
    end
end
if g.useGround && ~(y.h >= g.hMin)
    r = 'vital:sim:ground';
    d = guardDetail(r, t, 'h', y.h, g.hMin, 'altitude below the ground limit');
    return
end
if g.useOOB && y.outOfEnvelope
    r = 'vital:sim:outOfEnvelope';
    d = guardDetail(r, t, 'outOfEnvelope', true, true, 'a table lookup was clamped (outside the published data)');
end
end

function d = guardDetail(id, t, field, value, limit, msg)
d = emptyDetail();
d.identifier = id; d.message = msg; d.time = t; d.stage = 'sample'; d.field = field; d.value = value; d.limit = limit;
end

function d = emptyDetail()
d = struct('identifier', '', 'message', '', 'time', NaN, 'stage', '', 'field', '', 'value', [], 'limit', []);
end
