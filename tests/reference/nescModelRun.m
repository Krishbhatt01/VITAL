function res = nescModelRun(id)
%NESCMODELRUN  Run NESC check-case 1..10 with the vehicle built as a vital.AircraftModel
%   (tests/reference/nescAircraftModel.m) instead of the vital.nesc.vehicle struct
%   (TEST FIXTURE; increment I0, ADR-041).
%   res = nescModelRun(id)    id '1'..'10'
%   Path: model.toRuntime() -> vital.sim.run(..., 'Plant', @vital.plant.derivativesRotating)
%   with the case's env, x0, dt, duration and guards from vital.nesc.caseDef, i.e.
%   exactly the non-F-16 branch of vital.nesc.runCase with only the vehicle replaced.
%   res has the fields vital.nesc.compare reads (id, t, sig, units, status,
%   stopReason, caseDef) plus out, dt, tFinal and model.
%   The signal mapping below is a COPY of the local function nescSignals of
%   +vital/+nesc/runCase.m (runCase has no vehicle override; FINDINGS_FOR_I1 F-5).
%   tests/M9/i0/tI0NescAircraftModel.m#modelPathEqualsStructPath checks the copy
%   against runCase itself.
cd = vital.nesc.caseDef(id);
if cd.isF16
    error('vital:badInput', 'nescModelRun covers the sphere and brick cases 1-10 only, not case %s.', id);
end
model = nescAircraftModel(cd.vehicle, cd.overrides);
AC = model.toRuntime();
logf = {'lat', 'lon', 'h', 'v_ned', 'phi', 'theta', 'psi', 'w_bi', 'w_bn', 'localGravity', 'rho', 'pressure', ...
    'temperature', 'a', 'F_aero', 'M_aero_cg', 'mach', 'V', 'alpha', 'beta', 'quatNorm', 'outOfEnvelope'};
wall = tic;
out = vital.sim.run(AC, cd.env, cd.x0, [], 'dt', cd.dt, 'tFinal', cd.duration, ...
    'Plant', @vital.plant.derivativesRotating, 'Guards', cd.guards, 'LogFields', logf);
res.id = id;
res.t = out.t;
[res.sig, res.units] = nescSignals(out.y);
res.status = out.status;
res.stopReason = out.stopReason;
res.out = out;
res.dt = cd.dt;
res.tFinal = cd.duration;
res.caseDef = cd;
res.model = model;
res.trim = []; res.commands = [];
res.wallTime_s = toc(wall);
end

function [s, u] = nescSignals(y)
% copy of +vital/+nesc/runCase.m nescSignals (TM Vol II Table 75 names, NESC units)
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
