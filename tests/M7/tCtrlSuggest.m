classdef (TestTags = {'M7'}) tCtrlSuggest < vital.test.VitalTestCase
%TCTRLSUGGEST  M7 design feedback (the core demonstration): vital.ctrl.suggestGains
%   proposes pitch-SAS and yaw-damper gains from the bare airframe's in-envelope
%   MIL-F-8785C weaknesses, and the proposal is CONFIRMED by re-running
%   vital.fq.assess on the augmented aircraft over the in-envelope points.
%   Runtime: several minutes (about 15 closed-loop assessments of 36 points); the
%   search runs once in TestClassSetup.
%
%   PRE-REGISTERED (written with the stubs, BEFORE any implementation or run of
%   the search; the gain box was chosen from open-loop (bare) derivatives at the
%   two critical points: at 13,000 ft / Mach 0.63 / CG 30 % M_alpha = -3.0 1/s^2
%   and M_de = -12.6 1/s^2 in the air-axis model, so Ka of a few tenths moves
%   omega_sp^2 by several 1/s^2; at CG 20 % N_dr = -4.4 1/s^2 per rad, so Kr of
%   order 0.5 s adds about 0.3 to zeta_d):
%   CONDITIONS  vital.ctrl.inEnvelopeConditions (36 points, 30 IN); only the
%               in-envelope (headline) results count.
%   TARGETS     Level 1 for 3.2.2.1.1-CatA (CAP, omega_nsp), 3.3.1.1-CatA-other
%               (zeta_d > 0.19, zeta_d omega_nd > 0.35) and 3.3.1.1-CatA-COGA
%               (zeta_d > 0.4).
%   GAIN BOX    Kq in [0, 0.4] s, Ka in [0, 1.0] rad/rad, Kr in [0, 1.5] s; start 0;
%               signs fixed by CONVENTIONS 7 (positive = stabilizing).
%   SUCCESS     status 'TARGET_REACHED' = in the CONFIRMATION run (a fresh
%               vital.fq.assess of the augmented aircraft with the proposed,
%               rounded gains) every target's in-envelope headline Level is 1 and
%               no other in-envelope group with a bare headline Level is worse
%               than bare. Anything else is 'TARGET_NOT_REACHED' and is reported
%               as such, never claimed.
%   EXPECTATIONS
%   1. Re-confirmation of the bare weaknesses (REG, reports/fq/
%      f16_fq_default_baseline.json): the IN points of the bare assessment over
%      the conditions are exactly the 30 IN points of the default report; every
%      group's in-envelope headline Level equals the report's and its critical
%      margin agrees within 1e-12 relative (Inf/NaN equal); 3.2.2.1.1-CatA,
%      3.3.1.1-CatA-other and -COGA are Level 2; the 3.2.2.1.1 Level 1 critical
%      record is the CAP record at 13,000 ft / Mach 0.63 / CG 30 % (CAP 0.2016 <
%      0.28), the 3.3.1.1-CatA-other one the zeta_d record at 13,000 ft / Mach
%      0.63 / CG 20 %.
%   2. Sensitivities at the start k = 0 (forward differences through the whole
%      chain): d m(3.2.2.1.1-CatA)/dKa > 0 (alpha feedback raises CAP where it is
%      low); d m(3.3.1.1-CatA-other)/dKr > 0 and d m(3.3.1.1-CatA-COGA)/dKr > 0;
%      lon/lat decoupling of the symmetric airframe at wings-level trims
%      (ANALYTIC): |d m(3.3.1.1-*)/dKq|, |d m(3.3.1.1-*)/dKa| and
%      |d m(3.2.2.1.1-CatA)/dKr| <= 1e-6 per unit gain. The zero-gain closed loop
%      equals the open loop: its target margins equal the bare ones within 1e-6
%      abs (two step-study paths).
%   3. Outcome (REG prediction): TARGET_REACHED; each target confirmed at Level 1
%      with margin > 0 and >= Goal/2 = 0.025 (design goal 0.05; rounding to 0.01
%      may cost part of it); no protected group regressed; every proposed gain
%      inside its box and a multiple of 0.01.
%   4. Confirmation is real: an assessment run by THIS test with the proposed
%      gains (the default builder written out here) gives exactly (isequal) the
%      in-envelope headline Levels and critical margins of s.confirmation.
%   5. Not reached is a status, not a claim: target 3.3.1.1-CatA-COGA Level 1
%      with only Kr in [0, 0.05] s on the README point -> 'TARGET_NOT_REACHED',
%      reached false, achieved Level 2, the reason names the group.
%   6. A target without an in-envelope point (a single EXTRAPOLATED condition,
%      29,000 ft / Mach 0.5) -> 'NOT_ASSESSABLE'.
%   7. Errors: an unknown target group or a start outside the box ->
%      vital:badInput.
%   8. (ADDED AFTER the first GREEN run, a guard for failure-catalogue row FC-816,
%      not a RED-first test.) A suggestion that reaches its target but degrades
%      another group is not a success: README point, target 3.3.1.1-CatA-other
%      Level 1 with Kr in [0, 1] s, and a fixed wrong-sign Kq = -0.3 s ->
%      'TARGET_NOT_REACHED' with a reason that says "worse than bare".

    properties
        R
        C
        bare
        s
        report
    end

    properties (Constant)
        TARGETS = {'3.2.2.1.1-CatA', '3.3.1.1-CatA-other', '3.3.1.1-CatA-COGA'}
    end

    methods (TestClassSetup)
        function runSearchOnce(tc)
            tc.R = vital.fq.loadRules();
            tc.C = vital.ctrl.inEnvelopeConditions();
            tc.bare = vital.fq.assess(tc.R, vital.fq.f16Factory(), tc.C);
            tc.s = vital.ctrl.suggestGains('Bare', tc.bare, 'Rules', tc.R, 'Conditions', tc.C);
            tc.report = jsondecode(fileread(fullfile(vital.paths('reports'), 'fq', 'f16_fq_default_baseline.json')));
        end
    end

    methods (Static, Access = private)
        function k = condKey(c)
            k = sprintf('%.6g|%.6g|%.6g', c.h_ft, c.mach, c.cg_pct_mac);
        end

        function v = num(x)
            if iscell(x) && isscalar(x), x = x{1}; end      % jsondecode of a ["Inf"]-style value
            if ischar(x) || isstring(x), v = str2double(x); elseif isempty(x), v = NaN; else, v = double(x); end
        end

        function t = tgt(s, name)
            t = s.targets(strcmp({s.targets.group}, name));
        end
    end

    methods (Test)
        function bareWeaknessesReconfirmed(tc)
            P = tc.bare.points;
            inNow = sort(arrayfun(@(p) tCtrlSuggest.condKey(p.cond), P(strcmp({P.envelope}, 'IN')), 'UniformOutput', false));
            RP = tc.report.points;
            if isstruct(RP), RP = num2cell(RP); end
            inRep = {};
            for k = 1:numel(RP)
                if strcmp(RP{k}.envelope, 'IN'), inRep{end+1} = tCtrlSuggest.condKey(RP{k}.cond); end %#ok<AGROW>
            end
            tc.verifyEqual(numel(inNow), 30);
            tc.verifyEqual(inNow(:), sort(inRep(:)), 'the IN set equals the default report''s');
            RG = tc.report.groups;
            if isstruct(RG), RG = num2cell(RG); end
            for k = 1:numel(RG)
                g = tc.bare.groups(strcmp({tc.bare.groups.group}, RG{k}.group));
                Lr = tCtrlSuggest.num(RG{k}.inEnvelope.levelHeadline);
                tc.verifyTrue(isequaln(g.inEnvelope.levelHeadline, Lr), sprintf('%s headline Level', RG{k}.group));
                mr = tCtrlSuggest.num(RG{k}.inEnvelope.criticalMargin); m = g.inEnvelope.criticalMargin;
                if isfinite(mr) && mr ~= 0
                    tc.verifyTol(m, mr, 1e-12, 'rel', 'REG', 'reports/fq/f16_fq_default_baseline.json', ...
                        'Quantity', [RG{k}.group ' in-envelope critical margin']);
                else
                    tc.verifyTrue(isequaln(m, mr), sprintf('%s margin %g vs %g', RG{k}.group, m, mr));
                end
            end
            for n = tc.TARGETS
                tc.verifyEqual(tCtrlSuggest.tgt(tc.s, n{1}).bareLevel, 2, [n{1} ' bare Level 2']);
            end
            t = tCtrlSuggest.tgt(tc.s, '3.2.2.1.1-CatA');
            tc.verifyEqual(t.bareCritical.record, 'MIL-F-8785C-3.2.2.1.1-CAP-L1-CatA');
            tc.verifyEqual([t.bareCritical.cond.h_ft t.bareCritical.cond.mach t.bareCritical.cond.cg_pct_mac], [13000 0.63 30]);
            t = tCtrlSuggest.tgt(tc.s, '3.3.1.1-CatA-other');
            tc.verifyEqual(t.bareCritical.record, 'MIL-F-8785C-3.3.1.1-zeta_d-L1-CatA-other');
            tc.verifyEqual([t.bareCritical.cond.h_ft t.bareCritical.cond.mach t.bareCritical.cond.cg_pct_mac], [13000 0.63 20]);
        end

        function sensitivitySignsAtStart(tc)
            S1 = tc.s.sensitivity(1);
            tc.verifyEqual(S1.k(:).', [0 0 0], 'iteration 1 is at the start k = 0');
            gi = @(n) find(strcmp(S1.gainNames, n));
            ci = @(n) find(strcmp(S1.constraintNames, ['target:' n]));
            S = S1.S;
            tc.verifyGreaterThan(S(ci('3.2.2.1.1-CatA'), gi('Ka')), 0, 'dm(CAP group)/dKa > 0');
            tc.verifyGreaterThan(S(ci('3.3.1.1-CatA-other'), gi('Kr')), 0, 'dm(Dutch roll)/dKr > 0');
            tc.verifyGreaterThan(S(ci('3.3.1.1-CatA-COGA'), gi('Kr')), 0, 'dm(Dutch roll CO/GA)/dKr > 0');
            for n = {'3.3.1.1-CatA-other', '3.3.1.1-CatA-COGA'}
                for gname = {'Kq', 'Ka'}
                    tc.verifyTol(S(ci(n{1}), gi(gname{1})), 0, 1e-6, 'abs', 'ANALYTIC', 'lon/lat decoupling', ...
                        'Quantity', sprintf('dm(%s)/d%s', n{1}, gname{1}));
                end
            end
            tc.verifyTol(S(ci('3.2.2.1.1-CatA'), gi('Kr')), 0, 1e-6, 'abs', 'ANALYTIC', 'lon/lat decoupling', ...
                'Quantity', 'dm(3.2.2.1.1-CatA)/dKr');
            for n = tc.TARGETS
                t = tCtrlSuggest.tgt(tc.s, n{1});
                tc.verifyTol(S1.margins(ci(n{1})), t.bareMargin, 1e-6, 'abs', 'ANALYTIC', ...
                    'zero-gain closed loop = open loop (header 2)', 'Quantity', [n{1} ' margin at k = 0']);
            end
            tc.verifyTrue(islogical(S1.switched) && isequal(size(S1.switched), size(S)), 'active-set switch flags reported');
        end

        function targetReachedAndConfirmed(tc)
            s = tc.s;
            tc.verifyEqual(s.status, 'TARGET_REACHED', s.reason);
            tc.verifyTrue(s.confirmation.evaluated);
            for n = tc.TARGETS
                t = tCtrlSuggest.tgt(s, n{1});
                tc.verifyEqual(t.achievedLevel, 1, [n{1} ' confirmed Level 1']);
                tc.verifyGreaterThan(t.achievedMargin, 0, [n{1} ' margin > 0']);
                tc.verifyWithin(t.achievedMargin, 0.025, Inf, 'REG', 'header 3: margin >= Goal/2', 'Quantity', [n{1} ' margin']);
            end
            tc.verifyFalse(any([s.protected.regressed]), 'no protected group is worse than bare');
            k = s.gains.value(:).';
            tc.verifyTrue(all(k >= [0 0 0] - 1e-12 & k <= [0.4 1.0 1.5] + 1e-12), 'gains inside the box');
            tc.verifyTrue(all(abs(k / 0.01 - round(k / 0.01)) < 1e-9), 'gains rounded to 0.01');
        end

        function confirmationIsIndependentAssessment(tc)
            k = tc.s.gains.value;
            b = @(AC, env, tr) vital.ctrl.combine(vital.ctrl.pitchSas(AC, env, tr, 'Kq', k(1), 'Ka', k(2)), ...
                vital.ctrl.yawDamper(AC, env, tr, 'Kr', k(3)));
            res = vital.fq.assess(tc.R, vital.fq.f16Factory('Controller', b), tc.C);
            G = tc.s.confirmation.groups;
            for gi = 1:numel(res.groups)
                g = res.groups(gi);
                c = G(strcmp({G.group}, g.group));
                tc.verifyTrue(isequaln(c.levelHeadline, g.inEnvelope.levelHeadline), [g.group ' Level']);
                tc.verifyTrue(isequaln(c.criticalMargin, g.inEnvelope.criticalMargin), [g.group ' margin']);
            end
        end

        function notReachedIsAStatus(tc)
            Cr = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), 'Grid', 'readme');
            s = vital.ctrl.suggestGains('Conditions', Cr, 'Rules', tc.R, ...
                'Targets', struct('group', '3.3.1.1-CatA-COGA', 'level', 1), ...
                'Gains', struct('name', 'Kr', 'lo', 0, 'hi', 0.05, 'start', 0, 'unit', 's'), ...
                'Builder', @(AC, env, tr, k) vital.ctrl.yawDamper(AC, env, tr, 'Kr', k(1)), 'MaxIter', 2);
            tc.verifyEqual(s.status, 'TARGET_NOT_REACHED');
            tc.verifyFalse(s.targets(1).reached);
            tc.verifyEqual(s.targets(1).achievedLevel, 2);
            tc.verifySubstring(s.reason, '3.3.1.1-CatA-COGA');
        end

        function regressionIsNotASuccess(tc)
            Cr = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), 'Grid', 'readme');
            s = vital.ctrl.suggestGains('Conditions', Cr, 'Rules', tc.R, ...
                'Targets', struct('group', '3.3.1.1-CatA-other', 'level', 1), ...
                'Gains', struct('name', {'Kq', 'Kr'}, 'lo', {-0.3, 0}, 'hi', {-0.3, 1}, 'start', {-0.3, 0}, 'unit', {'s', 's'}), ...
                'MaxIter', 2);
            tc.verifyEqual(s.status, 'TARGET_NOT_REACHED');
            tc.verifySubstring(s.reason, 'worse than bare');
            tc.verifyTrue(any([s.protected.regressed]));
        end

        function noInEnvelopePointIsNotAssessable(tc)
            Cx = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), ...
                'Axes', struct('h_ft', 29000, 'mach', 0.5, 'cg_pct_mac', 25));
            s = vital.ctrl.suggestGains('Conditions', Cx, 'Rules', tc.R, 'MaxIter', 1);
            tc.verifyEqual(s.status, 'NOT_ASSESSABLE');
        end

        function badInputs(tc)
            tc.verifyError(@() vital.ctrl.suggestGains('Rules', tc.R, 'Bare', tc.bare, 'Conditions', tc.C, ...
                'Targets', struct('group', 'no-such-group', 'level', 1)), 'vital:badInput');
            tc.verifyError(@() vital.ctrl.suggestGains('Rules', tc.R, 'Bare', tc.bare, 'Conditions', tc.C, ...
                'Gains', struct('name', 'Kr', 'lo', 0, 'hi', 1, 'start', 2, 'unit', 's'), ...
                'Builder', @(AC, env, tr, k) vital.ctrl.yawDamper(AC, env, tr, 'Kr', k(1))), 'vital:badInput');
        end
    end
end
