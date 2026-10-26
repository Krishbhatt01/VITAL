function out = context(action, value)
%CONTEXT  Session store that carries what cannot cross the Simulink boundary
%   (the aircraft struct with its loadsFcn handle, env, the controller handles and
%   the controller state) from vital.slx.simulate to vital.slx.kernel
%   (docs/PLAN_M9.md section 2, ADR-039).
%
%   vital.slx.context('set', ctx)   store ctx (a struct)
%   ctx = vital.slx.context('get')  the stored struct; vital:slx:noContext if none
%   ctx = vital.slx.context('peek') the stored struct, or [] if none
%   vital.slx.context('clear')      forget it
persistent C
switch action
    case 'set'
        C = value;
    case 'get'
        if isempty(C)
            error('vital:slx:noContext', ['no Simulink run context: the VitalPlant model runs only through ' ...
                'vital.slx.simulate (the plant and controller live in MATLAB, ADR-039).']);
        end
        out = C;
    case 'peek'
        out = C;
    case 'clear'
        C = [];
    otherwise
        error('vital:badInput', 'vital.slx.context: unknown action ''%s''.', action);
end
end
