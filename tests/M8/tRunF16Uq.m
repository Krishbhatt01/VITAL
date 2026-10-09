classdef (TestTags = {'M8'}) tRunF16Uq < vital.test.VitalTestCase
%TRUNF16UQ  M8 user entry point run_f16_uq: a small run (one group, the NESC
%   README point, a tiny budget) writes its labelled report and never overwrites
%   an existing one.
%
%   PRE-REGISTERED (with the stub, before any implementation):
%   1. run_f16_uq('Groups', {'3.3.1.1-CatA-other'}, 'Conditions', <readme grid:
%      10,013 ft, 565.6854 ft/s, CG 25 %, IN the validity envelope>,
%      'WidthScales', 1, 'NumLHS', 4, 'NumStarts', 1, 'MaxEvals', 10,
%      'NumCandidates', 1, 'N', 10, 'Label', 'test', 'ReportDir', d, 'Quiet', true)
%      returns one group with one width; its verdict is one of ROBUST /
%      NOT_ROBUST / NOT_ASSESSABLE; the bound-worst search evaluated the centre,
%      the 64 corners and the 4 LHS points (at least 69 points); the Monte Carlo
%      drew 10 samples.
%   2. Files: <d>\f16_uq_test.json and .md. The JSON decodes, has label
%      'JUDGMENT' and the group; the Markdown names the group, the verdict and
%      the word JUDGMENT; the printout (r.printout) has the headline table.
%   3. No overwrite: with existing files f16_uq_test.json/.md in d (written by
%      the test), the run writes a timestamped name (f16_uq_test_<stamp>.*), the
%      existing files are byte-identical afterwards, and the printout says the
%      existing file was kept.

    properties
        dir
    end

    methods (TestMethodSetup)
        function tmp(tc)
            tc.dir = tempname;
            mkdir(tc.dir);
            tc.addTeardown(@() rmdir(tc.dir, 's'));
        end
    end

    methods (Access = private)
        function r = small(tc, label)
            Cr = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), 'Grid', 'readme');
            r = run_f16_uq('Groups', {'3.3.1.1-CatA-other'}, 'Conditions', Cr, 'WidthScales', 1, 'NumLHS', 4, ...
                'NumStarts', 1, 'MaxEvals', 10, 'NumCandidates', 1, 'N', 10, 'Label', label, 'ReportDir', tc.dir, 'Quiet', true);
        end
    end

    methods (Test)
        function smallRunWritesLabelledReport(tc)
            % existing files: the run must keep them (header 3)
            fj = fullfile(tc.dir, 'f16_uq_test.json'); fm = fullfile(tc.dir, 'f16_uq_test.md');
            fid = fopen(fj, 'w'); fprintf(fid, '{"keep": true}'); fclose(fid);
            fid = fopen(fm, 'w'); fprintf(fid, 'keep me'); fclose(fid);
            r = tc.small('test');
            tc.verifyEqual(fileread(fj), '{"keep": true}', 'existing JSON kept');
            tc.verifyEqual(fileread(fm), 'keep me', 'existing Markdown kept');
            tc.verifyNotEqual(r.files.json, fj);
            tc.verifyTrue(startsWith(r.files.json, fullfile(tc.dir, 'f16_uq_test_')), r.files.json);
            tc.verifyTrue(isfile(r.files.json) && isfile(r.files.md));
            tc.verifySubstring(r.printout, 'kept');
            % the run itself (header 1)
            tc.verifyNumElements(r.groups, 1);
            g = r.groups(1);
            tc.verifyEqual(g.group, '3.3.1.1-CatA-other');
            tc.verifyNumElements(g.widths, 1);
            w = g.widths(1);
            tc.verifyTrue(any(strcmp(w.verdict.verdict, {'ROBUST', 'NOT_ROBUST', 'NOT_ASSESSABLE'})), w.verdict.verdict);
            tc.verifyGreaterThanOrEqual(w.bw.nEvaluated, 69);
            tc.verifyEqual(w.mc.N, 10);
            % the files (header 2)
            J = jsondecode(fileread(r.files.json));
            tc.verifyEqual(J.label, 'JUDGMENT');
            tc.verifyEqual(J.groups(1).group, '3.3.1.1-CatA-other');
            md = fileread(r.files.md);
            tc.verifySubstring(md, 'JUDGMENT');
            tc.verifySubstring(md, '3.3.1.1-CatA-other');
            tc.verifySubstring(md, w.verdict.verdict);
            tc.verifySubstring(r.printout, '3.3.1.1-CatA-other');
        end
    end
end
