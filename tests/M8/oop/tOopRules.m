classdef (TestTags = {'M8', 'OOP'}) tOopRules < vital.test.VitalTestCase
%TOOPRULES  0.8.1-OOP: vital.rules.Rule / RuleSet over rules/mil_f_8785c/records
%   and vital.fq.Assessment (ADR-037).
%   PRE-REGISTERED (written before the classes existed):
%   1. RuleSet.load() holds one Rule per record, in the order and with the ids
%      of vital.fq.loadRules (118 records today).
%   2. At the NESC README point (bare F-16), Rule.evaluate(metrics) reproduces the
%      engine (vital.fq.assess) for EVERY record: point class, margin (isequaln:
%      NaN where the engine has NaN) and pass/fail (engine verdict PASS/FAIL).
%   3. RuleSet.levels(metrics, policy) reproduces the engine's group Level
%      (worstLevel, isequaln) for every group.
%   4. Aircraft.assess(conditions) returns a vital.fq.Assessment whose groups and
%      records equal vital.fq.assess on the same factory (isequal of worstLevel,
%      status, verdict).
%   5. Validation: a Rule from a struct without the loadRules fields ->
%      vital:badInput.

    properties (Constant)
        Ref = 'vital.fq.assess (M6 engine; tests/M6/tF16Fq readme grid)'
    end

    properties
        Res
        Cond
    end

    methods (TestClassSetup)
        function runEngine(tc)
            tc.Cond = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), 'Grid', 'readme');
            tc.Res = vital.fq.assess(vital.fq.loadRules(), vital.fq.f16Factory(), tc.Cond);
        end
    end

    methods (Test)
        function ruleSetLoadsAllRecords(tc)
            rs = vital.rules.RuleSet.load();
            R = vital.fq.loadRules();
            tc.verifyClass(rs, 'vital.rules.RuleSet');
            tc.verifyEqual(numel(rs.Rules), numel(R));
            tc.verifyEqual(arrayfun(@(r) r.Id, rs.Rules, 'UniformOutput', false), {R.id});
            tc.verifyClass(rs.Rules(1), 'vital.rules.Rule');
            tc.verifyTrue(isequaln(rs.toStruct(), R), 'RuleSet.toStruct is the loadRules struct (isequaln: NaN increment fields)');
        end

        function ruleEvaluateMatchesEngine(tc)
            rs = vital.rules.RuleSet.load();
            P = tc.Res.points(1);
            tc.assertEqual(P.status, 'OK');
            policy = tc.Res.conditions.categoryPolicy;
            e = rs.evaluate(P.metrics, policy);
            nPass = 0;
            for r = 1:numel(rs.Rules)
                er = tc.Res.rules(r);
                tc.verifyEqual(e(r).class, er.pointClass{1}, er.id);
                tc.verifyTrue(isequaln(e(r).margin, er.margin(1)), [er.id ': margin differs from the engine']);
                if strcmp(e(r).class, 'OK')
                    tc.verifyEqual(e(r).pass, strcmp(er.verdict, 'PASS'), [er.id ': pass/fail differs from the engine']);
                    nPass = nPass + e(r).pass;
                end
            end
            tc.verifyExact(nPass, sum(strcmp({tc.Res.rules.verdict}, 'PASS')), 'REG', tc.Ref, 'Quantity', 'records passing');
            one = rs.Rules(1).evaluate(P.metrics);
            tc.verifyTrue(isequaln(one.margin, tc.Res.rules(1).margin(1)));
        end

        function groupLevelsMatchEngine(tc)
            rs = vital.rules.RuleSet.load();
            P = tc.Res.points(1);
            L = rs.levels(P.metrics, tc.Res.conditions.categoryPolicy);
            G = tc.Res.groups;
            tc.verifyEqual({L.group}, {G.group});
            tc.verifyTrue(isequaln([L.level], [G.worstLevel]), 'group Levels differ from the engine');
            lv = [L.level]; gw = [G.worstLevel];
            tc.verifyExact(lv(~isnan(gw)), gw(~isnan(gw)), 'REG', tc.Ref, 'Quantity', 'group Levels (finite)');
        end

        function assessmentWrapsEngine(tc)
            a = vital.Aircraft();
            A = a.assess(tc.Cond);
            tc.verifyClass(A, 'vital.fq.Assessment');
            G = tc.Res.groups;
            tc.verifyEqual({A.Groups.group}, {G.group});
            tc.verifyTrue(isequaln([A.Groups.worstLevel], [G.worstLevel]));
            tc.verifyEqual({A.Groups.status}, {G.status});
            tc.verifyEqual({A.Rules.verdict}, {tc.Res.rules.verdict});
            tc.verifyTrue(isequaln(A.level('3.2.2.1.2-CatA'), G(strcmp({G.group}, '3.2.2.1.2-CatA')).worstLevel));
        end

        function ruleValidation(tc)
            tc.verifyError(@() vital.rules.Rule(struct('id', 'x')), 'vital:badInput');
        end
    end
end
