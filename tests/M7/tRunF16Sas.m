classdef (TestTags = {'M7'}) tRunF16Sas < vital.test.VitalTestCase
%TRUNF16SAS  M7 user entry point run_f16_sas: bare vs augmented, side by side, with
%   every Level labelled by the aircraft it belongs to.
%
%   PRE-REGISTERED (with the stub, before any implementation):
%   1. run_f16_sas('Quiet', true) at the README point with the default gains
%      (Kq 0.1, Ka 0.2, Kr 0.5): closedLoop.status 'STABLE'; r.levels has one
%      row per assessed group; its bare Levels equal a vital.fq.assess of the bare
%      aircraft on the 'readme' grid (in-envelope headline, isequaln) and its
%      augmented Levels equal one with the same controller (isequaln);
%      3.3.1.1-CatA-other is bare Level 2, augmented Level 1 (as tCtrlFq 6, REG).
%   2. The printout names the aircraft of each Level column: it contains
%      'BARE AIRFRAME' and 'AUGMENTED', the gains, and the envelope tag 'IN';
%      with 'Law', 'lqr' it contains 'NESC LQR'.
%   3. 'Suggest', true with 'SuggestOptions' (readme grid, target
%      3.3.1.1-CatA-other Level 1, only Kr in [0, 1] s, MaxIter 3) writes
%      f16_sas_suggestion.json and .md in the given ReportDir, r.suggestion.status
%      is 'TARGET_REACHED' (REG: Kr 0.5 already reaches it at this point) and the
%      printout contains 'CONFIRMED'. A second run with the same ReportDir does
%      not overwrite the first files (a timestamped name is used).

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

    methods (Test)
        function sideBySideLevels(tc)
            r = run_f16_sas('Quiet', true);
            tc.verifyEqual(r.closedLoop.status, 'STABLE');
            R = vital.fq.loadRules();
            C = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), 'Grid', 'readme');
            bare = vital.fq.assess(R, vital.fq.f16Factory(), C);
            b = @(AC, env, tr) vital.ctrl.combine(vital.ctrl.pitchSas(AC, env, tr, 'Kq', 0.1, 'Ka', 0.2), ...
                vital.ctrl.yawDamper(AC, env, tr, 'Kr', 0.5));
            aug = vital.fq.assess(R, vital.fq.f16Factory('Controller', b), C);
            for k = 1:numel(r.levels)
                gb = bare.groups(strcmp({bare.groups.group}, r.levels(k).group));
                ga = aug.groups(strcmp({aug.groups.group}, r.levels(k).group));
                tc.verifyTrue(isequaln(r.levels(k).bareLevel, gb.inEnvelope.levelHeadline), [r.levels(k).group ' bare']);
                tc.verifyTrue(isequaln(r.levels(k).augLevel, ga.inEnvelope.levelHeadline), [r.levels(k).group ' augmented']);
            end
            row = r.levels(strcmp({r.levels.group}, '3.3.1.1-CatA-other'));
            tc.verifyEqual([row.bareLevel row.augLevel], [2 1]);
        end

        function printoutLabelsTheAircraft(tc)
            txt = evalc('run_f16_sas;');
            tc.verifySubstring(txt, 'BARE AIRFRAME');
            tc.verifySubstring(txt, 'AUGMENTED');
            tc.verifySubstring(txt, 'Kr 0.5');
            tc.verifySubstring(txt, 'IN');
            txt = evalc('run_f16_sas(''Law'', ''lqr'');');
            tc.verifySubstring(txt, 'NESC LQR');
        end

        function suggestionWrittenAndConfirmed(tc)
            Cr = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), 'Grid', 'readme');
            so = {'Conditions', Cr, 'Targets', struct('group', '3.3.1.1-CatA-other', 'level', 1), ...
                'Gains', struct('name', 'Kr', 'lo', 0, 'hi', 1, 'start', 0, 'unit', 's'), ...
                'Builder', @(AC, env, tr, k) vital.ctrl.yawDamper(AC, env, tr, 'Kr', k(1)), 'MaxIter', 3};
            txt = evalc('r = run_f16_sas(''Suggest'', true, ''SuggestOptions'', so, ''ReportDir'', tc.dir);');
            tc.verifyEqual(r.suggestion.status, 'TARGET_REACHED');
            tc.verifyTrue(isfile(fullfile(tc.dir, 'f16_sas_suggestion.json')));
            tc.verifyTrue(isfile(fullfile(tc.dir, 'f16_sas_suggestion.md')));
            tc.verifySubstring(txt, 'CONFIRMED');
            d1 = dir(fullfile(tc.dir, 'f16_sas_suggestion.json'));
            evalc('run_f16_sas(''Suggest'', true, ''SuggestOptions'', so, ''ReportDir'', tc.dir, ''Quiet'', true);');
            d2 = dir(fullfile(tc.dir, 'f16_sas_suggestion.json'));
            tc.verifyEqual(d2.datenum, d1.datenum, 'the existing report is not overwritten');
            tc.verifyGreaterThan(numel(dir(fullfile(tc.dir, 'f16_sas_suggestion_*.json'))), 0, 'a timestamped report is written');
        end
    end
end
