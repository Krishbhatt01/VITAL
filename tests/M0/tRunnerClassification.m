classdef (TestTags = {'M0'}) tRunnerClassification < matlab.unittest.TestCase
%TRUNNERCLASSIFICATION  M0: the RED/GREEN gate logic.
%   A RED gate is valid only when every failing test fails because the
%   feature is not implemented yet (vital:notImplemented). Any other error
%   is RED-unexpected and invalidates the gate; an ordinary assertion
%   failure is RED-suspicious; a new test that already passes is VACUOUS;
%   an earlier-milestone test that fails is a REGRESSION.

    properties
        Fixtures
    end

    methods (TestClassSetup)
        function locate(tc)
            tc.Fixtures = fullfile(vital.paths('root'), 'tests', 'fixtures');
        end
    end

    methods (Access = private)
        function [rows, summary] = classifyFixtures(tc, milestone, phase)
            suite = [matlab.unittest.TestSuite.fromFile(fullfile(tc.Fixtures, 'fxClassifyNew.m')), ...
                     matlab.unittest.TestSuite.fromFile(fullfile(tc.Fixtures, 'fxClassifyOld.m'))];
            runner = matlab.unittest.TestRunner.withNoPlugins;
            runner.addPlugin(matlab.unittest.plugins.DiagnosticsRecordingPlugin);
            results = runner.run(suite);
            [rows, summary] = vital.test.classifyResults(suite, results, milestone, phase);
        end

        function c = classOf(~, rows, name)
            c = string(rows(endsWith(string({rows.name}), "/" + name)).class);
        end
    end

    methods (Test)
        function notImplementedIsRedExpected(tc)
            rows = tc.classifyFixtures('M1', 'red');
            tc.verifyEqual(tc.classOf(rows, 'errorsNotImplemented'), "RED_EXPECTED");
        end

        function otherErrorIsRedUnexpected(tc)
            rows = tc.classifyFixtures('M1', 'red');
            tc.verifyEqual(tc.classOf(rows, 'errorsOther'), "RED_UNEXPECTED");
        end

        function verifyErrorCatchingNotImplementedIsExpected(tc)
            rows = tc.classifyFixtures('M1', 'red');
            tc.verifyEqual(tc.classOf(rows, 'verifyErrorSeesNotImplemented'), "RED_EXPECTED");
        end

        function assertionWithoutNotImplementedIsSuspicious(tc)
            rows = tc.classifyFixtures('M1', 'red');
            tc.verifyEqual(tc.classOf(rows, 'failsVerify'), "RED_SUSPICIOUS");
        end

        function passingNewTestInRedIsVacuous(tc)
            rows = tc.classifyFixtures('M1', 'red');
            tc.verifyEqual(tc.classOf(rows, 'passes'), "VACUOUS");
        end

        function earlierMilestonePassIsPass(tc)
            rows = tc.classifyFixtures('M1', 'red');
            tc.verifyEqual(tc.classOf(rows, 'passesOld'), "PASS");
        end

        function earlierMilestoneFailureIsRegression(tc)
            rows = tc.classifyFixtures('M1', 'red');
            tc.verifyEqual(tc.classOf(rows, 'failsOld'), "REGRESSION");
        end

        function redGateInvalidOnUnexpectedOrRegression(tc)
            [~, s] = tc.classifyFixtures('M1', 'red');
            tc.verifyFalse(s.gateOK);
            tc.verifyEqual(s.counts.RED_UNEXPECTED, 1);
            tc.verifyEqual(s.counts.REGRESSION, 1);
            tc.verifyEqual(s.counts.RED_EXPECTED, 2);
        end

        function greenGateRequiresZeroFailures(tc)
            [rows, s] = tc.classifyFixtures('M1', 'green');
            tc.verifyFalse(s.gateOK);
            nFail = sum(string({rows.class}) == "FAIL");
            tc.verifyEqual(nFail, 5, 'every non-passing fixture counts as FAIL in a green run');
        end

        function milestoneSelectionIsCumulative(tc)
            suite = matlab.unittest.TestSuite.fromFile(fullfile(tc.Fixtures, 'fxTagSelection.m'));
            sel = vital.test.selectMilestone(suite, 'M2', 'IncludeFixtures', true);
            got = sort(extractAfter(string({sel.Name}), '/'));
            tc.verifyEqual(got, ["inM0","inM1","inM2"]);
        end

        function milestoneTagM1DoesNotMatchM10(tc)
            suite = matlab.unittest.TestSuite.fromFile(fullfile(tc.Fixtures, 'fxTagSelection.m'));
            sel = vital.test.selectMilestone(suite, 'M1', 'IncludeFixtures', true);
            tc.verifyFalse(any(endsWith(string({sel.Name}), 'inM10')));
        end

        function fixturesExcludedByDefault(tc)
            suite = matlab.unittest.TestSuite.fromFile(fullfile(tc.Fixtures, 'fxTagSelection.m'));
            sel = vital.test.selectMilestone(suite, 'M10');
            tc.verifyEmpty(sel);
        end

        function badMilestoneNameErrors(tc)
            suite = matlab.unittest.TestSuite.fromFile(fullfile(tc.Fixtures, 'fxTagSelection.m'));
            tc.verifyError(@() vital.test.selectMilestone(suite, 'milestone2'), 'vital:test:badMilestone');
        end

        function reportsWrittenAndCountsMatch(tc)
            out = tempname; mkdir(out);
            cleanup = onCleanup(@() rmdir(out, 's'));
            s = run_vital_tests('M1', 'Phase', 'red', 'Folder', tc.Fixtures, ...
                'IncludeFixtures', true, 'ReportDir', out, 'Quiet', true);
            for ext = [".txt", ".json", ".xml"]
                tc.verifyTrue(isfile(fullfile(out, "M1_red" + ext)), "missing report M1_red" + ext);
            end
            j = jsondecode(fileread(fullfile(out, 'M1_red.json')));
            tc.verifyEqual(numel(j.tests), s.total);
            tc.verifyEqual(j.summary.total, s.total);
            tc.verifyFalse(j.summary.gateOK);
        end
    end
end
