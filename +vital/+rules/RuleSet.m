classdef RuleSet
%RULESET  The curated MIL-F-8785C records as vital.rules.Rule objects (0.8.1-OOP, ADR-037).
%   rs = vital.rules.RuleSet.load()          rules/mil_f_8785c/records
%   rs = vital.rules.RuleSet.load(folder)    (vital.fq.loadRules: schema checks)
%   rs.Rules                                 Rule array, in loadRules order
%   R  = rs.toStruct()                       the vital.fq.loadRules struct (for
%                                            vital.fq.assess)
%   e  = rs.evaluate(metrics, policy)        Rule.evaluate for every record
%   L  = rs.levels(metrics, policy)          per group (paragraph + Category):
%        group, level = the best Level L whose records all pass or are not
%        applicable (MIL-F-8785C 6.7.1); 4 = worse than Level 3; NaN when any
%        record is excluded, all are not applicable, or the Category is not
%        assessed (the engine's rule at one point)
    properties (SetAccess = private)
        Rules vital.rules.Rule = vital.rules.Rule.empty
    end
    properties (Access = private)
        Raw struct
    end
    methods
        function obj = RuleSet(R)
            if nargin == 0, obj.Raw = struct([]); return; end
            if ~isstruct(R)
                error('vital:badInput', 'a RuleSet needs a vital.fq.loadRules struct array.');
            end
            obj.Raw = R;
            rs = vital.rules.Rule.empty;
            for k = 1:numel(R), rs(k) = vital.rules.Rule(R(k)); end
            obj.Rules = rs;
        end

        function R = toStruct(obj)
            R = obj.Raw;
        end

        function e = evaluate(obj, metrics, policy)
            arguments
                obj
                metrics
                policy struct = struct()
            end
            e = struct('class', {}, 'why', {}, 'value', {}, 'margin', {}, 'pass', {});
            for k = 1:numel(obj.Rules), e(k) = obj.Rules(k).evaluate(metrics, policy); end
        end

        function L = levels(obj, metrics, policy)
            arguments
                obj
                metrics
                policy struct = struct()
            end
            e = obj.evaluate(metrics, policy);
            groups = {obj.Rules.Group};
            [names, ~, gi] = unique(groups, 'stable');
            L = struct('group', names, 'level', NaN);
            for g = 1:numel(names)
                ks = find(gi == g).';
                cls = {e(ks).class};
                if any(strcmp(cls, 'NOT_ASSESSED')) || any(strcmp(cls, 'EXCLUDED')) || all(strcmp(cls, 'NOT_APPLICABLE'))
                    continue
                end
                lv = [obj.Rules(ks).Level];
                ok = [e(ks).pass] | strcmp(cls, 'NOT_APPLICABLE');
                L(g).level = 4;
                for Lv = unique(lv)
                    if all(ok(lv == Lv)), L(g).level = Lv; break; end
                end
            end
        end
    end
    methods (Static)
        function rs = load(folder)
            if nargin == 0
                rs = vital.rules.RuleSet(vital.fq.loadRules());
            else
                rs = vital.rules.RuleSet(vital.fq.loadRules(folder));
            end
        end
    end
end
