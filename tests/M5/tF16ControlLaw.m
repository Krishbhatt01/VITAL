classdef (TestTags = {'M5'}) tF16ControlLaw < vital.test.VitalTestCase
%TF16CONTROLLAW  M5-C: the NESC F-16 control laws F16_control.dml and
%   F16_gnc.dml compiled through vital.daveml.compile (vital.nesc.generateModels
%   -> vital.models.f16.control / gnc), and the controller adapter
%   vital.nesc.f16Controller used by the NESC cases 13.1-13.4, 15 and 16.
%
%   The two files contain NO checkData (docs/nesc/NESC_EXTRACT_F16.md B.4-B.5),
%   so every expectation below is HAND-EVALUATED from the published law
%   (NESC_EXTRACT_F16.md section C, re-read against the DML with an
%   independent MathML-to-infix conversion) with the published gains typed
%   into this file (PUB: F16_control.dml:574-651). Tolerance 1e-12 on
%   quantities of order 1-100: the law is a few additions and products.
%
%   PRE-REGISTERED expectations:
%   1. generatedModelsAreCurrent: regenerating into a temporary folder gives
%      files byte-identical to the committed +vital/+models/+f16/control.m,
%      gnc.m and +vital/+models/+nesc/*.m (REG).
%   2. sasApOffPassesTrimmedControls: sasOn = apOn = 0, no pilot input, trims
%      at their initialValues: el = -25*0.1296382327486013 deg,
%      PWR = 100*0.1390191130965607 %, ail = rdr = 0 (PUB, F16_control.dml
%      initial values; README trim table el -3.2410 deg, PLA 13.9019 %).
%   3. lqrSumsAndMixer (SAS on, AP off; small errors, no limit active):
%        dV = Vequiv - trimmedKEAS, dalpha = alpha - trimmedAlpha,
%        dtheta = theta - trimmedTheta, dphi = phi (phiCmdSw = 0 with AP off)
%        long  = -(K11 dV + K12 dalpha + K13 qb + K14 dtheta), throttle row K2j
%        lat   = -(L11 dphi + L12 beta + L13 pb + L14 rb), dir row L2j
%        el = -25 (longStkTrim + long), PWR = 100 (throttleTrim + throttle),
%        ail = -21.5 lat, rdr = -30 dir + 0.008 ail.
%   4. saturationsAreApplied (minValue/maxValue are saturations, ADR-014):
%      totLongStk clamps at +/-1 (el = -/+25), totThrottle at [0, 1]
%      (PWR 0 / 100), deltaThetaCmd at +/-5 deg, deltaChiCmd at +/-30 deg,
%      phiCmd at +/-30 deg; exact values.
%   5. aileronRudderInterconnect: rdr + 30 totPedal = 0.008 ail (1e-12).
%   6. courseErrorWraps: chiErrUnwrapped = 358 -> chiErr = -2, phiCmd = +20;
%      -358 -> +2, phiCmd = -20; 10 -> 10 (unchanged), phiCmd = -30 (limited).
%   7. gncCircumnavigator (C.3): polar latOffset = 60*6076.12 (90 - lat)
%      - 3*6076.12, baseChiCmd = 90; Equator/IDL: degEFromTgt = lon -/+ 180,
%      N = lat*deg_to_ft, E = degE*deg_to_ft*cos(lat*3.14159265/180),
%      latOffset = hypot(E, N) - 3*6076.12,
%      baseChiCmd = atan2(N, E)*(-180)/3.14159265 (argument order y = N, x = E).
%   8. gncDownstreamEqualsControl: with the same course and offset, the GNC
%      and the control law produce identical surfaces (1e-12).
%   9. missingInputIsAnError: omitting a required input (alpha) raises
%      vital:daveml:missingInput (FC-208).
%   10. adapterHoldsTrimAndSchedulesCommands (vital.nesc.f16Controller; ADR
%      proposals N6/N7 in reports/fragments/nesc/DECISIONS.md): at VITAL's own
%      trim, with AP and SAS on and the LQR reference states replaced by the
%      trim (SIM 5 practice, TM Vol II p.256), the commanded controls equal the
%      trim controls (1e-12 rad, 1e-12 throttle); the altitude command steps by
%      +100 ft at the first sample with t >= 5 s and not before; the output is
%      mapped to [de da dr throttle] in rad and 0..1.
%   11. crossTrackOfRhumbLine: vital.nesc.crossTrack is 0 on the rhumb line
%      through the start point (1e-6 m after 10 km along it) and equals the
%      perpendicular offset for a point displaced 609.6 m (2000 ft) to the
%      right in the local tangent plane (1e-3 m).
%   12. stageFormHoldsTrimAndSteps (registered with ADR N6r, before its first
%      run): the continuous-time form (vital.nesc.f16Controller 'Mode' 'stage',
%      used as AC.stageControl) commands the trim controls at the trim state
%      with the baseline command vector (1e-12 rad / 1e-12), the rotating plant
%      reports them as y.u_applied, and the commands are stepped by
%      vital.sim.stepInput exactly at the TM times: 13.1 +100 ft (channel 1,
%      t = 5 s), 13.2 -5 kt (channel 2, 5 s), 13.3 +15 deg (channel 3, 15 s),
%      13.4 sidestep on (channel 4, 20 s).
%   13. everyLimitIsObservableAndApplied (added after the S5C-4 sabotage
%      survived: saturationsAreApplied drove each clamp to ONE side only, e.g.
%      alpha = +60 gave a large negative longLQR, so min(totLongStk, 1) was
%      never reached). An independent hand evaluator of F16_control.dml
%      (handLaw below; the law of NESC_EXTRACT_F16.md C.2 with every
%      minValue/maxValue as an explicit clamp) is run on 22 input sets, one per
%      limit and side: the four pilot inputs (throttle [0,1], longStk, latStk,
%      pedal +/-1), deltaThetaCmd +/-5, deltaChiCmd +/-30, phiCmd +/-30 and the
%      four mixer totals (totLongStk, totLatStk, totPedal +/-1, totThrottle
%      [0,1]). For each input set (a) OBSERVABILITY is asserted: the hand law
%      with that single limit disabled differs from the hand law with all
%      limits in at least one law variable by > 1e-6; (b) the compiled law must
%      equal the hand law with all limits to 1e-12 in every compared variable.
%      So removing any one clamp from the generated law changes a compared
%      variable and fails (b). The pilot-input clamps are made observable by
%      choosing the LQR term that offsets them (e.g. longStk = 5 with qb such
%      that longLQR = -0.8: the clamped total is 0.33, the unclamped one
%      saturates at 1). No tolerance of the earlier tests is changed; this test
%      only adds coverage. It cannot be RED against a stub (the law exists
%      since the first increment): its sensitivity is demonstrated by the
%      sabotages S5C-4 and S5C-8 ... S5C-12.
%   REVISION of 10 and 12 (ADR N6c, after the case-15 diagnosis): both were
%      registered as "at trim the law commands exactly the trim controls",
%      which is true only for the superseded local-level rates (w_bn = 0 at
%      trim). With Earth-relative rates the trim rates w_be (the transport rate,
%      ~1e-5 rad/s) enter the LQR, as SIM 5's engagement transient shows. The
%      expectation is now the trim plus the hand-evaluated LQR rate terms
%        de = de_trim + 25 K13 qb (deg), throttle = thr_trim - K23 qb,
%        da = -21.5 lat, dr = -30 dir + 0.008 da,
%        lat = -(L13 pb + L14 rb), dir = -(L23 pb + L24 rb)
%      (same 1e-12 tolerances; the gains are the published ones above).

    properties
        Gains
    end

    methods (TestMethodSetup)
        function setup(tc)
            % Published gains, F16_control.dml:574-651 (NESC_EXTRACT_F16.md C.2)
            tc.Gains.K = [-0.063009074230494, 0.113230403179271, 10.113432224566077, 3.154983341632913;
                           0.997260602961658, -0.025467711176391, 1.213308488207827, 0.208744369535208];
            tc.Gains.L = [ 3.078043941515770, 0.032365863044163, 4.557858908828332, 0.589443156647647;
                          -0.705817452754520, -0.256362860634868, -1.073666149713151, 0.822114635953878];
        end
    end

    methods (Access = private)
        function checkTrimPlusRateTerms(tc, u, tr, w, what)
            K = tc.Gains.K; L = tc.Gains.L;
            lon = -K(:, 3) * w(2);
            lat = -(L(:, 3) * w(1) + L(:, 4) * w(3));
            ail = -21.5 * lat(1);
            exp = [tr.u0(1) + deg2rad(-25 * lon(1)); deg2rad(ail); deg2rad(-30 * lat(2) + 0.008 * ail); tr.u0(4) + lon(2)];
            c = [what ': trim + hand-evaluated LQR rate terms (class header, revision)'];
            tc.verifyTol(u(1:3), exp(1:3), 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'de, da, dr', 'Unit', 'rad');
            tc.verifyTol(u(4), exp(4), 1e-12, 'abs', 'ANALYTIC', c, 'Quantity', 'throttle');
        end

        function in = baseInput(~)
            in = struct('throttle', 0, 'longStk', 0, 'latStk', 0, 'pedal', 0, 'sasOn', 0, 'apOn', 0, ...
                'keasCmd', 287.8088596053291, 'altCmd', 10013, 'latOffset', 0, 'baseChiCmd', 45, ...
                'altMsl', 10013, 'Vequiv', 287.8088596053291, 'alpha', 2.653813535191715, 'beta', 0, ...
                'phi', 0, 'theta', 2.653813535191715, 'psi', 45, 'pb', 0, 'qb', 0, 'rb', 0);
        end
    end

    methods (Test)
        function generatedModelsAreCurrent(tc)
            tmp = tempname; mkdir(tmp);
            c = onCleanup(@() rmdir(tmp, 's'));
            vital.nesc.generateModels(tmp);
            root = vital.paths('root');
            list = {fullfile('+vital', '+models', '+f16', 'control.m'), fullfile('+vital', '+models', '+f16', 'gnc.m'), ...
                fullfile('+vital', '+models', '+nesc', 'cannonball_aero.m'), fullfile('+vital', '+models', '+nesc', 'cannonball_inertia.m'), ...
                fullfile('+vital', '+models', '+nesc', 'brick_aero.m'), fullfile('+vital', '+models', '+nesc', 'brick_inertia.m')};
            for k = 1:numel(list)
                a = fileread(fullfile(root, list{k})); b = fileread(fullfile(tmp, list{k}));
                tc.verifyTrue(strcmp(a, b), [list{k} ' differs from a fresh generation (REG)']);
            end
        end

        function sasApOffPassesTrimmedControls(tc)
            o = vital.models.f16.control(tc.baseInput());
            c = 'F16_control.dml trimmed-control initialValues (NESC_EXTRACT_F16.md C.2 consistency check)';
            tc.verifyTol(o.el, -25 * 0.1296382327486013, 1e-12, 'abs', 'PUB', c, 'Quantity', 'el', 'Unit', 'deg');
            tc.verifyTol(o.PWR, 100 * 0.1390191130965607, 1e-12, 'abs', 'PUB', c, 'Quantity', 'PWR', 'Unit', '%');
            tc.verifyTol([o.ail; o.rdr], [0; 0], 1e-15, 'abs', 'PUB', c, 'Quantity', 'ail, rdr', 'Unit', 'deg');
        end

        function lqrSumsAndMixer(tc)
            in = tc.baseInput(); in.sasOn = 1;
            % Inputs corrected after the first GREEN attempt: the original set (Vequiv 290,
            % theta 3.1, ...) drove totLongStk and totThrottle into their limits, which the
            % registered expectation excludes ("no limit active"). Formula and tolerance
            % are unchanged; limits are asserted below so the case stays linear.
            in.Vequiv = 287.9; in.alpha = 2.70; in.theta = 2.68; in.qb = 0.001; in.phi = 0.2; in.beta = 0.05; in.pb = 0.002; in.rb = -0.001;
            o = vital.models.f16.control(in);
            tc.assertTrue(abs(o.totLongStk) < 1 && o.totThrottle > 0 && o.totThrottle < 1 && abs(o.totLatStk) < 1 && abs(o.totPedal) < 1, ...
                'the LQR case must stay inside every limit');
            K = tc.Gains.K; L = tc.Gains.L;
            e = [in.Vequiv - 287.8088596053291; in.alpha - 2.653813535191715; in.qb; in.theta - 2.653813535191715];
            f = [in.phi; in.beta; in.pb; in.rb];
            lon = -K * e; lat = -L * f;
            el = -25 * (0.1296382327486013 + lon(1)); pwr = 100 * (0.1390191130965607 + lon(2));
            ail = -21.5 * lat(1); rdr = -30 * lat(2) + 0.008 * ail;
            c = 'hand evaluation of F16_control.dml LQR, mixer and scaling (NESC_EXTRACT_F16.md C.2)';
            tc.verifyTol([o.el; o.PWR; o.ail; o.rdr], [el; pwr; ail; rdr], 1e-12, 'abs', 'PUB', c, 'Quantity', 'el, PWR, ail, rdr', 'Unit', 'deg, %');
        end

        function saturationsAreApplied(tc)
            c = 'minValue/maxValue are saturations (ADR-014; F16_control.dml:285, 354, 454, 1042-1094)';
            in = tc.baseInput(); in.sasOn = 1; in.alpha = 60;             % huge alpha error: stick to -1 ... +1
            o = vital.models.f16.control(in);
            tc.verifyTol(o.totLongStk, sign(o.longLQR + 0.1296382327486013), 0, 'abs', 'PUB', c, 'Quantity', 'totLongStk limit');
            tc.verifyTol(abs(o.el), 25, 0, 'abs', 'PUB', c, 'Quantity', '|el| at limit', 'Unit', 'deg');
            in = tc.baseInput(); in.sasOn = 1; in.Vequiv = 100;           % far too slow: full throttle
            o = vital.models.f16.control(in);
            tc.verifyTol(o.PWR, 100, 0, 'abs', 'PUB', c, 'Quantity', 'PWR at max', 'Unit', '%');
            in.Vequiv = 500; o = vital.models.f16.control(in);
            tc.verifyTol(o.PWR, 0, 0, 'abs', 'PUB', c, 'Quantity', 'PWR at idle', 'Unit', '%');
            in = tc.baseInput(); in.sasOn = 1; in.apOn = 1; in.altCmd = 11013;   % altErr = -1000 ft -> 50 deg
            o = vital.models.f16.control(in);
            tc.verifyTol(o.deltaThetaCmd, 5, 0, 'abs', 'PUB', c, 'Quantity', 'deltaThetaCmd limit', 'Unit', 'deg');
            in = tc.baseInput(); in.sasOn = 1; in.apOn = 1; in.latOffset = 5000;  % -50 deg -> -30
            o = vital.models.f16.control(in);
            tc.verifyTol(o.deltaChiCmd, -30, 0, 'abs', 'PUB', c, 'Quantity', 'deltaChiCmd limit', 'Unit', 'deg');
            in = tc.baseInput(); in.sasOn = 1; in.apOn = 1; in.baseChiCmd = 35;   % chiErr = +10 -> phiCmd -100 -> -30
            o = vital.models.f16.control(in);
            tc.verifyTol(o.phiCmd, -30, 0, 'abs', 'PUB', c, 'Quantity', 'phiCmd limit', 'Unit', 'deg');
        end

        function everyLimitIsObservableAndApplied(tc)
            K = tc.Gains.K; L = tc.Gains.L;
            kT = 287.8088596053291;
            C = {
                'totLongHi',  struct('alpha', 2.653813535191715 - 60)
                'totLongLo',  struct('alpha', 2.653813535191715 + 60)
                'totThrHi',   struct('Vequiv', 100)
                'totThrLo',   struct('Vequiv', 500)
                'totLatHi',   struct('phi', -20)
                'totLatLo',   struct('phi', 20)
                'totPedHi',   struct('phi', 20)
                'totPedLo',   struct('phi', -20)
                'throttleInHi', struct('throttle', 5, 'Vequiv', kT + 0.5 / K(2,1))
                'throttleInLo', struct('throttle', -5, 'Vequiv', kT - 0.5 / K(2,1))
                'longStkInHi',  struct('longStk', 5, 'qb', 0.8 / K(1,3))
                'longStkInLo',  struct('longStk', -5, 'qb', -0.8 / K(1,3))
                'latStkInHi',   struct('latStk', 5, 'pb', 0.8 / L(1,3))
                'latStkInLo',   struct('latStk', -5, 'pb', -0.8 / L(1,3))
                'pedalInHi',    struct('pedal', 5, 'rb', 0.8 / L(2,4))
                'pedalInLo',    struct('pedal', -5, 'rb', -0.8 / L(2,4))
                'dThetaHi',   struct('apOn', 1, 'altCmd', 11013)
                'dThetaLo',   struct('apOn', 1, 'altCmd', 9013)
                'dChiHi',     struct('apOn', 1, 'latOffset', -5000)
                'dChiLo',     struct('apOn', 1, 'latOffset', 5000)
                'phiCmdHi',   struct('apOn', 1, 'baseChiCmd', 55)
                'phiCmdLo',   struct('apOn', 1, 'baseChiCmd', 35)
                };
            fields = {'throttle', 'longStk', 'latStk', 'pedal', 'deltaThetaCmd', 'deltaChiCmd', 'phiCmd', ...
                'totLongStk', 'totLatStk', 'totPedal', 'totThrottle', 'el', 'ail', 'rdr', 'PWR'};
            for k = 1:size(C, 1)
                in = tc.baseInput(); in.sasOn = 1;
                for f = fieldnames(C{k, 2}).', in.(f{1}) = C{k, 2}.(f{1}); end
                h = handLaw(in, K, L, '');
                hk = handLaw(in, K, L, C{k, 1});
                d = max(abs(cellfun(@(f) h.(f) - hk.(f), fields)));
                tc.assertGreaterThan(d, 1e-6, [C{k, 1} ': the limit is not observable in this input set (the test would not see it removed)']);
                o = vital.models.f16.control(in);
                tc.verifyTol(cellfun(@(f) o.(f), fields), cellfun(@(f) h.(f), fields), 1e-12, 'abs', 'PUB', ...
                    'hand evaluation of F16_control.dml with every minValue/maxValue as a saturation (NESC_EXTRACT_F16.md C.2, B.4)', ...
                    'Quantity', ['all law variables, limit ' C{k, 1}]);
                % F16_gnc.dml carries its own copy of the clamps: the 16 AP-off input sets
                % (the navigator does not enter with AP off) must give the same law there.
                if in.apOn < 0.5
                    g = rmfield(in, {'latOffset', 'baseChiCmd'});
                    g.circlePoleSW = 1; g.ownshipN_deg = 89.9; g.ownshipE_deg = -45;
                    og = vital.models.f16.gnc(g);
                    gf = setdiff(fields, {'deltaChiCmd', 'phiCmd'}, 'stable');
                    tc.verifyTol(cellfun(@(f) og.(f), gf), cellfun(@(f) h.(f), gf), 1e-12, 'abs', 'PUB', ...
                        'hand evaluation of F16_gnc.dml (same law downstream of the navigator, NESC_EXTRACT_F16.md C.3)', ...
                        'Quantity', ['GNC law variables, limit ' C{k, 1}]);
                end
            end
        end

        function aileronRudderInterconnect(tc)
            in = tc.baseInput(); in.sasOn = 1; in.beta = 2; in.phi = 3; in.pb = 0.05;
            o = vital.models.f16.control(in);
            tc.assertGreaterThan(abs(o.ail), 0.1);
            tc.verifyTol(o.rdr + 30 * o.totPedal, 0.008 * o.ail, 1e-12, 'abs', 'PUB', ...
                'aileron-rudder interconnect rdr = -30 totPedal + 0.008 ail (F16_control.dml:1117-1185)', 'Quantity', 'ARI', 'Unit', 'deg');
        end

        function courseErrorWraps(tc)
            c = 'chiErr wrap to +/-180 (F16_control.dml:403-452); phiCmd = -10 chiErr, limited +/-30';
            in = tc.baseInput(); in.sasOn = 1; in.apOn = 1;
            in.psi = 179; in.baseChiCmd = -179; o = vital.models.f16.control(in);
            tc.verifyTol([o.chiErr; o.phiCmd], [-2; 20], 1e-12, 'abs', 'PUB', c, 'Quantity', 'chiErr, phiCmd (+358)', 'Unit', 'deg');
            in.psi = -179; in.baseChiCmd = 179; o = vital.models.f16.control(in);
            tc.verifyTol([o.chiErr; o.phiCmd], [2; -20], 1e-12, 'abs', 'PUB', c, 'Quantity', 'chiErr, phiCmd (-358)', 'Unit', 'deg');
            in.psi = 55; in.baseChiCmd = 45; o = vital.models.f16.control(in);
            tc.verifyTol([o.chiErr; o.phiCmd], [10; -30], 1e-12, 'abs', 'PUB', c, 'Quantity', 'chiErr, phiCmd (10, limited)', 'Unit', 'deg');
        end

        function gncCircumnavigator(tc)
            dft = 60 * 6076.12; R = 3 * 6076.12;
            in = rmfield(tc.baseInput(), {'latOffset', 'baseChiCmd'});
            in.sasOn = 1; in.apOn = 1; in.circlePoleSW = 1; in.ownshipN_deg = 89.9; in.ownshipE_deg = -45;
            o = vital.models.f16.gnc(in);
            c = 'F16_gnc.dml circumnavigator (NESC_EXTRACT_F16.md C.3)';
            tc.verifyTol([o.latOffset; o.baseChiCmd], [dft * (90 - 89.9) - R; 90], 1e-9, 'abs', 'PUB', c, 'Quantity', 'polar offset, course', 'Unit', 'ft, deg');
            in.circlePoleSW = 0;
            for lonE = [-179.95, 179.97]
                in.ownshipN_deg = 0.01; in.ownshipE_deg = lonE;
                o = vital.models.f16.gnc(in);
                if lonE > 0, dE = lonE - 180; else, dE = lonE + 180; end
                N = 0.01 * dft; E = dE * dft * cos(0.01 * 3.14159265 / 180);
                tc.verifyTol([o.latOffset; o.baseChiCmd], [hypot(E, N) - R; atan2(N, E) * (-180) / 3.14159265], 1e-9, 'abs', 'PUB', c, ...
                    'Quantity', sprintf('Equator/IDL offset, course at lon %g', lonE), 'Unit', 'ft, deg');
            end
        end

        function gncDownstreamEqualsControl(tc)
            g = rmfield(tc.baseInput(), {'latOffset', 'baseChiCmd'});
            g.sasOn = 1; g.apOn = 1; g.circlePoleSW = 1; g.ownshipN_deg = 89.93; g.ownshipE_deg = 10;
            g.psi = 80; g.beta = 0.4; g.phi = -5; g.pb = 0.01; g.rb = 0.02; g.qb = -0.01; g.Vequiv = 285; g.altMsl = 9990;
            og = vital.models.f16.gnc(g);
            cIn = rmfield(g, {'circlePoleSW', 'ownshipN_deg', 'ownshipE_deg'});
            cIn.latOffset = og.latOffset; cIn.baseChiCmd = og.baseChiCmd;
            oc = vital.models.f16.control(cIn);
            tc.verifyTol([og.el; og.ail; og.rdr; og.PWR], [oc.el; oc.ail; oc.rdr; oc.PWR], 1e-12, 'abs', 'PUB', ...
                'F16_gnc.dml is F16_control.dml downstream of the navigator (F16_gnc.dml:6-22)', 'Quantity', 'surfaces', 'Unit', 'deg, %');
        end

        function missingInputIsAnError(tc)
            in = rmfield(tc.baseInput(), 'alpha');
            tc.verifyError(@() vital.models.f16.control(in), 'vital:daveml:missingInput');
        end

        function adapterHoldsTrimAndSchedulesCommands(tc)
            tr = vital.nesc.f16Trim(vital.nesc.caseDef('11'), vital.aircraft.f16.config());
            tc.assertEqual(tr.status, 'OK', tr.reason);
            cd = vital.nesc.caseDef('13.1');
            ctl = vital.nesc.f16Controller(cd, tr);
            [~, y] = vital.plant.derivativesRotating(tr.x0, tr.u0, vital.aircraft.f16.config(), cd.env);
            st = ctl.init(tr.x0, tr.u0);
            [u, st] = ctl.step(0, tr.x0, y, tr.u0, st);
            tc.checkTrimPlusRateTerms(u, tr, y.w_be, 'sampled form at trim (revision of 10, ADR N6c)');
            [~, st] = ctl.step(4.98, tr.x0, y, tr.u0, st);
            tc.verifyTol(st.cmd.altCmd, 10013, 1e-6, 'abs', 'ANALYTIC', 'baseline altitude command = trim altitude', 'Quantity', 'altCmd before 5 s', 'Unit', 'ft');
            [~, st] = ctl.step(5.0, tr.x0, y, tr.u0, st);
            tc.verifyTol(st.cmd.altCmd, 10113, 1e-6, 'abs', 'PUB', 'TM Vol II p.63: +100 ft at t = 5 s (first sample t >= 5 s)', 'Quantity', 'altCmd at 5 s', 'Unit', 'ft');
        end

        function stageFormHoldsTrimAndSteps(tc)
            AC = vital.aircraft.f16.config();
            tr = vital.nesc.f16Trim(vital.nesc.caseDef('11'), AC);
            tc.assertEqual(tr.status, 'OK', tr.reason);
            cd = vital.nesc.caseDef('13.1');
            ctl = vital.nesc.f16Controller(cd, tr, 'Mode', 'stage');
            AC.stageControl = ctl.lawFcn;
            [~, y] = vital.plant.derivativesRotating(tr.x0, ctl.u0, AC, cd.env);
            tc.checkTrimPlusRateTerms(y.u_applied, tr, y.w_be, 'stage form at trim (revision of 12, ADR N6c)');
            tc.verifyTol(y.u_command, ctl.u0, 0, 'abs', 'ANALYTIC', 'plant records the command vector', 'Quantity', 'u_command');
            expect = {'13.1', 1, 5, 100; '13.2', 2, 5, -5; '13.3', 3, 15, 15; '13.4', 4, 20, 1};
            for i = 1:size(expect, 1)
                ci = vital.nesc.f16Controller(vital.nesc.caseDef(expect{i, 1}), tr, 'Mode', 'stage');
                tc.assertNumElements(ci.inputs, 1);
                s = ci.inputs{1};
                tc.verifyEqual(s.channel, expect{i, 2}, ['channel of ' expect{i, 1}]);
                tc.verifyTol([s.fcn(expect{i, 3} - 1e-6), s.fcn(expect{i, 3})], [0, expect{i, 4}], 0, 'abs', 'PUB', ...
                    'TM Vol II pp.63-65 command steps', 'Quantity', ['step of ' expect{i, 1}]);
            end
        end

        function crossTrackOfRhumbLine(tc)
            K = vital.geo.constants('wgs84');
            lat0 = deg2rad(36.01916667); lon0 = deg2rad(-75.67444444); chi = deg2rad(45); h = 3052;
            % a point 10 km along the rhumb line: constant course, isometric-latitude straight line
            e = sqrt(K.e2);
            iso = @(p) atanh(sin(p)) - e * atanh(e * sin(p));
            lat = lat0; lon = lon0; ds = 10;
            for k = 1:1000                                    % march 10 km along the loxodrome
                sl = sin(lat); Rm = K.a * (1 - K.e2) / (1 - K.e2 * sl^2)^1.5;
                dlat = ds * cos(chi) / (Rm + h);
                lon = lon + (iso(lat + dlat) - iso(lat)) * tan(chi);   % exact loxodrome relation
                lat = lat + dlat;
            end
            d = vital.nesc.crossTrack(lat, lon, h, lat0, lon0, chi, K);
            tc.verifyTol(d, 0, 1e-6, 'abs', 'ANALYTIC', 'point on the rhumb line through the start point', 'Quantity', 'cross-track', 'Unit', 'm');
            C = vital.geo.dcmEcefToNed(lat0, lon0);
            r0 = vital.geo.lla2ecef(lat0, lon0, h, K);
            off = 609.6 * [-sin(chi); cos(chi); 0];            % 2000 ft to the right of a 45 deg course
            [la, lo] = vital.geo.ecef2lla(r0 + C.' * off, K);
            d2 = vital.nesc.crossTrack(la, lo, h, lat0, lon0, chi, K);
            tc.verifyTol(d2, 609.6, 1e-3, 'abs', 'ANALYTIC', 'perpendicular tangent-plane offset (curvature ~ d^2/2R = 3e-2 m in height only)', ...
                'Quantity', 'cross-track 2000 ft right', 'Unit', 'm');
        end
    end
end

% ---- independent hand evaluation of F16_control.dml ---------------------------------
function y = clampLo(x, lo, nm, kill)
if strcmp(kill, [nm 'Lo']), y = x; else, y = max(x, lo); end
end

function y = clampHi(x, hi, nm, kill)
if strcmp(kill, [nm 'Hi']), y = x; else, y = min(x, hi); end
end

function y = clamp(x, lo, hi, nm, kill)
y = clampHi(clampLo(x, lo, nm, kill), hi, nm, kill);
end

function h = handLaw(in, K, L, kill)
% The law of NESC_EXTRACT_F16.md C.2 with every limit written out. 'kill' names ONE
% limit to disable (e.g. 'totLongHi', 'phiCmdLo', 'throttleInHi'); '' keeps all.
trimTheta = 2.653813535191715; trimAlpha = 2.653813535191715; trimKEAS = 287.8088596053291;
thr0 = 0.1390191130965607; lng0 = 0.1296382327486013;
h.throttle = clamp(in.throttle, 0, 1, 'throttleIn', kill);
h.longStk = clamp(in.longStk, -1, 1, 'longStkIn', kill);
h.latStk = clamp(in.latStk, -1, 1, 'latStkIn', kill);
h.pedal = clamp(in.pedal, -1, 1, 'pedalIn', kill);
fsas = in.sasOn + in.apOn;
h.deltaThetaCmd = clamp((in.altMsl - in.altCmd) * -0.05, -5, 5, 'dTheta', kill);
thetaCmd = h.deltaThetaCmd + trimTheta;
h.deltaChiCmd = clamp(-0.01 * in.latOffset, -30, 30, 'dChi', kill);
chiErrU = (in.beta + in.psi) - (h.deltaChiCmd + in.baseChiCmd);
if abs(chiErrU) > 180
    if chiErrU > 0, chiErr = chiErrU - 360; else, chiErr = chiErrU + 360; end
else
    chiErr = chiErrU;
end
h.phiCmd = clamp(-10 * chiErr, -30, 30, 'phiCmd', kill);
if in.apOn > 0.5
    keasSw = in.keasCmd; thSw = thetaCmd; phSw = h.phiCmd;
else
    keasSw = trimKEAS; thSw = trimTheta; phSw = 0;
end
lon = -K * [in.Vequiv - keasSw; in.alpha - trimAlpha; in.qb; in.theta - thSw];
lat = -L * [in.phi - phSw; in.beta; in.pb; in.rb];
if fsas > 0.5, lonSw = lon; latSw = lat; else, lonSw = [0; 0]; latSw = [0; 0]; end
if in.apOn < 0.5
    pLong = h.longStk; pThr = h.throttle; pLat = h.latStk; pPed = h.pedal;
else
    pLong = 0; pThr = 0; pLat = 0; pPed = 0;
end
h.totLongStk = clamp(lng0 + pLong + lonSw(1), -1, 1, 'totLong', kill);
h.totLatStk = clamp(pLat + latSw(1), -1, 1, 'totLat', kill);
h.totPedal = clamp(pPed + latSw(2), -1, 1, 'totPed', kill);
h.totThrottle = clamp(thr0 + pThr + lonSw(2), 0, 1, 'totThr', kill);
h.el = -25 * h.totLongStk;
h.ail = -21.5 * h.totLatStk;
h.rdr = -30 * h.totPedal + 0.008 * h.ail;
h.PWR = 100 * h.totThrottle;
end
