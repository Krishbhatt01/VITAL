function c = combine(varargin)
%COMBINE  Sum several controllers about the same reference command (M7).
%   c = vital.ctrl.combine(c1, c2, ...)
%
%   u = u_ref + sum_i (u_i - u_ref), u_i = c_i.step(t, x, y, u_ref, s_i): each
%   member is a deviation law about u_ref (vital.ctrl.pitchSas and
%   vital.ctrl.yawDamper act on different surfaces, so the sum is the joint law).
%   All members must have the same rate_hz (vital:ctrl:rateMismatch). The result
%   is static (c.static = true) only if every member is declared static;
%   otherwise c.static = false and vital.linear.linearize refuses it
%   (vital:linear:dynamicController).
%   A member whose output does not have numel(u_ref) elements is a wiring error:
%   step raises vital:ctrl:badOutputSize (vital.sim.run records it as a
%   vital:sim:controllerError STOP with that identifier; vital.linear.linearize
%   raises vital:linear:controllerError naming it; vital.ctrl.closedLoop raises
%   it directly).
%   c fields: rate_hz, init (struct('members', {cell of the member inits}); a
%   scalar struct, because vital.sim.run builds structs from init), static, step, info
%   (members: the member info structs).
%   Errors: vital:badInput (no member, a member that is not a struct with step
%   and rate_hz); vital:ctrl:rateMismatch.
if nargin == 0
    error('vital:badInput', 'vital.ctrl.combine needs at least one controller.');
end
M = varargin;
rates = zeros(1, numel(M));
isStatic = true;
hasFcnInit = false;
for i = 1:numel(M)
    m = M{i};
    if ~isstruct(m) || ~isscalar(m) || ~isfield(m, 'step') || ~isa(m.step, 'function_handle') || ~isfield(m, 'rate_hz') ...
            || ~isnumeric(m.rate_hz) || ~isscalar(m.rate_hz) || ~isfinite(m.rate_hz) || m.rate_hz <= 0
        error('vital:badInput', 'vital.ctrl.combine: member %d is not a controller struct with step and rate_hz.', i);
    end
    if ~isfield(m, 'init'), m.init = []; M{i} = m; end
    rates(i) = m.rate_hz;
    isStatic = isStatic && isfield(m, 'static') && isequal(m.static, true);
    hasFcnInit = hasFcnInit || isa(m.init, 'function_handle');
end
if any(abs(rates - rates(1)) > 1e-12 * rates(1))
    error('vital:ctrl:rateMismatch', 'vital.ctrl.combine: members have different rates (%s Hz).', num2str(rates));
end
c.rate_hz = rates(1);
if hasFcnInit
    c.init = @(x0, u0) memberInits(M, x0, u0);
else
    c.init = struct('members', {cellfun(@(m) m.init, M, 'UniformOutput', false)});
end
c.static = isStatic;
c.step = @(t, x, y, uref, s) combStep(M, t, x, y, uref, s);
info = cell(1, numel(M));
for i = 1:numel(M)
    if isfield(M{i}, 'info'), info{i} = M{i}.info; else, info{i} = struct('name', 'unnamed'); end
end
c.info = struct('name', 'combine', 'members', {info}, ...
    'law', 'u = u_ref + sum_i (u_i - u_ref)');
end

function s = memberInits(M, x0, u0)
c = cell(1, numel(M));
for i = 1:numel(M)
    if isa(M{i}.init, 'function_handle'), c{i} = M{i}.init(x0, u0); else, c{i} = M{i}.init; end
end
s = struct('members', {c});
end

function [u, s] = combStep(M, t, x, y, uref, s)
uref = uref(:);
u = uref;
for i = 1:numel(M)
    [ui, s.members{i}] = M{i}.step(t, x, y, uref, s.members{i});
    if ~(isnumeric(ui) && numel(ui) == numel(uref))
        error('vital:ctrl:badOutputSize', 'vital.ctrl.combine: member %d returned %d values; expected %d.', ...
            i, numel(ui), numel(uref));
    end
    u = u + (double(ui(:)) - uref);
end
end
