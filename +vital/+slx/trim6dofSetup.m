function P = trim6dofSetup(opts)
%TRIM6DOFSETUP  Trim the NESC F-16 and collect everything models/F16Trim6DOF.slx needs.
%   P = vital.slx.trim6dofSetup()          NESC case 11 start / README trim:
%                                          10013 ft, 565.6854 ft/s, heading 45 deg
%   P = vital.slx.trim6dofSetup('Mach', 0.6, 'h_ft', 20000, 'psi_deg', 0, 'CG_PCT_MAC', 30)
%
%   What you choose: the flight condition (speed or Mach, altitude, heading), the
%   CG, and "level, wings-level, no sideslip". What the trim SOLVES for: alpha
%   (= theta in level flight), the elevator and the throttle; aileron and rudder are
%   0 because the F-16 is symmetric. Those x and u are the trim point x-bar, u-bar.
%
%   Everything comes from the NASA data objects (D1): f16_data =
%   vital.aircraft.f16.data(...) -> f16 = vital.AircraftModel.fromData(f16_data). The
%   loads, the trim (through f16.toRuntime()), the mass, the inertia and c-bar all
%   come from that one object. The trim is computed ONCE, here, before the run;
%   Simulink never re-trims: it holds u = u-bar and integrates.
%
%   P fields (SI): data (vital.data.AircraftData), f16 (vital.AircraftModel), AC
%   (f16.toRuntime(), for the trim solver and vital.sim.run), tr (vital.trim.solve
%   result), cond, env, V, h, Mach, g,
%   m, J, cbar, x0 (13 x 1, [v_b; w_b; q; p_n]), u_trim (4 x 1, [de da dr
%   throttle], rad and 0..1), Vb0, w0, eul0 ([phi theta psi]), Xe0 (NED),
%   dt, tFinal, weightOn (1), du ([t du1..du4], zero), model (file), plot
%   (true: the model's StopFcn draws the result figures), plotDir.
arguments
    opts.h_ft (1,1) double {mustBeFinite} = 10013
    opts.V_ftps (1,1) double {mustBeFinite, mustBePositive} = 565.6854
    opts.Mach (1,1) double = NaN
    opts.psi_deg (1,1) double {mustBeFinite} = 45
    opts.CG_PCT_MAC (1,1) double {mustBeFinite} = 25
    opts.dt (1,1) double {mustBePositive} = 0.01
    opts.tFinal (1,1) double {mustBePositive} = 10
end
ft = 0.3048;
P.data = vital.aircraft.f16.data('CG_PCT_MAC', opts.CG_PCT_MAC);
P.f16 = vital.AircraftModel.fromData(P.data);
P.AC = P.f16.toRuntime();
P.env = struct('g', 32.174 * ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
P.h = opts.h_ft * ft;
atm = vital.env.atmosphere(P.h);
if isnan(opts.Mach)
    P.V = opts.V_ftps * ft;
else
    P.V = opts.Mach * atm.a;
end
P.Mach = P.V / atm.a;
cond = struct('type', 'level', 'V', P.V, 'h', P.h, 'gamma', 0, 'psi', deg2rad(opts.psi_deg));
P.cond = cond;
P.tr = vital.trim.solve(P.AC, P.env, cond);
if ~strcmp(P.tr.status, 'OK')
    error('vital:trim:notOk', 'trim at V = %.4g m/s, h = %.4g m is %s; nothing to simulate.', P.V, P.h, P.tr.status);
end
P.g = P.env.g;
P.m = P.data.mass.massSI();
P.J = P.data.mass.inertiaSI();
P.cbar = P.data.geometry.cbar.si();
P.x0 = P.tr.x(:);
P.u_trim = P.tr.u(:);
P.Vb0 = P.x0(1:3);
P.w0 = P.x0(4:6);
P.eul0 = vital.frames.dcm2eul(vital.frames.quat2dcm(P.x0(7:10)));
P.eul0 = P.eul0(:);
P.Xe0 = P.x0(11:13);
P.dt = opts.dt;
P.tFinal = opts.tFinal;
P.weightOn = 1;
P.du = [0 0 0 0 0; P.tFinal 0 0 0 0];
P.model = fullfile(vital.paths('root'), 'models', 'F16Trim6DOF.slx');
P.trimRef = [P.V; P.tr.alpha; P.tr.theta; P.h];
P.plot = true;
P.plotDir = fullfile(vital.paths('root'), 'reports', 'simulink', 'trim6dof');
end
