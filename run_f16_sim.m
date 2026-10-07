function out = run_f16_sim(V_ftps, h_ft, opts)
%RUN_F16_SIM  Trim the NESC F-16, apply a control input and simulate (the entry point for users).
%
%   run_f16_sim                           NESC README trim (565.6854 ft/s, 10,013 ft),
%                                         1 deg elevator doublet at 1 s, 10 s
%   run_f16_sim(700, 15000)               trim at any airspeed (ft/s, true) and altitude (ft)
%   run_f16_sim(..., 'Input', 'step', 'Channel', 'aileron', 'Amplitude_deg', 2)
%   run_f16_sim(..., 'Channel', 'throttle', 'Amplitude_pct', 10)
%   run_f16_sim(..., 'Plot', true)        plot the time histories
%   out = run_f16_sim(...)                returns the vital.sim.run output plus
%                                         out.trim (the trimLevel result) and out.input
%
%   Options
%     'CG' (% MAC, 25), 'g_ftps2' (32.174), 'gamma_deg' (0)  trim condition, as in
%                     vital.aircraft.f16.trimLevel
%     'Input'         'doublet' | 'step' | 'none'                     (default 'doublet')
%     'Channel'       'elevator' | 'aileron' | 'rudder' | 'throttle'  (default 'elevator')
%     'Amplitude_deg' surface amplitude, deg (+TED elevator, +right-TED-down aileron,
%                     +TEL rudder; CONVENTIONS 7)                     (default 1)
%     'Amplitude_pct' throttle amplitude, % power lever angle points  (default 5)
%     'Start_s'       input start (s, a multiple of dt)               (default 1)
%     'Width_s'       doublet half-width (s, a multiple of dt)        (default 0.5)
%     'Duration_s'    simulated time (s)                               (default 10)
%     'dt'            RK4 step (s)                                     (default 0.01)
%     'Guards'        passed to vital.sim.run (default guards: alpha/beta table
%                     range, |q| drift, ground)
%     'Plot'          true to plot                                    (default false)
%     'Quiet'         true to suppress the printed summary            (default false)
%
%   A trim whose status is not OK (e.g. INFEASIBLE at 150 ft/s: stall-limited)
%   is reported and NOT simulated: out.status = 'NOT_SIMULATED', out.trim.
%   A simulation that a guard stops is reported with its stop reason and time
%   (status STOPPED; see vital.sim.run). Works from any MATLAB session: it
%   puts VITAL on the path itself.
arguments
    V_ftps (1,1) double = 565.6854
    h_ft (1,1) double = 10013
    opts.CG (1,1) double = 25
    opts.g_ftps2 (1,1) double = 32.174
    opts.gamma_deg (1,1) double = 0
    opts.Input (1,:) char = 'doublet'
    opts.Channel (1,:) char = 'elevator'
    opts.Amplitude_deg (1,1) double = 1
    opts.Amplitude_pct (1,1) double = 5
    opts.Start_s (1,1) double = 1
    opts.Width_s (1,1) double = 0.5
    opts.Duration_s (1,1) double = 10
    opts.dt (1,1) double = 0.01
    opts.Guards (1,1) struct = struct()
    opts.Plot (1,1) logical = false
    opts.Quiet (1,1) logical = false
end
addpath(fileparts(mfilename('fullpath')));
channels = {'elevator', 'aileron', 'rudder', 'throttle'};
ch = find(strcmpi(opts.Channel, channels), 1);
if isempty(ch)
    error('vital:badInput', 'Channel must be one of %s.', strjoin(channels, ', '));
end
if ~any(strcmpi(opts.Input, {'doublet', 'step', 'none'}))
    error('vital:badInput', 'Input must be doublet, step or none.');
end
ft = vital.units.constants().ft;
say = @(varargin) printIf(~opts.Quiet, varargin{:});

r = vital.aircraft.f16.trimLevel(V_ftps, h_ft, 'CG', opts.CG, 'g_ftps2', opts.g_ftps2, 'gamma_deg', opts.gamma_deg);
say('F-16 simulation  trim V = %.4f ft/s  h = %.0f ft  CG = %.1f %% MAC  gamma = %.2f deg\n', ...
    V_ftps, h_ft, opts.CG, opts.gamma_deg);
say('  trim status   %s %s\n', r.status, r.reason);
if ~strcmp(r.status, 'OK')
    say('  trim is not OK (%s): not simulated.\n', r.status);
    out = struct('status', 'NOT_SIMULATED', 'reason', sprintf('trim status %s: %s', r.status, r.reason), 'trim', r);
    if nargout == 0, clear out; end
    return
