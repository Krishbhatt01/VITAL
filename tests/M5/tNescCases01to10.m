classdef (TestTags = {'M5'}) tNescCases01to10 < vital.test.VitalTestCase
%TNESCCASES01TO10  M5-C: NESC atmospheric check-cases 1-10 (dropped and
%   ballistic spheres, tumbling bricks) through vital.sim.run with the
%   rotating-Earth plant vital.plant.derivativesRotating.
%
%   Reference: NASA/TM-2015-218675 Vol II and the NESC CSVs (data/nesc,
%   SHA-256 in data/MANIFEST.json). Case definitions, sims and bands come
%   ONLY from docs/NESC_CASE_MATRIX.json (read by vital.nesc.caseDef); VITAL's
%   choices where the TM is silent are the proposed ADRs N1-N11 in
%   reports/fragments/nesc/DECISIONS.md, written before any comparison run:
%     N1 ECEF state [r_e v_e q_be w_bi], ECI = ECEF at t = 0 (TM V2 p.603)
%     N2 J2 or central GRAVITATION in the EOM; localGravity = |gravitation|
%     N3 aerodynamic (brick damping) rates relative to the Earth-fixed airmass
%     N4 initial rates: the matrix's rate_inertial_body_deg_s (XLSX rows 23-25)
%     N8 comparison mechanics (interpolation of VITAL onto each sim's times,
%        angle residuals wrapped to +/-180 deg, truncation to the duration)
%     N9 cases 2/3 start at 30,000 ft (ADR-008); case 1 CD = 0; case 2 all brick
%        coefficients 0; case 3 CD = 0 with the published damping
%     N10 wind Earth-fixed, horizontal: case 7 [0 +20 0] ft/s NED; case 8
%        East = (0.003 h - 20) ft/s, h geometric height above the ellipsoid
%     N11 dt = 0.01 s (RK4); step-size study against dt = 0.02 s
%
%   PRE-REGISTERED expectations:
%   1. caseNN (PUB): for every signal of the case's band list, VITAL lies in
%      [min_s ref_s - delta, max_s ref_s + delta] on the reference time base,
%      delta = max(floor, rel_floor*max|ref|, k*spread) exactly as registered in
%      NESC_CASE_MATRIX.json (ADR-009/015; vital.verify.envelopeCheck). The
%      reported quantity is the worst envelope excess (<= 0 passes).
%   2. everyBandSignalIsAssessable (REG): every band signal of cases 1-10 is
%      recorded by at least one included simulation (no NOT_ASSESSABLE).
%   3. stepSizeStudy (REG, N11): for every case and signal, the change between
%      dt = 0.01 and dt = 0.02 s is at most 10 % of the band half-width delta(t)
%      at every compared reference time. For an integrator of order >= 1 the
%      dt = 0.01 error is then below 10 % of delta.
%   4. initialStateMapping (PUB): case 1 eiPosition_X(0) = 20955646.32545932 ft
%      (tol 1e-6 ft) and eiVelocity_Y(0) = 1528.1098290457676 ft/s (1e-7 ft/s),
%      case 9 eiVelocity(0) = [1000 2525.922194546 0] ft/s (1e-6 ft/s) (CSV sim 5
%      row 0; ECI = ECEF at t = 0); case 2 and 3 start at 30,000 ft (ADR-008).
%   5. referenceHandling (PUB/REG): the sims of case 1 are 1-6; sim 5's
%      duplicated feVelocity_ft_s_Z column is bit-identical to the first; every
%      reference sample used lies in [0, 30] s.
%   6. Failure modes of the comparison (added after the RED run, together
%      with the implementation; they guard behaviour that exists from the
%      first implementation, hence no RED phase):
%      unknownCaseRejected         caseDef('14') -> vital:nesc:unknownCase
%      signalWithoutReferenceIsNotAssessable  a band signal no included sim
%                                  records -> status NOT_ASSESSABLE with a reason
%      shortRunFailsEverySignal    a VITAL run shorter than the duration -> every
%                                  signal FAIL with a reason (never a partial pass)

    properties (Constant)
        Cite = 'NESC Atmos CSVs (TM-2015-218675 Vol II App. D); band NESC_CASE_MATRIX.json (ADR-009)'
    end

    methods (Access = private)
        function checkCase(tc, id)
            res = vital.nesc.runCase(id);
            tc.assertEqual(res.status, 'COMPLETED', sprintf('case %s stopped: %s', id, res.stopReason));
            cmp = vital.nesc.compare(res);
            for c = cmp(:).'
                if strcmp(c.status, 'NOT_ASSESSABLE')
                    tc.verifyFail(sprintf('case %s %s NOT_ASSESSABLE: %s', id, c.signal, c.reason));
                    continue
                end
                tc.verifyWithin(c.worst, -Inf, 0, 'PUB', tc.Cite, ...
                    'Quantity', sprintf('case %s %s envelope excess', id, c.signal), 'Unit', c.unit);
            end
        end
    end

    methods (Test)
        function case01(tc), tc.checkCase('1'); end
        function case02(tc), tc.checkCase('2'); end
        function case03(tc), tc.checkCase('3'); end
        function case04(tc), tc.checkCase('4'); end
        function case05(tc), tc.checkCase('5'); end
        function case06(tc), tc.checkCase('6'); end
        function case07(tc), tc.checkCase('7'); end
        function case08(tc), tc.checkCase('8'); end
        function case09(tc), tc.checkCase('9'); end
        function case10(tc), tc.checkCase('10'); end

        function everyBandSignalIsAssessable(tc)
            for k = 1:10
                id = sprintf('%d', k);
                cd = vital.nesc.caseDef(id);
                ref = vital.nesc.reference(id);
                for b = cd.band(:).'
                    sims = setdiff(cd.sims, b.exclude_sims(:).');
                    has = false;
                    for s = sims
                        j = find([ref.sim] == s, 1);
                        has = has || (~isempty(j) && any(strcmp(ref(j).columns, b.signal)));
                    end
                    tc.verifyTrue(has, sprintf('case %s %s: no included simulation records it (REG)', id, b.signal));
                end
            end
        end

        function stepSizeStudy(tc)
            for k = 1:10
                id = sprintf('%d', k);
                cd = vital.nesc.caseDef(id);
                a = vital.nesc.runCase(id);
                b = vital.nesc.runCase(id, 'dt', cd.study.dt);
                st = vital.nesc.stepStudy(a, b);
                for s = st(:).'
                    tc.verifyWithin(s.ratio, 0, 0.1, 'REG', 'step-size study dt vs 2 dt, class header 3 (proposed ADR N11)', ...
                        'Quantity', sprintf('case %s %s max |d(dt)|/delta', id, s.signal));
                end
            end
        end

        function initialStateMapping(tc)
            ft = 0.3048;
            w = [0; 0; vital.geo.constants('wgs84').omega];
            cd = vital.nesc.caseDef('1');
            s = vital.eom.rotatingToInertial(cd.x0, 0, w(3));
            tc.verifyTol(s.r_i(1) / ft, 20955646.32545932, 1e-6, 'abs', 'PUB', 'Atmos_01_sim_05.csv row 0 eiPosition_ft_X', 'Quantity', 'x_i(0)', 'Unit', 'ft');
            tc.verifyTol(s.v_i(2) / ft, 1528.1098290457676, 1e-7, 'abs', 'PUB', 'Atmos_01_sim_05.csv row 0 eiVelocity_ft_s_Y', 'Quantity', 'vy_i(0)', 'Unit', 'ft/s');
            cd = vital.nesc.caseDef('9');
            s = vital.eom.rotatingToInertial(cd.x0, 0, w(3));
            tc.verifyTol(s.v_i / ft, [1000; 2525.922194546; 0], 1e-6, 'abs', 'PUB', 'Atmos_09_sim_05.csv row 0 eiVelocity', 'Quantity', 'v_i(0)', 'Unit', 'ft/s');
            for id = {'2', '3'}
                cd = vital.nesc.caseDef(id{1});
                tc.verifyTol(cd.ic.h, 30000 * ft, 1e-9, 'abs', 'PUB', 'ADR-008: TM text and every CSV start at 30,000 ft', ...
                    'Quantity', ['case ' id{1} ' initial altitude'], 'Unit', 'm');
            end
        end

        function referenceHandling(tc)
            ref = vital.nesc.reference('1');
            tc.verifyEqual(sort([ref.sim]), 1:6);
            j = find([ref.sim] == 5, 1);
            T = vital.io.readNescCsv('Atmos_01_DroppedSphere', 5);
            names = T.Properties.VariableNames;
            dup = names(startsWith(names, 'feVelocity_ft_s_Z'));
            tc.assertNumElements(dup, 2, 'sim 5 publishes feVelocity_ft_s_Z twice (NESC_EXTRACT_CASES_01_10.md 0.6)');
            tc.verifyTrue(isequal(T.(dup{1}), T.(dup{2})), 'the duplicated sim 5 column is bit-identical (REG)');
            for r = ref(:).'
                tc.verifyTrue(all(r.t >= 0 & r.t <= 30 + 1e-6), sprintf('sim %d samples inside [0, 30] s', r.sim));
            end
            tc.verifyEqual(numel(ref(j).t), 3001);
        end

        function unknownCaseRejected(tc)
            tc.verifyError(@() vital.nesc.caseDef('14'), 'vital:nesc:unknownCase');
        end

        function signalWithoutReferenceIsNotAssessable(tc)
            res = vital.nesc.runCase('1');
            ref = vital.nesc.reference('1');
            for j = 1:numel(ref)                      % remove the column from every sim
                ref(j).columns = setdiff(ref(j).columns, {'mach'}, 'stable');
            end
            cmp = vital.nesc.compare(res, 'Reference', ref);
            c = cmp(strcmp({cmp.signal}, 'mach'));
            tc.verifyEqual(c.status, 'NOT_ASSESSABLE');
            tc.verifySubstring(c.reason, 'mach');
            tc.verifyEqual(sum(strcmp({cmp.status}, 'NOT_ASSESSABLE')), 1);
        end

        function shortRunFailsEverySignal(tc)
            res = vital.nesc.runCase('1', 'tFinal', 10);
            cmp = vital.nesc.compare(res);
            tc.verifyTrue(all(strcmp({cmp.status}, 'FAIL')), 'a 10 s run of a 30 s case must fail every signal');
            tc.verifySubstring(cmp(1).reason, 'duration');
        end

        function runNescCasePrintsComparison(tc)
            % User entry point: run_nesc_case prints one line per band signal with
            % its worst envelope excess and PASS/FAIL, and returns the comparison.
            txt = evalc('r = run_nesc_case(''1'', ''Plot'', false);');
            tc.verifyTrue(contains(txt, 'altitudeMsl_ft') && contains(txt, 'aero_bodyMoment_ftlbf_N'), 'every band signal is printed');
            tc.verifyTrue(contains(txt, 'PASS') || contains(txt, 'FAIL'), 'a verdict is printed');
            tc.verifyEqual(r.id, '1');
            tc.verifyEqual(numel(r.cmp), numel(vital.nesc.caseDef('1').band));
        end
    end
end
