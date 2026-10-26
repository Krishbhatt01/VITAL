function out = kernel(mode, a, b)
%KERNEL  The MATLAB side of the generated Simulink model (coder.extrinsic target,
%   docs/PLAN_M9.md section 2). Never call it directly except in tests.
%
%   xdot = vital.slx.kernel('plant', x, u)   vital.plant.derivatives(x, u, AC, env)
%   u    = vital.slx.kernel('fcs', t, x)     the discrete FCS sample at t_k:
%       no controller: u = u0 + du(t_k + dt/2), the command vital.sim.run gives
%                      every stage of the step from t_k (piecewise inputs)
%       controller:    ADR-026 as vital.sim.run: y = plant output at (x_k, u_held),
%                      u_ref = u0 + du(t_k + dt/2), vital.sim.sampleController,
%                      u_held = the result (held by Simulink until the next hit)
%       at t_N (after the last step; vital.sim.run never samples there) the
%       left-limit command is returned so the logged u matches vital.sim.run.
%   A failing controller sample records ctx.stop (reason, identifier, message, t,
%   x, u) and raises the reason as the error identifier; vital.slx.simulate turns
%   it into a STOPPED run.
%   Errors: vital:slx:noContext (no vital.slx.simulate context).
c = vital.slx.context('get');
switch mode
    case 'plant'
        out = vital.plant.derivatives(a, b, c.AC, c.env);
        out = out(:);
    case 'fcs'
        out = fcsSample(c, a, b(:));
    otherwise
        error('vital:badInput', 'vital.slx.kernel: unknown mode ''%s''.', mode);
end
end

function u = fcsSample(c, t, x)
k = round(t / c.dt);
tk = k * c.dt;
if k >= c.N
    u = c.uLeftFinal;                 % logged left limit at t_N (no sample)
    if c.ctrl.present, u = c.uHeld; end
    return
end
uref = c.u0 + inputAt(c, tk);
if ~c.ctrl.present
    u = uref;
    return
end
try
    [~, yc] = vital.plant.derivatives(x, c.uHeld, c.AC, c.env);
catch err
    if any(strcmp(err.identifier, {'vital:plant:nonFinite', 'vital:sim:nanState'}))
        r = 'vital:sim:nanState';
    else
        r = 'vital:sim:plantError';
    end
    stopAt(c, r, err.identifier, err.message, tk, x);
end
[uc, cnew, cstop] = vital.sim.sampleController(c.ctrl, tk, x, yc, uref, c.cstate, c.nu);
if ~isempty(cstop)
    stopAt(c, cstop.reason, cstop.identifier, cstop.message, tk, x);
end
c.cstate = cnew;
c.uHeld = uc;
c.nCalls = c.nCalls + 1;
c.tSample(end+1) = tk;
vital.slx.context('set', c);
u = uc;
end

function stopAt(c, reason, id, msg, tk, x)
c.stop = struct('reason', reason, 'identifier', id, 'message', msg, 't', tk, 'x', x, 'u', c.uHeld);
vital.slx.context('set', c);
error(reason, 'controller sample at t = %.6g s: %s', tk, msg);
end

function du = inputAt(c, tk)
% Piecewise-constant specifications at the interior point of the step from t_k,
% exactly as vital.sim.run (inputAt(tk, tk)).
du = zeros(c.nu, 1);
tm = tk + c.dt / 2;
for s = 1:numel(c.pw)
    du(c.pw(s).ch) = du(c.pw(s).ch) + c.pw(s).fcn(tm);
end
end
