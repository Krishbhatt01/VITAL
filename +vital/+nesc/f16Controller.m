function ctl = f16Controller(cd, tr, opts)
%F16CONTROLLER  The NESC F-16 control law (F16_control.dml or F16_gnc.dml) as a
%   VITAL controller, in two forms.
%   ctl = vital.nesc.f16Controller(cd, tr)                      'sampled' (default)
%   ctl = vital.nesc.f16Controller(cd, tr, 'Mode', 'stage')     continuous-time form
%   ctl = vital.nesc.f16Controller(..., 'tFinal', T)            preallocate the sampled log
%     cd  case definition (vital.nesc.caseDef) with cd.controller:
%         kind 'control' | 'gnc', rate_hz (sampled form), steps (field, t, delta),
%         sidestep (t, offset_ft) for case 13.4, circlePoleSW (gnc), baseChi_deg,
%         recovered
%     tr  the NESC-environment trim (vital.nesc.f16Trim)
%
%   'sampled': ctl = struct(rate_hz, init, step, info), the vital.sim.run
%     Controller (zero-order hold at rate_hz). step(t, x, y, u_ref, st) returns
%     u = [de da dr throttle] and logs the commands in st.log (st.k samples).
%   'stage': the law has no dynamic states (NESC_EXTRACT_F16.md C.4), so its
%     continuous-time form is an algebraic feedback evaluated at EVERY plant
%     evaluation. ctl.lawFcn(sig, ucmd) is used as AC.stageControl of
%     vital.plant.derivativesRotating; the plant input is then the command
%     vector ucmd = [altCmd_ft; keasCmd_kt; baseChiCmd_deg; sidestepOn], with
%     ctl.u0 the baseline and ctl.inputs the vital.sim.stepInput steps
%     (switch times on step boundaries: exact timing, t >= t_step).
%     ctl.commands(out) rebuilds the command history of a run.
%   Signal mapping (both forms; proposed ADRs N6, N6b, N7):
%     inputs   altMsl ft, Vequiv = KEAS (vital.nesc.equivalentAirspeed), alpha,
%              beta, phi, theta, psi deg, pb qb rb = body rates relative to the
%              Earth (w_be, rad/s: the same bodyAngularRate the aero model gets,
%              ADR N6c; cd.controller.rateFrame 'bn' | 'be' | 'bi' selects another
%              frame, diagnostics only); gnc: geodetic lat/lon deg
%     trim     trimmedPilotControl_long = -de_trim/25 deg, _throttle = throttle_trim;
%              LQR reference states replaced by the trim through exact input
%              shifts alpha - alpha_trim + trimmedAlpha, theta - theta_trim +
%              trimmedTheta (and, AP off only, Vequiv - KEAS_trim + trimmedKEAS)
%     commands AP and SAS on; baseline altitude = trim altitude, KEAS = trim
%              KEAS, course = cd.controller.baseChi_deg, lateral offset 0;
%              13.4: latOffset = crossTrack - offset once the sidestep is on,
%              the cross track from the rhumb line through the initial
%              position at the base course (vital.nesc.crossTrack)
%     outputs  u = [el; ail; rdr] deg -> rad (NESC signs equal VITAL's,
%              CONVENTIONS 7; tF16Plant), throttle = PWR/100
arguments
    cd (1,1) struct
    tr (1,1) struct
    opts.Mode (1,:) char {mustBeMember(opts.Mode, {'sampled', 'stage'})} = 'sampled'
    opts.tFinal (1,1) double = NaN
end
spec = cd.controller;
if isempty(spec)
    error('vital:badInput', 'case %s has no controller.', cd.id);
end
k = vital.units.constants();
K = vital.geo.constants(cd.env.earth);
switch spec.kind
    case 'control', law = @vital.models.f16.control;
    case 'gnc',     law = @vital.models.f16.gnc;
    otherwise, error('vital:badInput', 'unknown control law %s.', spec.kind);
end
inBase = baseInput(spec, tr);          % built once; evalLaw copies it (pure overhead saving)
probe = inBase;
if strcmp(spec.kind, 'gnc'), probe.ownshipN_deg = 0; probe.ownshipE_deg = 0; end
c0 = law(probe);
dml = struct('alpha', c0.trimmedAlpha, 'theta', c0.trimmedTheta, 'keas', c0.trimmedKEAS);
base = struct('altCmd', tr.h_ft, 'keasCmd', tr.keas, 'baseChiCmd', spec.baseChi_deg, 'latOffset', 0);
[lat0, lon0] = vital.geo.ecef2lla(tr.x0(1:3), K);
alphaTrim = rad2deg(tr.alpha); thetaTrim = rad2deg(tr.theta);
rateField = 'w_be';                                   % ADR N6b2: Earth-relative body rates
if isfield(spec, 'rateFrame'), rateField = ['w_' spec.rateFrame]; end
info = struct('kind', spec.kind, 'mode', opts.Mode, 'dmlReference', dml, 'baseCommands', base, 'recovered', spec.recovered);

if strcmp(opts.Mode, 'sampled')
    T = opts.tFinal; if isnan(T), T = cd.duration; end
    nLog = ceil(T * spec.rate_hz - 1e-9) + 1;
    ctl.rate_hz = spec.rate_hz;
    ctl.init = @init;
    ctl.step = @step;
    ctl.info = info;
