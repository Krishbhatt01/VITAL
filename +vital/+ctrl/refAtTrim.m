function y0 = refAtTrim(AC, env, tr, who)
%REFATTRIM  Plant output at an OK trim: the references of the M7 control laws.
%   y0 = vital.ctrl.refAtTrim(AC, env, tr, who)
%   tr must be an OK vital.trim.solve result with a 13-state x and 4 controls u,
%   else vital:ctrl:notTrimmed (status not OK) or vital:badInput. who names the
%   caller for the message. y0 = the y of vital.plant.derivatives(tr.x, tr.u, AC, env):
%   a law that feeds back (y - y0) returns exactly u_trim at the trim.
arguments
    AC (1,1) struct
    env (1,1) struct
    tr (1,1) struct
    who (1,:) char
end
if ~isfield(tr, 'status') || ~strcmp(tr.status, 'OK')
    st = '(none)'; if isfield(tr, 'status'), st = char(tr.status); end
    error('vital:ctrl:notTrimmed', '%s: the trim status is %s, not OK; a control law is built only about an OK trim.', who, st);
end
if ~isfield(tr, 'x') || ~isfield(tr, 'u') || numel(tr.x) ~= 13 || numel(tr.u) ~= 4
    error('vital:badInput', '%s: the trim must carry a 13-element state x and 4 controls u.', who);
end
[~, y0] = vital.plant.derivatives(tr.x(:), tr.u(:), AC, env);
end
