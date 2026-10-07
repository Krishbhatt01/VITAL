classdef (TestTags = {'M5'}) tAxisChecks < vital.test.VitalTestCase
%TAXISCHECKS  Visual axis checks (run_axis_checks, vital.viz.axisChecks), added
%   2026-10-06 on the user's request: vector plots that show the frames,
%   rotations, translations and the CG bookkeeping behave as CONVENTIONS.md
%   says, with every plotted case carrying numeric checks against an
%   INDEPENDENT reference (a hand-built closed form or the Aerospace Toolbox),
%   never against the function that produced the plotted vector.
%
%   PRE-REGISTERED (written before vital.viz.axisChecks exists):
%     1. 13 cases, every check passes, and each check names its reference
%        (ANALYTIC or INDEP) in field 'ref'.
%     2. Cases, in order:
%          yaw 30, pitch 20, roll 40, combined 3-2-1, level-flight velocity,
%          climb velocity, sideslip and wind, gravity in body axes, CG and
%          reference points (BFRP), station-to-body, control moment signs,
%          simulated flight path, NED on the rotating Earth.
%     3. With 'Plot', true the tool draws one figure per case and, with
%        'SaveDir', writes one non-empty PNG per case.
%     4. vital.viz.checkItem: inside the tolerance passes, outside fails, a
%        non-finite value fails, a logical check fails when false.
%     5. run_axis_checks prints one PASS/FAIL line per case and an overall verdict.
%   Sabotages (tests/M5/sabotages_axis.json) prove the plotted checks are not
%   vacuous: a pitch-matrix sign, the station flip, the CG moment transfer and
%   the ECEF-to-NED down row must each turn this class RED.

    methods (Test)
        function allCasesPassWithIndependentReferences(tc)
            R = vital.viz.axisChecks('Plot', false);
            tc.verifyEqual(numel(R.cases), 13, 'number of cases');
            names = {'yaw', 'pitch', 'roll', 'combined', 'level', 'climb', 'sideslip', ...
                'gravity', 'cg', 'station', 'control', 'path', 'earth'};
            for k = 1:numel(R.cases)
                c = R.cases(k);
                tc.verifyEqual(c.id, names{k}, sprintf('case %d id', k));
                tc.verifyNotEmpty(c.checks, [c.id ': no checks']);
                for j = 1:numel(c.checks)
                    ch = c.checks(j);
                    tc.verifyTrue(ismember(ch.ref, {'ANALYTIC', 'INDEP'}), ...
                        sprintf('%s / %s: reference "%s" is not ANALYTIC or INDEP', c.id, ch.what, ch.ref));
                    tc.verifyTrue(ch.pass, sprintf('%s / %s: value %s, expected %s, tol %g', ...
                        c.id, ch.what, mat2str(ch.value, 6), mat2str(ch.expected, 6), ch.tol));
                end
            end
            tc.verifyTrue(R.allPass);
        end

        function plotsAreDrawnAndSaved(tc)
            d = tempname; mkdir(d); cl = onCleanup(@() rmdir(d, 's'));
            R = vital.viz.axisChecks('Plot', true, 'Visible', false, 'SaveDir', d);
            closer = onCleanup(@() close([R.cases.figure]));
            tc.verifyEqual(numel([R.cases.figure]), 13);
            png = dir(fullfile(d, '*.png'));
            tc.verifyEqual(numel(png), 13, 'one PNG per case');
            tc.verifyTrue(all([png.bytes] > 5000), 'PNG files are not empty');
        end

        function checkItemSemantics(tc)
            a = vital.viz.checkItem('inside', 1.0 + 1e-10, 1.0, 1e-9, 'ANALYTIC');
            b = vital.viz.checkItem('outside', 1.0 + 1e-8, 1.0, 1e-9, 'ANALYTIC');
            c = vital.viz.checkItem('nan', NaN, 1.0, 1e-9, 'ANALYTIC');
            d = vital.viz.checkItem('sign true', true, true, 0, 'ANALYTIC');
            e = vital.viz.checkItem('sign false', false, true, 0, 'ANALYTIC');
            f = vital.viz.checkItem('vector', [1 2 3] + 1e-13, [1 2 3], 1e-12, 'INDEP');
            tc.verifyTrue(a.pass); tc.verifyFalse(b.pass); tc.verifyFalse(c.pass);
            tc.verifyTrue(d.pass); tc.verifyFalse(e.pass); tc.verifyTrue(f.pass);
            tc.verifyError(@() vital.viz.checkItem('x', 1, 1, 0, 'PUB?'), 'vital:badInput');
        end

        function entryPointPrintsVerdict(tc)
            d = tempname; mkdir(d); cl = onCleanup(@() rmdir(d, 's'));
            txt = evalc('R = run_axis_checks(''Plot'', false, ''SaveDir'', d);');
            tc.verifyTrue(R.allPass);
            tc.verifyEqual(count(txt, 'PASS'), 14, '13 case lines + the overall verdict');
            tc.verifySubstring(txt, 'ALL AXIS CHECKS PASS');
        end
    end
end