else
    ctl.lawFcn = @lawFcn;
    ctl.u0 = [base.altCmd; base.keasCmd; base.baseChiCmd; 0];
    names = {'altCmd', 'keasCmd', 'baseChiCmd'};
    ctl.inputs = {};
    for s = spec.steps(:).'
        ctl.inputs{end+1} = vital.sim.stepInput(s.t, s.delta, find(strcmp(names, s.field)));
    end
    if ~isempty(spec.sidestep)
        ctl.inputs{end+1} = vital.sim.stepInput(spec.sidestep.t, 1, 4);
    end
    ctl.commands = @commands;
    ctl.info = info;
end

    function st = init(x0, u0) %#ok<INUSD>
        z = zeros(1, nLog);
        st = struct('k', 0, 'cmd', base, 'last', [], ...
            'log', struct('t', z, 'altCmd_ft', z, 'keasCmd', z, 'baseChiCmd_deg', z, 'latOffset_ft', z));
    end

    function [u, st] = step(t, x, y, uref, st) %#ok<INUSL>
        cmd = base;
        for s = spec.steps(:).'
            if t >= s.t - 1e-9, cmd.(s.field) = cmd.(s.field) + s.delta; end
        end
        on = ~isempty(spec.sidestep) && t >= spec.sidestep.t - 1e-9;
        [u, o, cmd] = evalLaw(y, cmd, on);
        st.cmd = cmd; st.last = o;
        n = st.k + 1;
        if n <= nLog
            st.log.t(n) = t; st.log.altCmd_ft(n) = cmd.altCmd; st.log.keasCmd(n) = cmd.keasCmd;
            st.log.baseChiCmd_deg(n) = cmd.baseChiCmd; st.log.latOffset_ft(n) = cmd.latOffset;
            st.k = n;
        end
    end

    function u = lawFcn(sig, ucmd)
        cmd = base;
        cmd.altCmd = ucmd(1); cmd.keasCmd = ucmd(2); cmd.baseChiCmd = ucmd(3);
        u = evalLaw(sig, cmd, ucmd(4) > 0.5);
    end

    function c = commands(out)
        U = out.u;
        c.t = out.t; c.altCmd_ft = U(1, :); c.keasCmd = U(2, :); c.baseChiCmd_deg = U(3, :);
        c.latOffset_ft = zeros(size(c.t));
        for i = find(U(4, :) > 0.5)
            c.latOffset_ft(i) = offsetFt(out.y.lat(i), out.y.lon(i), out.y.h(i));
        end
        c.recovered = spec.recovered;
    end

    function d = offsetFt(la, lo, hh)
        d = vital.nesc.crossTrack(la, lo, hh, lat0, lon0, deg2rad(spec.baseChi_deg), K) / k.ft - spec.sidestep.offset_ft;
    end

    function [u, o, cmd] = evalLaw(y, cmd, sidestepOn)
        if sidestepOn, cmd.latOffset = offsetFt(y.lat, y.lon, y.h); end
        in = inBase;
        in.keasCmd = cmd.keasCmd; in.altCmd = cmd.altCmd;
        in.altMsl = y.h / k.ft;
        keas = vital.nesc.equivalentAirspeed(y.V, y.rho) / k.kt;
        in.Vequiv = keas;
        if in.apOn < 0.5, in.Vequiv = keas - tr.keas + dml.keas; end
        in.alpha = rad2deg(y.alpha) - alphaTrim + dml.alpha;
        in.beta = rad2deg(y.beta);
        in.phi = rad2deg(y.phi);
        in.theta = rad2deg(y.theta) - thetaTrim + dml.theta;
        in.psi = rad2deg(y.psi);
        w = y.(rateField);
        in.pb = w(1); in.qb = w(2); in.rb = w(3);
        if strcmp(spec.kind, 'control')
            in.latOffset = cmd.latOffset; in.baseChiCmd = cmd.baseChiCmd;
        else
            in.ownshipN_deg = rad2deg(y.lat); in.ownshipE_deg = rad2deg(y.lon);
        end
        o = law(in);
        if strcmp(spec.kind, 'gnc')
            cmd.latOffset = o.latOffset; cmd.baseChiCmd = o.baseChiCmd;
        end
        u = [deg2rad(o.el); deg2rad(o.ail); deg2rad(o.rdr); o.PWR / 100];
    end
end

function in = baseInput(spec, tr)
in = struct('throttle', 0, 'longStk', 0, 'latStk', 0, 'pedal', 0, 'sasOn', 1, 'apOn', 1, ...
    'keasCmd', tr.keas, 'altCmd', tr.h_ft, 'altMsl', tr.h_ft, 'Vequiv', tr.keas, 'alpha', 0, 'beta', 0, ...
    'phi', 0, 'theta', 0, 'psi', 0, 'pb', 0, 'qb', 0, 'rb', 0, ...
    'throttleTrim', tr.throttle, 'longStkTrim', -rad2deg(tr.de) / 25);
if strcmp(spec.kind, 'gnc')
    in.circlePoleSW = spec.circlePoleSW;
else
    in.latOffset = 0; in.baseChiCmd = spec.baseChi_deg;
end
end
