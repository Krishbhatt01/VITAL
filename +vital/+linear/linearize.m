function lin = linearize(AC, env, tr, opts)
%LINEARIZE  Linear model of the plant about a trim (12 states, 4 inputs).
%   lin = vital.linear.linearize(AC, env, tr)
%   lin = vital.linear.linearize(AC, env, tr, 'Name', value, ...)
%
%   AC, env  as for vital.plant.derivatives (flat Earth, env.g, env.wind_n)
%   tr       a vital.trim.solve result with status 'OK'; anything else raises
%            vital:linear:notTrimmed (only OK may be used for analysis)
%
%   State  x_lin = [u v w p q r phi theta psi pN pE h] (m/s, rad/s, rad, m)
%   Inputs u = [de da dr throttle] (rad, rad, rad, 0..1)
%   Map to the 13-state plant: v_b = [u v w], w_b = [p q r],
%     q = vital.frames.eul2quat(phi, theta, psi), p_n = [pN pE -h].
%   Map of the derivative back: body accelerations xdot(1:6); Euler rates from
%   the body rates (3-2-1 kinematics, CONVENTIONS 3)
%     phidot   = p + (q sin(phi) + r cos(phi)) tan(theta)
%     thetadot = q cos(phi) - r sin(phi)
%     psidot   = (q sin(phi) + r cos(phi)) / cos(theta)
%   pNdot, pEdot = xdot(11:12), hdot = -xdot(13). The plant's quaternion
%   derivative (with its constraint term) is not used.
%
%   Derivatives: vital.linear.jacobian (step study, FC-506) with row scales
%   FScale = [g g g 1 1 1 1 1 1 V V V] and typical perturbations ZScale =
%   [10 10 10 m/s, 1 1 1 rad/s, 1 1 1 rad, 1000 1000 1000 m, 0.1 0.1 0.1 rad, 1].
%
%   Options  'H0'      first steps (16 x 1; default [1 1 1 m/s, 0.1 0.1 0.1 rad/s,
%                      0.01 0.01 0.01 rad, 10 10 10 m, 0.01 0.01 0.01 rad, 0.01])
%            'Steps'   step-study length (7);  'RelTol', 'KinkTol' (1e-6 each)
%            'TrimTol' equilibrium tolerance (1e-8, review R1 B1): the trim must satisfy
%                      ||W f0(1:8)||_inf <= TrimTol for THIS (AC, env), with
%                      W = [1/g x3, 1 (rad/s^2) x3, 1 (rad/s) x2]; otherwise
%                      vital:linear:notEquilibrium (e.g. a trim of another CG or g).
%                      vital.trim.solve accepts a scaled residual < 1e-9.
%            'Controller'  closed-loop linearization with a STATIC controller in
%                      the vital.sim.run struct form {rate_hz, init, step} and the
%                      declaration static = true. The loop follows the sim
%                      semantics in the continuous limit (ADR-026): the controller
%                      measures the plant under the command actually applied,
%                        u = step(0, x, y(x, u), u_ref, state0), where
%                        x is the 13-state plant state,
%                        y is the plant output at (x, u) (u-dependent fields such
%                          as nz make this an algebraic loop),
%                        state0 = init, or init(x0, u0) for a function handle.
%                      The loop is solved by one fixed-point step from u = u_ref,
%                      then Newton's method (finite-difference Jacobian, at most
%                      30 iterations). Converged: |u - step(..)| <= 1e-14 (1 + |u|),
%                      or a stalled residual <= 1e-11 (1 + |u|). Otherwise
%                      vital:linear:algebraicLoop.
%                      Closed loop: f(x_lin, u_ref) = plant(x, u(x, u_ref)).
%                      Refusals:
%                        vital:linear:dynamicController when static is not declared
%                        true, or when any call returns a state ~= state0 (checked
%                        at the trim and at every perturbed point). A dynamic
%                        controller is never linearized as static. This is
%                        conservative: a static law that keeps bookkeeping state
%                        (e.g. a call counter) is refused too (R1 MINOR 12).
%                        vital:linear:controllerNotAtTrim when u(x0, u0) ~= u0
%                        (tolerance 1e-9 (1 + |u0|)): the trim would not be a
%                        closed-loop equilibrium.
%                      Continuous approximation: the ZOH delay of a sampled
%                      controller (about half a sample) is not modelled.
%
%   lin fields
%     A (12x12), B (12x4), stateNames, inputNames, x0 (12), u0 (4)
%     status   'OK' | 'NOT_CONVERGED' (a column without a plateau or at a table
%              breakpoint or round-off limited; those columns of A/B are NaN),
%              reason, stepStudy (16)
%     columnStatus  1x16 cellstr, the status of each column of [A B] ('OK',
%              'KINK', 'NO_PLATEAU', 'ROUNDOFF', 'NON_FINITE'; R1 M1). A consumer
%              that uses only some columns (vital.linear.modes: 1-8, plus 12 with
%              IncludeHeight) may proceed when those are OK, even if status is
%              NOT_CONVERGED. Closed loop: 'OK' only if the column is OK in the
%              closed-loop, controller and open-loop studies (else CONTROLLER_...
%              or OPEN_... prefixes).
%     equilibriumResidual  ||W f0(1:8)||_inf at the trim (see 'TrimTol')
%     lon      states {u w q theta} (x_lin 1 3 5 8): idx, stateNames, A, B,
%              air: [V alpha q theta] form (T, A = T A T^-1, B = T B, stateNames)
%     lat      states {v p r phi} (x_lin 2 4 6 7): idx, stateNames, A, B,
%              air: [beta p r phi] form
%     n_alpha  the alpha-only PARTIAL: wind-axis normal load factor per rad of
%              alpha at fixed V, q, theta AND elevator,
%              n_alpha = -(V/g) dalphadot/dalpha + sin(gamma0) (derivation in
%              tests/M5/tF16Linearize.m (e)); NaN with a note when wind ~= 0.
%              It is NOT MIL-F-8785C's n/alpha (review R1 B2): -0.9 % at the
%              README trim, up to 15 % in the envelope. Use n_alpha_ss.
%     n_alpha_ss  MIL-F-8785C 6.2 n/alpha (p.77): steady-state normal load factor
%              per alpha for an incremental pitch-control deflection at constant
%              speed, (V/g) q_ss/alpha_ss with Z_de and Z_q included
%              (vital.linear.nAlphaSteady; equal to vital.fq.metrics
%              n_alpha_g_per_rad). n_alpha_ss_status 'OK' | 'NOT_LEVEL' (NaN) |
%              'SINGULAR' | 'NOT_CONVERGED'; n_alpha_ss_reason. Open-loop airframe.
%     inputRange  4x2 [min max] of [de da dr throttle] from AC.limits (SI)
%     f0 (x_lin-dot at the trim), V0, g, gamma0, trim (tr), notes
%     closedLoop  false, or true with 'Controller'; then
%       A, B     closed loop: d f / d x_lin, d f / d u_ref (the partitions, air
%                forms and modes follow the closed loop)
%       open     open-loop A, B, status, reason, stepStudy
%       K, Kref  controller Jacobians du/dx_lin (4x12) and du/du_ref (4x4), so
%                A = open.A + open.B K and B = open.B Kref (to step-study accuracy)
%       controller  rate_hz, note; status is OK only if all three step studies are
%       n_alpha  always from the OPEN-loop airframe
%   The air-axis converters are exact at beta0 = 0 (the wings-level trims of
%   vital.trim.solve); with wind they include the attitude dependence of the
%   air-relative velocity within each partition.
%   Errors: vital:linear:notTrimmed; vital:linear:notEquilibrium; vital:badInput
%   (non-finite or missing trim state/controls, non-finite gravity or wind, bad H0,
%   a malformed controller or controller output); vital:linear:dynamicController;
%   vital:linear:controllerNotAtTrim (|u(x0) - u0| > 1e-9 (1 + |u0|));
%   vital:linear:algebraicLoop; vital:linear:controllerError (the controller's
%   step raised an error; its identifier is in the message). The controller is
%   called through vital.sim.sampleController, as in vital.sim.run.
arguments
    AC (1,1) struct
    env (1,1) struct
    tr (1,1) struct
    opts.H0 double = []
    opts.Steps (1,1) double = 7
    opts.RelTol (1,1) double = 1e-6
    opts.KinkTol (1,1) double = 1e-6
    opts.TrimTol (1,1) double = 1e-8
    opts.Controller (1,1) struct = struct()
