function r = closedLoop(AC, env, tr, c)
%CLOSEDLOOP  Bare vs augmented linear models and modes about one trim (M7).
%   r = vital.ctrl.closedLoop(AC, env, tr, c)
%
%   c  a STATIC controller in the vital.sim.run form (static = true), e.g.
%      vital.ctrl.pitchSas, yawDamper, nescLqr or combine.
%   Before linearizing, the controller is called once at the trim with y(x_trim,
%   u_trim) and u_ref = u_trim: an output that is not 4 real numbers is
%   vital:ctrl:badOutputSize. A controller not declared static is refused by
%   vital.linear.linearize (vital:linear:dynamicController) and is never
%   linearized as static.
%   Bare: vital.linear.linearize(AC, env, tr); augmented: the same with
%   'Controller', c (ADR-024, ADR-026, ADR-028). Modes: vital.linear.modes (8 states).
%
%   r fields
%     bare, aug     struct(lin, modes)
%     status        'STABLE' (every closed-loop 8-state eigenvalue has Re < 0),
%                   'UNSTABLE' (some Re >= 0), 'NOT_CONVERGED' (a closed-loop
%                   column 1-8 is not OK: no verdict, no modes)
%     unstable      struct array (name, eigenvalue) of closed-loop modes with Re >= 0
%     destabilized  true when the closed loop has more eigenvalues with Re >= 0
%                   than the bare airframe (e.g. a wrong-sign gain)
%     table         one row per bare mode: name, bare and augmented eigenvalue,
%                   wn and zeta, dzeta = zeta_aug - zeta_bare
%     improvement   logical per table row: dzeta > 0 AND status 'STABLE' (an
%                   unstable closed loop is never reported as an improvement)
%     extraModes    names of closed-loop modes that are not one of the five
%                   classical modes, or whose status is not OK: the MIL-F-8785C
%                   3.1.12 equivalent-system flag
%   Errors: vital:ctrl:badOutputSize; the errors of vital.linear.linearize.
arguments
    AC (1,1) struct
    env (1,1) struct
    tr (1,1) struct
    c (1,1) struct
end
y0 = vital.ctrl.refAtTrim(AC, env, tr, 'vital.ctrl.closedLoop');
if ~isfield(c, 'step') || ~isa(c.step, 'function_handle')
    error('vital:badInput', 'vital.ctrl.closedLoop: the controller needs a function handle step.');
end
s0 = [];
if isfield(c, 'init')
    if isa(c.init, 'function_handle'), s0 = c.init(tr.x(:), tr.u(:)); else, s0 = c.init; end
end
[u, ~] = c.step(0, tr.x(:), y0, tr.u(:), s0);
if ~(isnumeric(u) && isreal(u) && numel(u) == 4)
    error('vital:ctrl:badOutputSize', 'vital.ctrl.closedLoop: the controller returned %d values at the trim; expected 4 real numbers [de da dr throttle].', numel(u));
end
linB = vital.linear.linearize(AC, env, tr);
linA = vital.linear.linearize(AC, env, tr, 'Controller', c);
r.bare = struct('lin', linB, 'modes', modesIfOK(linB));
r.aug = struct('lin', linA, 'modes', modesIfOK(linA));
r.unstable = struct('name', {}, 'eigenvalue', {});
r.destabilized = false;
r.table = struct('name', {}, 'bareEigenvalue', {}, 'augEigenvalue', {}, 'bareWn', {}, 'augWn', {}, ...
    'bareZeta', {}, 'augZeta', {}, 'dzeta', {}, 'augStatus', {});
r.improvement = false(1, 0);
r.extraModes = {};
if isempty(r.aug.modes)
    r.status = 'NOT_CONVERGED';
    return
end
lamA = eig(linA.A(1:8, 1:8));
nA = sum(real(lamA) >= 0);
if nA == 0, r.status = 'STABLE'; else, r.status = 'UNSTABLE'; end
if ~isempty(r.bare.modes)
    r.destabilized = nA > sum(real(eig(linB.A(1:8, 1:8))) >= 0);
end
ma = r.aug.modes;
for k = 1:numel(ma)
    if real(ma(k).eigenvalue) >= 0
        r.unstable(end+1) = struct('name', ma(k).name, 'eigenvalue', ma(k).eigenvalue);
    end
end
classical = {'short_period', 'phugoid', 'dutch_roll', 'roll', 'spiral'};
for k = 1:numel(ma)
    if ~any(strcmp(ma(k).name, classical)) || ~strcmp(ma(k).status, 'OK')
        r.extraModes{end+1} = sprintf('%s (%s)', ma(k).name, ma(k).status);
    end
end
mb = r.bare.modes;
for k = 1:numel(mb)
    j = find(strcmp({ma.name}, mb(k).name), 1);
    row = struct('name', mb(k).name, 'bareEigenvalue', mb(k).eigenvalue, 'augEigenvalue', NaN, ...
        'bareWn', mb(k).wn, 'augWn', NaN, 'bareZeta', mb(k).zeta, 'augZeta', NaN, 'dzeta', NaN, 'augStatus', 'MISSING');
    if ~isempty(j)
        row.augEigenvalue = ma(j).eigenvalue; row.augWn = ma(j).wn; row.augZeta = ma(j).zeta;
        row.dzeta = ma(j).zeta - mb(k).zeta; row.augStatus = ma(j).status;
    end
    r.table(end+1) = row;
end
r.improvement = ([r.table.dzeta] > 0) & strcmp(r.status, 'STABLE');
end

function m = modesIfOK(lin)
% 8-state modes when the columns they use converged (linear ADR-028); else empty
m = [];
if strcmp(lin.status, 'OK') || all(strcmp(lin.columnStatus(1:8), 'OK'))
    m = vital.linear.modes(lin);
end
end
