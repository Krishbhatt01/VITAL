function lim = controlLimits(AC, n)
%CONTROLLIMITS  Default command limits of an aircraft, as vital.sim.run monitors them.
%   lim = vital.sim.controlLimits(AC, n)
%
%   AC   aircraft configuration with AC.controlNames (n names) and AC.limits;
%        a limit is AC.limits.<name>_deg (converted deg -> rad) or
%        AC.limits.<name> (taken as SI, e.g. throttle [0 1])
%   n    number of control values being checked
%   lim  names (1 x n cell), lo, hi (n x 1, SI; -Inf/Inf where no limit is
%        declared), monitored (true if any limit is finite), note (why not)
%   For the NESC F-16 (vital.aircraft.f16.config): de +/-24 deg, da +/-21.5 deg,
%   dr +/-30 deg, throttle [0 1]. Limits are monitored, never enforced: a
%   command beyond them is recorded (and optionally stops the run) but is
%   never clipped (R1 M6).
lim = struct('names', {{}}, 'lo', -Inf(n, 1), 'hi', Inf(n, 1), 'monitored', false, 'note', '');
if ~(isstruct(AC) && isfield(AC, 'controlNames'))
    lim.note = 'AC.controlNames absent: command limits not monitored';
    return
end
names = cellstr(AC.controlNames);
if numel(names) ~= n
    lim.note = sprintf('AC.controlNames has %d entries but %d controls are checked: command limits not monitored', numel(names), n);
    return
end
lim.names = names(:).';
if ~(isfield(AC, 'limits') && isstruct(AC.limits))
    lim.note = 'AC.limits absent: command limits not monitored';
    return
end
L = AC.limits;
for i = 1:n
    if isfield(L, [names{i} '_deg'])
        v = deg2rad(double(L.([names{i} '_deg'])));
    elseif isfield(L, names{i})
        v = double(L.(names{i}));
    else
        continue
    end
    if ~(isnumeric(v) && numel(v) == 2 && ~any(isnan(v)) && v(1) <= v(2))
        error('vital:badInput', 'AC.limits for control %s must be [lo hi] with lo <= hi.', names{i});
    end
    lim.lo(i) = v(1); lim.hi(i) = v(2);
end
lim.monitored = any(isfinite([lim.lo; lim.hi]));
if ~lim.monitored, lim.note = 'no finite command limit declared in AC.limits'; end
end
