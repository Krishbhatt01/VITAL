classdef (TestTags = {'M0'}) tVitalTestCase < matlab.unittest.TestCase
%TVITALTESTCASE  M0: the provenance-recording check methods behave exactly
%   as specified. Runs the fxVitalTol fixture as a nested suite and inspects
%   each outcome and each logged provenance record.

    properties
        Results      % TestResult array of the nested fixture run
        Records      % provenance records logged during that run
    end

    methods (TestClassSetup)
        function runFixture(tc)
            fixtures = fullfile(vital.paths('root'), 'tests', 'fixtures');
            suite = matlab.unittest.TestSuite.fromFile(fullfile(fixtures, 'fxVitalTol.m'));
            runner = matlab.unittest.TestRunner.withNoPlugins;
            runner.addPlugin(matlab.unittest.plugins.DiagnosticsRecordingPlugin);
            outer = vital.test.provenance('get');      % keep the gate run's own log
            vital.test.provenance('clear');
            tc.Results = runner.run(suite);
            tc.Records = vital.test.provenance('get');
            vital.test.provenance('set', outer);
        end
    end

    methods (Access = private)
        function r = result(tc, name)
            names = arrayfun(@(x) extractAfter(x.Name, '/'), tc.Results, 'UniformOutput', false);
            r = tc.Results(strcmp(names, name));
            tc.assertNumElements(r, 1, sprintf('fixture test "%s" not found', name));
        end

        function rec = recordFor(tc, name)
            tests = arrayfun(@(x) string(x.test), tc.Records);
            rec = tc.Records(endsWith(tests, name));
        end
    end

    methods (Test)
        function passingCheckPasses(tc)
            tc.verifyTrue(tc.result('absPass').Passed);
        end

        function failingCheckFails(tc)
            r = tc.result('absFail');
            tc.verifyTrue(r.Failed && ~r.Incomplete, 'absFail must fail as a verification, not an error');
        end

        function nanVsNanFails(tc)
            tc.verifyTrue(tc.result('nanVsNan').Failed, 'NaN vs NaN must fail verifyTol');
        end

        function infActualFails(tc)
            tc.verifyTrue(tc.result('infActual').Failed);
        end

        function badSourceErrors(tc)
            r = tc.result('badSource');
            tc.verifyTrue(r.Failed);
            tc.verifyTrue(vital.test.resultMentions(r, 'vital:test:badSource'), ...
                'bad source tag must raise vital:test:badSource');
        end

        function badModeErrors(tc)
            r = tc.result('badMode');
            tc.verifyTrue(r.Failed);
            tc.verifyTrue(vital.test.resultMentions(r, 'vital:test:badMode'));
        end

        function absModeIgnoresRelTolerance(tc)
            tc.verifyTrue(tc.result('absIgnoresRel').Failed, 'abs mode must not fall back to a relative tolerance');
            tc.verifyTrue(tc.result('relPass').Passed);
        end

        function relModeRejectsZeroExpected(tc)
            r = tc.result('relZeroExpected');
            tc.verifyTrue(r.Failed);
            tc.verifyTrue(vital.test.resultMentions(r, 'vital:test:relZeroExpected'));
        end

        function withinAndExact(tc)
            tc.verifyTrue(tc.result('withinPass').Passed);
            tc.verifyTrue(tc.result('withinFail').Failed);
            tc.verifyTrue(tc.result('exactPass').Passed);
        end

        function vectorFailsOnOneBadElement(tc)
            tc.verifyTrue(tc.result('vectorOneBadElement').Failed);
        end

        function recordHasAllFields(tc)
            rec = tc.recordFor('absPass');
            tc.assertNumElements(rec, 1);
            required = {'test','quantity','actual','expected','tol','mode','unit', ...
                        'source','citation','pass','slack'};
            tc.verifyTrue(all(isfield(rec, required)), 'provenance record is missing fields');
            tc.verifyEqual(string(rec.source), "ANALYTIC");
            tc.verifyEqual(string(rec.unit), "m");
            tc.verifyTrue(rec.pass);
            tc.verifyGreaterThan(rec.slack, 0);
        end

        function failingCheckIsLogged(tc)
            rec = tc.recordFor('absFail');
            tc.assertNumElements(rec, 1);
            tc.verifyFalse(rec.pass);
            tc.verifyLessThan(rec.slack, 0);
        end

        function provenanceWritesJson(tc)
            f = [tempname '.json'];
            cleanup = onCleanup(@() delete(f));
            outer = vital.test.provenance('get');
            restore = onCleanup(@() vital.test.provenance('set', outer));
            vital.test.provenance('clear');
            vital.test.provenance('add', struct('test','t','quantity','q','actual',1, ...
                'expected',1,'tol',0,'mode','abs','unit','','source','ANALYTIC', ...
                'citation','c','pass',true,'slack',0));
            vital.test.provenance('write', f);
            tc.assertTrue(isfile(f));
            s = jsondecode(fileread(f));
            tc.verifyNumElements(s, 1);
            tc.verifyEqual(string(s(1).source), "ANALYTIC");
        end
    end
end
