function res = runCase(id, opts)
%RUNCASE  Run one NESC atmospheric check-case with the rotating-Earth plant.
%   res = vital.nesc.runCase('6')
%   res = vital.nesc.runCase('13.4', 'dt', 0.01, 'tFinal', 30)
%   res = vital.nesc.runCase(..., 'Cache', false)
%   res = vital.nesc.runCase('11', 'Override', struct('v_ned', [75; 75; 0] * 0.3048))
%
%   Builds the case from docs/NESC_CASE_MATRIX.json (vital.nesc.caseDef), runs
%   vital.sim.run with 'Plant', @vital.plant.derivativesRotating and returns
%   the time histories under the NESC signal names in NESC units:
%     res.id, res.t (1 x n, s), res.sig.<NESC name> (1 x n), res.units.<name>
%     res.status, res.stopReason ('COMPLETED' / vital.sim.run stop reason)
%     res.out      the vital.sim.run output (SI; x in the rotating layout)
%     res.trim     F-16: the NESC-environment trim (vital.nesc.f16Trim); else []
%     res.commands F-16 autopilot cases: logged commands (t, altCmd_ft, keasCmd,
%                  baseChiCmd_deg, latOffset_ft, recovered); else []
%     res.dt, res.tFinal, res.wallTime_s, res.caseDef
%   Options: 'dt' (default the case's dt), 'tFinal' (default its duration),
%   'Cache' (default true: identical calls in one MATLAB session reuse the run),
%   'Override' (struct merged over the case's initial condition cd.ic,
%   SI fields, e.g. v_ned; for failure-mode tests; disables caching).
%   Errors: vital:nesc:notTrimmed when the F-16 trim is not OK (case 12 accepts
%   OUT_OF_DATA_ENVELOPE only), vital:nesc:unknownCase.
%   Signals (TM Vol II Table 75): altitudeMsl_ft, latitude_deg, longitude_deg,
%   feVelocity_ft_s_X/Y/Z, localGravity_ft_s2 (|gravitation|), eulerAngle_deg_
%   Roll/Pitch/Yaw, bodyAngularRateWrtEi_deg_s_Roll/Pitch/Yaw, airDensity_slug_ft3,
%   ambientPressure_lbf_ft2, ambientTemperature_dgR, speedOfSound_ft_s,
%   aero_bodyForce_lbf_X/Y/Z, aero_bodyMoment_ftlbf_L/M/N (about the CM), mach,
%   trueAirspeed_nmi_h.
arguments
    id (1,:) char
    opts.dt (1,1) double = NaN
    opts.tFinal (1,1) double = NaN
    opts.Cache (1,1) logical = true
    opts.Override (1,1) struct = struct()
end
persistent cache
if isempty(cache), cache = struct(); end
cd = vital.nesc.caseDef(id);
override = ~isempty(fieldnames(opts.Override));
for f = fieldnames(opts.Override).'
    cd.ic.(f{1}) = opts.Override.(f{1});
end
if override
    if ~cd.isF16
        error('vital:badInput', 'Override applies to the F-16 cases (their state comes from the trim), not to case %s.', id);
    end
    opts.Cache = false;
end
dt = opts.dt; if isnan(dt), dt = cd.dt; end
T = opts.tFinal; if isnan(T), T = cd.duration; end
key = matlab.lang.makeValidName(sprintf('c%s_%.6g_%.6g', id, dt, T));
if opts.Cache && isfield(cache, key), res = cache.(key); return; end
wall = tic;
logf = {'lat', 'lon', 'h', 'v_ned', 'phi', 'theta', 'psi', 'w_bi', 'w_bn', 'localGravity', 'rho', 'pressure', ...
    'temperature', 'a', 'F_aero', 'M_aero_cg', 'mach', 'V', 'alpha', 'beta', 'quatNorm', 'outOfEnvelope'};
plant = @vital.plant.derivativesRotating;
res.trim = []; res.commands = [];
if ~cd.isF16
    AC = vital.nesc.vehicle(cd.vehicle, cd.overrides);
    out = vital.sim.run(AC, cd.env, cd.x0, [], 'dt', dt, 'tFinal', T, 'Plant', plant, ...
        'Guards', cd.guards, 'LogFields', logf);
else
    AC = vital.aircraft.f16.config('CG_PCT_MAC', 25);
    tr = vital.nesc.f16Trim(cd, AC);
    if ~(strcmp(tr.status, 'OK') || (strcmp(id, '12') && strcmp(tr.status, 'OUT_OF_DATA_ENVELOPE')))
        error('vital:nesc:notTrimmed', 'case %s: NESC-environment trim status %s (%s).', id, tr.status, tr.reason);
    end
    res.trim = tr;
    args = {'dt', dt, 'tFinal', T, 'Plant', plant, 'Guards', cd.guards};
    u0 = tr.u0;
    if isempty(cd.controller)
        out = vital.sim.run(AC, cd.env, tr.x0, u0, args{:}, 'LogFields', logf);
    elseif strcmp(cd.controller.mode, 'stage')
        % the static law evaluated at every RK4 stage (proposed ADR N6, revised)
        ctl = vital.nesc.f16Controller(cd, tr, 'Mode', 'stage');
        AC.stageControl = ctl.lawFcn;
        out = vital.sim.run(AC, cd.env, tr.x0, ctl.u0, args{:}, 'Inputs', ctl.inputs, ...
            'LogFields', [logf, {'u_applied'}]);
        res.commands = ctl.commands(out);
    else
        ctl = vital.nesc.f16Controller(cd, tr, 'tFinal', T);
        out = vital.sim.run(AC, cd.env, tr.x0, u0, args{:}, 'Controller', ctl, 'LogFields', logf);
        L = out.controller.state.log; n = out.controller.state.k;
        f = fieldnames(L);
        for i = 1:numel(f), L.(f{i}) = L.(f{i})(1:n); end
        L.recovered = cd.controller.recovered;
        res.commands = L;
    end
end
res.id = id;
res.t = out.t;
[res.sig, res.units] = nescSignals(out.y);
res.status = out.status;
res.stopReason = out.stopReason;
res.out = out;
res.dt = dt;
res.tFinal = T;
res.caseDef = cd;
res.wallTime_s = toc(wall);
if opts.Cache, cache.(key) = res; end
end

function [s, u] = nescSignals(y)
k = vital.units.constants();
ft = k.ft;
s.altitudeMsl_ft = y.h / ft;                         u.altitudeMsl_ft = 'ft';
s.latitude_deg = rad2deg(y.lat);                     u.latitude_deg = 'deg';
s.longitude_deg = rad2deg(y.lon);                    u.longitude_deg = 'deg';
ax = 'XYZ';
for i = 1:3
    s.(['feVelocity_ft_s_' ax(i)]) = y.v_ned(i, :) / ft;      u.(['feVelocity_ft_s_' ax(i)]) = 'ft/s';
    s.(['aero_bodyForce_lbf_' ax(i)]) = y.F_aero(i, :) / k.lbf; u.(['aero_bodyForce_lbf_' ax(i)]) = 'lbf';
end
s.localGravity_ft_s2 = y.localGravity / ft;          u.localGravity_ft_s2 = 'ft/s2';
s.eulerAngle_deg_Roll = rad2deg(y.phi);              u.eulerAngle_deg_Roll = 'deg';
s.eulerAngle_deg_Pitch = rad2deg(y.theta);           u.eulerAngle_deg_Pitch = 'deg';
s.eulerAngle_deg_Yaw = rad2deg(y.psi);               u.eulerAngle_deg_Yaw = 'deg';
rn = {'Roll', 'Pitch', 'Yaw'}; mn = 'LMN';
for i = 1:3
    s.(['bodyAngularRateWrtEi_deg_s_' rn{i}]) = rad2deg(y.w_bi(i, :)); u.(['bodyAngularRateWrtEi_deg_s_' rn{i}]) = 'deg/s';
    s.(['aero_bodyMoment_ftlbf_' mn(i)]) = y.M_aero_cg(i, :) / (k.lbf * ft); u.(['aero_bodyMoment_ftlbf_' mn(i)]) = 'ft-lbf';
end
s.airDensity_slug_ft3 = y.rho / k.slugft3;           u.airDensity_slug_ft3 = 'slug/ft3';
s.ambientPressure_lbf_ft2 = y.pressure / k.psf;      u.ambientPressure_lbf_ft2 = 'lbf/ft2';
s.ambientTemperature_dgR = y.temperature / k.degR;   u.ambientTemperature_dgR = 'degR';
s.speedOfSound_ft_s = y.a / ft;                      u.speedOfSound_ft_s = 'ft/s';
s.mach = y.mach;                                     u.mach = '';
s.trueAirspeed_nmi_h = y.V / k.kt;                   u.trueAirspeed_nmi_h = 'kt';
end
