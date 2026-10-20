classdef Rule
%RULE  One curated MIL-F-8785C rule record as an object (0.8.1-OOP, ADR-037).
%   r = vital.rules.Rule(s)    s: one element of vital.fq.loadRules (a record
%                              of rules/mil_f_8785c/records, validated there)
%   e = r.evaluate(metrics)            at one OK condition point
%   e = r.evaluate(metrics, policy)    with the Category policy of the conditions
%   metrics is a vital.fq.metrics result (or res.points(i).metrics of
%   vital.fq.assess). e fields:
%     class   'OK' (used), 'NOT_APPLICABLE', 'EXCLUDED' (metric status not OK or
%             missing), 'NOT_ASSESSED' (Category not assessed by the policy)
%     why     exclusion reason ('metric:<status>' or the policy reason)
%     value   the metric value (NaN if none)
%     margin  min((y - lo_eff)/scale, (hi - y)/scale) over the finite bounds;
%             lo_eff = lo + slope max(0, x - threshold) with an increment
%             (Table VI); -Inf for a DIVERGENT metric; NaN unless class OK
%     pass    margin >= 0 (margin > 0 if strict); false unless class OK
%   The same rules as the vital.fq.assess engine (RULE_SCHEMA; review R2 B1 for
%   DIVERGENT), re-stated here and proven equal to the engine at the F-16 README
%   point (tests/M8/oop/tOopRules.m).
%   Errors: vital:badInput (s is not a loadRules record).
    properties (SetAccess = private)
        Id (1,:) char
        Title (1,:) char
        Paragraph (1,:) char
        Group (1,:) char
        Category (1,:) char
        Level (1,1) double
        Metric (1,:) char
        Lo (1,1) double
        Hi (1,1) double
        Strict (1,1) logical
        Scale (1,1) double
        Increment struct
        Quote (1,:) char
    end
    properties (Access = private)
        Raw struct
    end
    methods
        function obj = Rule(s)
            need = {'id', 'title', 'paragraph', 'group', 'category', 'level', 'metric', 'lo', 'hi', ...
                'strict', 'scale', 'incr', 'quote'};
            if ~isstruct(s) || ~isscalar(s) || ~all(isfield(s, need))
                error('vital:badInput', 'a Rule needs one vital.fq.loadRules record.');
            end
            obj.Raw = s;
            obj.Id = s.id; obj.Title = s.title; obj.Paragraph = s.paragraph; obj.Group = s.group;
            obj.Category = s.category; obj.Level = s.level; obj.Metric = s.metric;
            obj.Lo = s.lo; obj.Hi = s.hi; obj.Strict = s.strict; obj.Scale = s.scale;
            obj.Increment = s.incr; obj.Quote = s.quote;
        end

        function s = toStruct(obj)
            s = obj.Raw;
        end

        function e = evaluate(obj, metrics, policy)
            arguments
                obj
                metrics
                policy struct = struct()
            end
            e = struct('class', '', 'why', '', 'value', NaN, 'margin', NaN, 'pass', false);
            if isfield(policy, obj.Category) && isfield(policy.(obj.Category), 'assess') && ~policy.(obj.Category).assess
                e.class = 'NOT_ASSESSED'; e.why = 'category policy: not assessed';
                if isfield(policy.(obj.Category), 'reason'), e.why = policy.(obj.Category).reason; end
                return
            end
            [y, st] = metricOf(metrics, obj.Metric);
            lo = obj.Lo;
            if obj.Increment.has && strcmp(st, 'OK')
                [x, stx] = metricOf(metrics, obj.Increment.metric);
                if strcmp(stx, 'OK'), lo = lo + obj.Increment.slope * max(0, x - obj.Increment.threshold); else, st = stx; end
            end
            if ~isnan(y), e.value = y; end
            switch st
                case 'NOT_APPLICABLE'
                    e.class = 'NOT_APPLICABLE';
                case 'DIVERGENT'
                    e.class = 'OK'; e.margin = -Inf; e.pass = false;
                case 'OK'
                    mLo = Inf; mHi = Inf;
                    if isfinite(lo), mLo = (y - lo) / obj.Scale; end
                    if isfinite(obj.Hi), mHi = (obj.Hi - y) / obj.Scale; end
                    e.margin = min(mLo, mHi);
                    if obj.Strict, e.pass = e.margin > 0; else, e.pass = e.margin >= 0; end
                    e.class = 'OK';
                otherwise
                    e.class = 'EXCLUDED'; e.why = ['metric:' st];
            end
        end
    end
end

function [y, st] = metricOf(M, name)
if ~isstruct(M) || ~isfield(M, name)
    y = NaN; st = 'MISSING'; return
end
y = double(M.(name).value); st = M.(name).status;
if strcmp(st, 'OK') && isnan(y), st = 'NAN'; end
end