end

AC = vital.aircraft.f16.config('CG_PCT_MAC', opts.CG);
env = struct('g', opts.g_ftps2 * ft, 'wind_n', [0; 0; 0], 'deltaT', 0);
if ch == 4
    amp = opts.Amplitude_pct / 100; ampTxt = sprintf('%g %% PLA', opts.Amplitude_pct);
else
    amp = deg2rad(opts.Amplitude_deg); ampTxt = sprintf('%g deg', opts.Amplitude_deg);
end
switch lower(opts.Input)
    case 'doublet'
        in = vital.sim.doublet(opts.Start_s, opts.Width_s, amp, ch);
        inTxt = sprintf('%s doublet %s, start %g s, half-width %g s', channels{ch}, ampTxt, opts.Start_s, opts.Width_s);
    case 'step'
        in = vital.sim.stepInput(opts.Start_s, amp, ch);
        inTxt = sprintf('%s step %s at %g s', channels{ch}, ampTxt, opts.Start_s);
    otherwise
        in = []; inTxt = 'none (trim hold)';
end
out = vital.sim.run(AC, env, r.trim.x, r.trim.u, 'dt', opts.dt, 'tFinal', opts.Duration_s, ...
    'Inputs', in, 'Guards', opts.Guards);
out.trim = r;
out.input = inTxt;

y = out.y;
say('  input         %s\n', inTxt);
say('  run           %s   stop reason: %s   t = %.2f s of %.2f s  (dt = %g s, %d plant calls, %.1f s wall)\n', ...
    out.status, ifEmpty(out.stopReason, 'none'), out.stopTime, opts.Duration_s, opts.dt, out.nPlantCalls, out.wallTime_s);
if ~isempty(out.stopDetail.message)
    say('                %s\n', out.stopDetail.message);
end
if isfield(y, 'V')
    say('  %-14s %11s %11s %11s %11s\n', 'quantity', 'initial', 'final', 'min', 'max');
    rows = {'alpha (deg)', rad2deg(y.alpha); 'beta (deg)', rad2deg(y.beta); ...
        'q (deg/s)', rad2deg(y.q); 'p (deg/s)', rad2deg(y.p); 'r (deg/s)', rad2deg(y.r); ...
        'theta (deg)', rad2deg(y.theta); 'phi (deg)', rad2deg(y.phi); ...
        'V (ft/s)', y.V / ft; 'altitude (ft)', y.h / ft; 'Mach', y.mach; 'nz (g)', y.nz};
    for i = 1:size(rows, 1)
        v = rows{i, 2};
        say('  %-14s %11.4f %11.4f %11.4f %11.4f\n', rows{i, 1}, v(1), v(end), min(v), max(v));
    end
end
if out.outOfEnvelope.ever
    say('  tables clamped (outside the NASA data) first at t = %.2f s\n', out.outOfEnvelope.firstTime);
end
if out.controlLimit.ever
    c = out.controlLimit;
    if strcmp(c.channel, 'throttle'), f = 100; un = '%'; else, f = 180/pi; un = 'deg'; end
    say('  command beyond its limit (not clipped): %s = %.3f %s outside [%.3f %.3f] first at t = %.2f s\n', ...
        c.channel, f * c.value, un, f * c.limit(1), f * c.limit(2), c.firstTime);
end
if opts.Plot, plotRun(out, ft); end
if nargout == 0, clear out; end
end

function printIf(on, varargin)
if on, fprintf(varargin{:}); end
end

function s = ifEmpty(s, alt)
if isempty(s), s = alt; end
end

function plotRun(out, ft)
y = out.y; t = out.t;
figure('Name', 'VITAL F-16 simulation');
sp = {@() plot(t, rad2deg(y.alpha)), 'alpha (deg)'; @() plot(t, rad2deg(y.q)), 'q (deg/s)'; ...
    @() plot(t, y.V / ft), 'V (ft/s)'; @() plot(t, y.h / ft), 'h (ft)'; ...
    @() plot(t, rad2deg(y.theta)), 'theta (deg)'; @() plot(t, y.nz), 'n_z (g)'; ...
    @() plot(t, rad2deg([y.p; y.r])), 'p, r (deg/s)'; @() plot(t, [rad2deg(out.u(1:3, :)); 100*out.u(4, :)]), 'de da dr (deg), PLA (%)'};
for i = 1:size(sp, 1)
    subplot(4, 2, i); sp{i, 1}(); grid on; ylabel(sp{i, 2}); xlabel('t (s)');
end
end
