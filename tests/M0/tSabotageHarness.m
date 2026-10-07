classdef (TestTags = {'M0'}) tSabotageHarness < matlab.unittest.TestCase
%TSABOTAGEHARNESS  M0: the harness that proves tests can fail.
%   A sabotage edits ONE pattern in a temporary copy of the tree and runs
%   the targeted tests in a separate MATLAB process. The sabotage is
%   "detected" only if the targets ran and at least one failed. Harness
%   problems (pattern absent or ambiguous, unknown target, process that
%   never reported) must be errors, never detections.

    properties
        Tree
    end

    methods (TestClassSetup)
        function locate(tc)
            tc.Tree = fullfile(vital.paths('root'), 'tests', 'fixtures', 'sabotage_tree');
        end
    end

    methods (Access = private)
        function sab = fixtureSabotage(tc)
            sab = vital.test.loadSabotages(fullfile(tc.Tree, 'sabotages.json'));
            sab = sab(1);
        end
    end

    methods (Test)
        function definitionsLoad(tc)
            sab = tc.fixtureSabotage();
            tc.verifyEqual(string(sab.id), "S-FIX-1");
            tc.verifyEqual(string(sab.targets), "tAddOne/addsOne");
        end

        function malformedDefinitionErrors(tc)
            f = [tempname '.json'];
            cleanup = onCleanup(@() delete(f));
            fid = fopen(f, 'w'); fprintf(fid, '[{"id":"X","file":"a.m"}]'); fclose(fid);
            tc.verifyError(@() vital.test.loadSabotages(f), 'sabotage:badDefinition');
        end

        function missingPatternErrors(tc)
            sab = tc.fixtureSabotage();
            sab.pattern = 'this text is not in the file';
            dst = tempname;
            cleanup = onCleanup(@() vital.test.removeTree(dst));
            tc.verifyError(@() vital.test.applySabotage(tc.Tree, dst, sab), 'sabotage:patternNotFound');
        end

        function ambiguousPatternErrors(tc)
            sab = tc.fixtureSabotage();
            sab.pattern = 'x';          % occurs more than once in addOne.m
            dst = tempname;
            cleanup = onCleanup(@() vital.test.removeTree(dst));
            tc.verifyError(@() vital.test.applySabotage(tc.Tree, dst, sab), 'sabotage:patternAmbiguous');
        end

        function unknownTargetErrors(tc)
            sab = tc.fixtureSabotage();
            sab.targets = {'tAddOne/doesNotExist'};
            tc.verifyError(@() vital.test.runSabotageCase(tc.Tree, sab), 'sabotage:targetNotFound');
        end

        function originalTreeUnchanged(tc)
            before = vital.test.treeHash(tc.Tree);
            dst = tempname;
            cleanup = onCleanup(@() vital.test.removeTree(dst));
            vital.test.applySabotage(tc.Tree, dst, tc.fixtureSabotage());
            tc.verifyEqual(vital.test.treeHash(tc.Tree), before, 'the original tree must never be edited');
            tc.verifyNotEqual(vital.test.treeHash(dst), before, 'the copy must differ after sabotage');
        end

        function treeHashIsDeterministicAndSensitive(tc)
            a = vital.test.treeHash(tc.Tree);
            tc.verifyEqual(vital.test.treeHash(tc.Tree), a);
            tc.verifyMatches(a, '^[0-9a-f]{64}$');
        end

        function sabotageTurnsTargetRedAndBaselineIsGreen(tc)
            % Two separate MATLAB processes: sabotaged copy must be RED,
            % unsabotaged copy must be GREEN.
            sab = tc.fixtureSabotage();
            r = vital.test.runSabotageCase(tc.Tree, sab);
            tc.verifyTrue(r.ran, 'the sabotaged run must report back');
            tc.verifyTrue(r.detected, 'sign flip in addOne must turn tAddOne RED');

            base = sab; base.replacement = base.pattern;   % a no-op edit
            b = vital.test.runSabotageCase(tc.Tree, base);
            tc.verifyTrue(b.ran);
            tc.verifyFalse(b.detected, 'unsabotaged copy must stay GREEN');
        end
    end
end