end
if ~isfield(tr, 'status') || ~strcmp(tr.status, 'OK')
    st = '(none)'; rs = '';
    if isfield(tr, 'status'), st = char(tr.status); end
    if isfield(tr, 'reason'), rs = char(tr.reason); end
    error('vital:linear:notTrimmed', 'trim status is %s, not OK: cannot linearize (%s).', st, rs);
end
if ~isfield(tr, 'x') || ~isfield(tr, 'u') || numel(tr.x) ~= 13 || numel(tr.u) ~= 4
    error('vital:badInput', 'the trim must carry a 13-element state x and 4 controls u.');
end
vital.validate.finite(tr.x, 'trim state');
vital.validate.finite(tr.u, 'trim controls');
if ~isfield(env, 'g') || ~isfield(env, 'wind_n')
    error('vital:badInput', 'env must have fields g and wind_n.');
end
vital.validate.finite(env.g, 'gravity');
vital.validate.finite(env.wind_n, 'wind');

stateNames = {'u','v','w','p','q','r','phi','theta','psi','pN','pE','h'};
inputNames = {'de','da','dr','throttle'};
x13 = tr.x(:);
eul = vital.frames.dcm2eul(vital.frames.quat2dcm(x13(7:10)));
x0 = [x13(1:6); eul; x13(11); x13(12); -x13(13)];
u0 = tr.u(:);
z0 = [x0; u0];
if isempty(opts.H0)
    h0 = [1 1 1, 0.1 0.1 0.1, 0.01 0.01 0.01, 10 10 10, 0.01 0.01 0.01, 0.01].';
