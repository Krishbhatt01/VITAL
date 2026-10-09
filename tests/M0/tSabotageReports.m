classdef (TestTags = {'M0'}) tSabotageReports < matlab.unittest.TestCase
%TSABOTAGEREPORTS  M0 (review R3 B1): the sabotage copy must contain the
%   committed reports that tests read, so a detection means the TESTS saw the
%   defect, not that a file was missing.
%
%   Finding R3 B1 (2026-10-09): vital.test.applySabotage copied the tree
%   without reports/. tCtrlSuggest and tF16Uq read reports/fq and reports/ctrl
%   in TestClassSetup, so in a sabotage copy they failed on ANY edit: a null
%   sabotage (whitespace in a comment) was "DETECTED".
%
%   PRE-REGISTERED (written before the fix; coordinator, 2026-10-09):
%   1. copyHasReportsButNotScratch: after applySabotage on the fixture tree
%      tests/fixtures/sabotage_reports_tree, the copy contains
%      reports/fq/value.json (byte-identical), does NOT contain reports/work
%      (scratch, 147 MB in the real tree) and does NOT contain data/ (read
%      through VITAL_DATA_ROOT, as before).
%   2. nullSabotageNotDetected: the null sabotage S-FIXR-0 (whitespace inside a
%      comment) on a test that reads reports/fq/value.json runs and is NOT
%      detected.
%   3. realSabotageDetected: S-FIXR-1 (factor 2 -> 3) on the same test is
%      detected. (Passes before the fix too, for the wrong reason; it guards
%      that the fix does not hide real defects.)
%   RED before the fix: 1 and 2 fail by assertion (the copy has no reports/),
%   which is the defect itself, not a missing feature; 3 passes (justified
%   above).

    properties
        Tree
        Sabs
    end

    methods (TestClassSetup)
        function locate(tc)
            tc.Tree = fullfile(vital.paths('root'), 'tests', 'fixtures', 'sabotage_reports_tree');
            tc.Sabs = vital.test.loadSabotages(fullfile(tc.Tree, 'sabotages.json'));
        end
    end

    methods (Access = private)
        function sab = byId(tc, id)
            sab = tc.Sabs(strcmp({tc.Sabs.id}, id));
            tc.assertNumElements(sab, 1);
        end
    end

    methods (Test)
        function copyHasReportsButNotScratch(tc)
            dst = tempname;
            cleanup = onCleanup(@() vital.test.removeTree(dst));
            vital.test.applySabotage(tc.Tree, dst, tc.byId('S-FIXR-0'));
            f = fullfile(dst, 'reports', 'fq', 'value.json');
            tc.verifyTrue(isfile(f), 'committed reports must be in the sabotage copy');
            if isfile(f)
                tc.verifyEqual(fileread(f), fileread(fullfile(tc.Tree, 'reports', 'fq', 'value.json')));
            end
            tc.verifyFalse(isfolder(fullfile(dst, 'reports', 'work')), 'reports/work is scratch and must not be copied');
            tc.verifyFalse(isfolder(fullfile(dst, 'data')), 'data/ is read through VITAL_DATA_ROOT, never copied');
        end

        function nullSabotageNotDetected(tc)
            r = vital.test.runSabotageCase(tc.Tree, tc.byId('S-FIXR-0'));
            tc.verifyTrue(r.ran, 'the null-sabotage run must report back');
            tc.verifyFalse(r.detected, ['a whitespace change in a comment must NOT be detected; ' ...
                'a detection here means the harness itself breaks the target (R3 B1)']);
        end

        function realSabotageDetected(tc)
            r = vital.test.runSabotageCase(tc.Tree, tc.byId('S-FIXR-1'));
            tc.verifyTrue(r.ran);
            tc.verifyTrue(r.detected, 'a wrong factor must turn tReadsReport RED');
        end
    end
end
