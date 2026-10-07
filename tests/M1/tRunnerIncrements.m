classdef (TestTags = {'M1'}) tRunnerIncrements < matlab.unittest.TestCase
%TRUNNERINCREMENTS  Gate support for building one milestone in several
%   increments, possibly in parallel (added 2026-09-29 before M5).
%
%   run_vital_tests(..., 'Increment', {classes}, 'Baseline', {classes})
%     restricts the CURRENT milestone's tests to Increment + Baseline.
%     Increment classes are the new ones (RED rules apply); Baseline classes
%     are finished increments and are treated like earlier milestones
%     (PASS or REGRESSION). Unlisted current-milestone files are skipped, so
%     one increment's gate is not broken by another's work in progress.
%     A full gate (no Increment/Baseline) still runs everything.
%   vital.test.loadSabotageSet(folder) merges sabotages.json and every
%     sabotages_<part>.json, so parallel increments never edit one file.

    properties
        Suite
        Parts
    end

    methods (TestClassSetup)
        function locate(tc)
            tc.Suite = fullfile(vital.paths('tests'), 'fixtures', 'increment_suite');
            tc.Parts = fullfile(vital.paths('tests'), 'fixtures');
        end
    end

    methods (Access = private)
        function [s, rows] = runGate(tc, phase, varargin)
            out = tempname; mkdir(out); c = onCleanup(@() rmdir(out, 's'));
            s = run_vital_tests('M5', 'Phase', phase, 'Folder', tc.Suite, 'IncludeFixtures', true, ...
                'ReportDir', out, 'Quiet', true, varargin{:});
            j = jsondecode(fileread(s.files.json));
            rows = j.tests;
        end

        function c = classOf(~, rows, cls)
            k = find(startsWith({rows.name}, [cls '/']));
            if isempty(k), c = 'ABSENT'; else, c = rows(k(1)).class; end
        end
    end

    methods (Test)
        function redIncrementClassifiesOnlyListedFilesAsNew(tc)
            [s, rows] = tc.runGate('red', 'Increment', {'fxIncNew'}, 'Baseline', {'fxIncDone'});
            tc.verifyEqual(tc.classOf(rows, 'fxIncNew'), 'RED_EXPECTED');
            tc.verifyEqual(tc.classOf(rows, 'fxIncDone'), 'PASS', 'a baseline increment is not VACUOUS');
            tc.verifyEqual(tc.classOf(rows, 'fxIncOld'), 'PASS');
            tc.verifyEqual(tc.classOf(rows, 'fxIncOther'), 'ABSENT', 'unlisted work in progress is skipped');
            tc.verifyTrue(s.gateOK);
        end

        function greenIncrementSkipsUnlistedCurrentMilestoneFiles(tc)
            [s, rows] = tc.runGate('green', 'Increment', {'fxIncDone'});
            tc.verifyEqual(numel(rows), 2, 'fxIncOld + fxIncDone only');
            tc.verifyTrue(s.gateOK);
        end

        function fullGateStillRunsEverything(tc)
            [s, rows] = tc.runGate('green');
            tc.verifyEqual(numel(rows), 4);
            tc.verifyFalse(s.gateOK, 'unfinished increments must fail the full gate');
        end

        function baselineFailureIsRegression(tc)
            [s, rows] = tc.runGate('red', 'Increment', {'fxIncDone'}, 'Baseline', {'fxIncNew'});
            tc.verifyEqual(tc.classOf(rows, 'fxIncNew'), 'REGRESSION');
            tc.verifyFalse(s.gateOK);
        end

        function unknownIncrementNameErrors(tc)
            % A typo must not silently select nothing; an earlier-milestone class is not an increment.
            tc.verifyError(@() tc.runGate('red', 'Increment', {'fxIncNwe'}), 'vital:test:unknownIncrement');
            tc.verifyError(@() tc.runGate('red', 'Increment', {'fxIncOld'}), 'vital:test:unknownIncrement');
        end

        function tagNamesTheReportFiles(tc)
            [s, ~] = tc.runGate('red', 'Increment', {'fxIncNew'}, 'Tag', 'A');
            [~, f] = fileparts(s.files.json);
            tc.verifyEqual(f, 'M5_red_A');
        end

        function sabotagePartsAreMerged(tc)
            sab = vital.test.loadSabotageSet(fullfile(tc.Parts, 'sabotage_parts'));
            tc.verifyEqual(sort({sab.id}), {'P-1', 'P-2'});
            b = vital.test.loadSabotageSet(fullfile(tc.Parts, 'sabotage_parts'), 'Parts', {'B'});
            tc.verifyEqual({b.id}, {'P-2'});
            m = vital.test.loadSabotageSet(fullfile(tc.Parts, 'sabotage_parts'), 'Parts', {'main'});
            tc.verifyEqual({m.id}, {'P-1'});
        end

        function duplicateSabotageIdAcrossPartsErrors(tc)
            tc.verifyError(@() vital.test.loadSabotageSet(fullfile(tc.Parts, 'sabotage_parts_dup')), ...
                'sabotage:badDefinition');
        end

        function missingSabotagePartErrors(tc)
            tc.verifyError(@() vital.test.loadSabotageSet(fullfile(tc.Parts, 'sabotage_parts'), 'Parts', {'Z'}), ...
                'sabotage:badDefinition');
        end
    end
end