else
    h0 = opts.H0(:);
    if numel(h0) ~= 16, error('vital:badInput', 'H0 must have 16 elements (12 states, 4 inputs).'); end
end
g = env.g;
wind = env.wind_n(:);
v_air0 = x13(1:3) - vital.frames.dcm321(eul(1), eul(2), eul(3)) * wind;
V0 = norm(v_air0);
fscale = [g g g 1 1 1 1 1 1 V0 V0 V0].';
zscale = [10 10 10 1 1 1 1 1 1 1000 1000 1000 0.1 0.1 0.1 1].';

fun = @(z) linDeriv(z, AC, env);
f0 = fun(z0);
eqRes = max(abs(f0(1:8) ./ [g g g 1 1 1 1 1].'));
if ~(eqRes <= opts.TrimTol)
    error('vital:linear:notEquilibrium', ['the trim is not an equilibrium of this aircraft and environment: ' ...
        '||W f0(1:8)||_inf = %.3g > TrimTol %.3g (was it trimmed with another CG, g or wind?).'], eqRes, opts.TrimTol);
end
[J, info] = vital.linear.jacobian(fun, z0, h0, 'Steps', opts.Steps, 'RelTol', opts.RelTol, ...
    'KinkTol', opts.KinkTol, 'FScale', fscale, 'ZScale', zscale, 'Names', [stateNames inputNames]);

Aopen = J(:, 1:12);
lin.A = Aopen;
lin.B = J(:, 13:16);
lin.stateNames = stateNames;
lin.inputNames = inputNames;
lin.x0 = x0;
lin.u0 = u0;
lin.status = info.status;
lin.reason = info.reason;
lin.stepStudy = info.stepStudy;
lin.columnStatus = {info.stepStudy.status};
lin.equilibriumResidual = eqRes;
lin.f0 = f0;
lin.V0 = V0;
lin.g = g;
lin.gamma0 = asin(max(-1, min(1, lin.f0(12) / norm(lin.f0(10:12)))));
if isfield(tr, 'cond') && isfield(tr.cond, 'gamma'), lin.gamma0 = tr.cond.gamma; end
lin.notes = {};
lin.closedLoop = false;

% ---- closed loop (static controller) ----------------------------------------------
if ~isempty(fieldnames(opts.Controller))
    c = checkController(opts.Controller);
    if isa(c.init, 'function_handle'), state0 = c.init(x13, u0); else, state0 = c.init; end
    ctrl = @(z) controllerOutput(z, c, state0, AC, env);
    uTrim = ctrl(z0);
    if any(abs(uTrim - u0) > 1e-9 * (1 + abs(u0)))
        error('vital:linear:controllerNotAtTrim', ...
            'the controller output at the trim, [%s], differs from the trim controls [%s]: not a closed-loop equilibrium.', ...
            num2str(uTrim.', '%.6g '), num2str(u0.', '%.6g '));
    end
    fcl = @(z) linDeriv([z(1:12); ctrl(z)], AC, env);
    [Jcl, infoCl] = vital.linear.jacobian(fcl, z0, h0, 'Steps', opts.Steps, 'RelTol', opts.RelTol, ...
        'KinkTol', opts.KinkTol, 'FScale', fscale, 'ZScale', zscale, 'Names', [stateNames inputNames]);
    [Ju, infoU] = vital.linear.jacobian(ctrl, z0, h0, 'Steps', opts.Steps, 'RelTol', opts.RelTol, ...
        'KinkTol', opts.KinkTol, 'FScale', [0.1 0.1 0.1 1], 'ZScale', zscale, 'Names', [stateNames inputNames]);
    lin.open = struct('A', lin.A, 'B', lin.B, 'status', lin.status, 'reason', lin.reason, 'stepStudy', lin.stepStudy, ...
        'columnStatus', {lin.columnStatus});
    lin.A = Jcl(:, 1:12);
    lin.B = Jcl(:, 13:16);
    lin.K = Ju(:, 1:12);
    lin.Kref = Ju(:, 13:16);
    lin.stepStudy = infoCl.stepStudy;
    lin.controllerStepStudy = infoU.stepStudy;
    cs = {infoCl.stepStudy.status}; cu = {infoU.stepStudy.status}; co = lin.open.columnStatus;
    for j = 1:16
        if ~strcmp(cs{j}, 'OK'), continue; end
        if ~strcmp(cu{j}, 'OK'), cs{j} = ['CONTROLLER_' cu{j}];
        elseif ~strcmp(co{j}, 'OK'), cs{j} = ['OPEN_' co{j}]; end
    end
    lin.columnStatus = cs;
    parts = {}; sts = {info.status, infoCl.status, infoU.status};
    labels = {'open loop', 'closed loop', 'controller'};
    rs = {info.reason, infoCl.reason, infoU.reason};
    for k = 1:3
        if ~strcmp(sts{k}, 'OK'), parts{end+1} = sprintf('%s: %s', labels{k}, rs{k}); end %#ok<AGROW>
    end
    if isempty(parts), lin.status = 'OK'; lin.reason = '';
    else, lin.status = 'NOT_CONVERGED'; lin.reason = strjoin(parts, ' | '); end
    lin.closedLoop = true;
    lin.controller = struct('rate_hz', c.rate_hz, 'static', true, ...
        'note', ['continuous approximation (ADR-026): y at the applied command, algebraic loop solved; ' ...
        'the ZOH sampling delay is not modelled']);
end

% ---- partitions and air-axis forms -------------------------------------------
lon = [1 3 5 8]; lat = [2 4 6 7];
lin.lon = struct('idx', lon, 'stateNames', {stateNames(lon)}, 'A', lin.A(lon, lon), 'B', lin.B(lon, :), ...
    'inputNames', {inputNames});
lin.lat = struct('idx', lat, 'stateNames', {stateNames(lat)}, 'A', lin.A(lat, lat), 'B', lin.B(lat, :), ...
    'inputNames', {inputNames});
G = airAngleGradient(x0, wind);            % rows V, alpha, beta; columns x_lin(1:12)
Tlon = eye(4); Tlon(1, :) = G(1, lon); Tlon(2, :) = G(2, lon);
Tlat = eye(4); Tlat(1, :) = G(3, lat);
lin.lon.air = struct('stateNames', {{'V','alpha','q','theta'}}, 'T', Tlon, ...
    'A', Tlon * lin.lon.A / Tlon, 'B', Tlon * lin.lon.B);
lin.lat.air = struct('stateNames', {{'beta','p','r','phi'}}, 'T', Tlat, ...
    'A', Tlat * lin.lat.A / Tlat, 'B', Tlat * lin.lat.B);

% ---- normal load factor per alpha (M6: n/alpha) --------------------------------
if any(wind ~= 0)
    lin.n_alpha = NaN;
    lin.notes{end+1} = 'n_alpha not computed: its derivation assumes zero wind';
else
    Aair = Tlon * Aopen(lon, lon) / Tlon;              % open-loop airframe
    lin.n_alpha = -(V0 / g) * Aair(2, 2) + sin(lin.gamma0);
end
AairOpen = Tlon * Aopen(lon, lon) / Tlon;              % open-loop airframe
if lin.closedLoop, BairOpen = Tlon * lin.open.B(lon, :); else, BairOpen = Tlon * lin.B(lon, :); end
if any(~isfinite(AairOpen(:))) || any(~isfinite(BairOpen(:, 1)))
    lin.n_alpha_ss = NaN; lin.n_alpha_ss_status = 'NOT_CONVERGED';
    lin.n_alpha_ss_reason = 'a longitudinal column of the linear model did not converge';
else
    [lin.n_alpha_ss, lin.n_alpha_ss_status, lin.n_alpha_ss_reason] = ...
        vital.linear.nAlphaSteady(AairOpen, BairOpen, V0, g, lin.gamma0);
end

% ---- control ranges (SI) ---------------------------------------------------------
L = AC.limits;
lin.inputRange = [deg2rad(L.de_deg(:).'); deg2rad(L.da_deg(:).'); deg2rad(L.dr_deg(:).'); L.throttle(:).'];
lin.trim = tr;
end

function y = linDeriv(z, AC, env)
% x_lin, u -> x_lin-dot through the 13-state plant
ph = z(7); th = z(8); ps = z(9);
x = [z(1:6); vital.frames.eul2quat(ph, th, ps); z(10); z(11); -z(12)];
xd = vital.plant.derivatives(x, z(13:16), AC, env);
y = [xd(1:6);
     vital.linear.eulerRates(ph, th, z(4), z(5), z(6));
     xd(11);
     xd(12);
     -xd(13)];
end

function c = checkController(c)
% validate the M5-B controller struct and the static declaration
if ~isfield(c, 'step') || ~isa(c.step, 'function_handle')
    error('vital:badInput', 'Controller must have a function handle step: [u, state] = step(t, x, y, u_ref, state).');
end
if ~isfield(c, 'rate_hz') || ~isnumeric(c.rate_hz) || ~isscalar(c.rate_hz) || ~isfinite(c.rate_hz) || c.rate_hz <= 0
    error('vital:badInput', 'Controller rate_hz must be a finite positive scalar.');
end
if ~isfield(c, 'init'), c.init = []; end
if ~isfield(c, 'static') || ~isequal(c.static, true)
    error('vital:linear:dynamicController', ['only static (memoryless) controllers can be linearized: ' ...
        'declare Controller.static = true for a controller whose state never changes.']);
end
end

function u = controllerOutput(z, c, state0, AC, env)
% ADR-026: solve u = step(0, x, y(x, u), u_ref, state0) (continuous-limit loop)
xl = z(1:12); uref = z(13:16);
x = [xl(1:6); vital.frames.eul2quat(xl(7), xl(8), xl(9)); xl(10); xl(11); -xl(12)];
cfun = @(uu) stepOnce(x, uu, uref, c, state0, AC, env);
u = uref; rPrev = Inf;
for it = 1:30
    r = u - cfun(u);
    rn = max(abs(r)); sc = 1 + max(abs(u));
    if rn <= 1e-14 * sc || (it > 3 && rn >= 0.5 * rPrev && rn <= 1e-11 * sc)
        return
    end
    rPrev = rn;
    if it == 1
        u = u - r;                                   % fixed-point step: u = step(y(x, u_ref))
        continue
    end
    Jc = zeros(4);
    for i = 1:4
        d = zeros(4, 1); d(i) = 1e-7 * max(1, abs(u(i)));
        Jc(:, i) = (cfun(u + d) - cfun(u - d)) / (2 * d(i));
    end
    Jn = eye(4) - Jc;
    if rcond(Jn) < 1e-12
        error('vital:linear:algebraicLoop', 'the controller-plant algebraic loop u = step(y(x, u)) is singular (rcond %.3g).', rcond(Jn));
    end
    u = u - Jn \ r;
end
error('vital:linear:algebraicLoop', ['the controller-plant algebraic loop u = step(y(x, u)) did not converge ' ...
    '(residual %.3g after 30 iterations): no unique static solution.'], rn);
end

function u = stepOnce(x, ua, uref, c, state0, AC, env)
% one controller call with y evaluated at the applied command ua (ADR-026)
[~, y] = vital.plant.derivatives(x, ua, AC, env);
[u, s, stop] = vital.sim.sampleController(c, 0, x, y, uref, state0, 4);   % same call as vital.sim.run
if ~isempty(stop) && strcmp(stop.reason, 'vital:sim:controllerError')
    error('vital:linear:controllerError', 'the controller raised %s: %s', stop.identifier, stop.message);
end
if ~isequal(s, state0)
    error('vital:linear:dynamicController', ...
        'the controller changed its state during linearization: it is dynamic and cannot be linearized as static.');
end
if ~isnumeric(u) || numel(u) ~= 4 || any(~isfinite(u(:)))
    error('vital:badInput', 'the controller must return 4 finite controls [de da dr throttle].');
end
u = u(:);
end

function G = airAngleGradient(x0, wind)
% d[V; alpha; beta]/d x_lin (3 x 12) of v_air = v_b - C_bn(phi, theta, psi) wind_n
ph = x0(7); th = x0(8); ps = x0(9);
C = vital.frames.dcm321(ph, th, ps);
va = x0(1:3) - C * wind;
u = va(1); v = va(2); w = va(3); V = norm(va);
dV = va.' / V;
da = [-w, 0, u] / (u^2 + w^2);
db = ([0 1 0] - v * va.' / V^2) / sqrt(V^2 - v^2);      % d asin(v/V)
% velocity sensitivity to the Euler angles: dv_air/d angle = -(dC/d angle) wind
c1 = cos(ph); s1 = sin(ph); c2 = cos(th); s2 = sin(th); c3 = cos(ps); s3 = sin(ps);
R1 = [1 0 0; 0 c1 s1; 0 -s1 c1]; R2 = [c2 0 -s2; 0 1 0; s2 0 c2]; R3 = [c3 s3 0; -s3 c3 0; 0 0 1];
dR1 = [0 0 0; 0 -s1 c1; 0 -c1 -s1]; dR2 = [-s2 0 -c2; 0 0 0; c2 0 -s2]; dR3 = [-s3 c3 0; -c3 -s3 0; 0 0 0];
dva = -[dR1 * R2 * R3 * wind, R1 * dR2 * R3 * wind, R1 * R2 * dR3 * wind];   % 3 x 3 (phi theta psi)
G = zeros(3, 12);
G(:, 1:3) = [dV; da; db];
G(:, 7:9) = [dV; da; db] * dva;
end
