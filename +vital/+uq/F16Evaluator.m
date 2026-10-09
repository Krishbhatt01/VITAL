classdef F16Evaluator < handle
    %F16EVALUATOR  The augmented NESC F-16 as a function of AeroScale multipliers,
    %   for the M8 uncertainty analysis. Every number comes from the whole M6/M7
    %   chain: vital.fq.f16Factory('AeroScale', s, 'Controller', b) -> trim ->
    %   closed-loop linearize -> modes -> metrics -> vital.fq.assess.
    %
    %   E = vital.uq.F16Evaluator(fields)
    %   E = vital.uq.F16Evaluator(fields, 'Rules', R, 'Conditions', C, 'Controller', b)
    %     fields      1 x d cellstr of AeroScale fields: theta(i) multiplies fields{i}
    %     Rules       default vital.fq.loadRules()
    %     Conditions  default vital.ctrl.inEnvelopeConditions()
    %     Controller  builder b(AC, env, tr); default 'augmented' =
    %                 vital.uq.augmentedBuilder() (Kq 0.02, Ka 0.14, Kr 0.82);
    %                 [] = the bare airframe
    %
    %   fac = E.factory(theta)         the aircraft factory at theta
    %   S   = E.pointSummary(theta, c) one condition point, CACHED by (theta, c):
    %         a single-point vital.fq.assess. S.status / S.stage / S.reason (the
    %         point), S.groups (group, pointClass, why, level (the group's Level
    %         at the point, NaN unless pointClass 'OK'), marginTo (1 x 3: margin
    %         to the Level-1..3 boundary = min over the group's records at that
    %         Level of their margin at the point; NOT_APPLICABLE records are
    %         ignored, Inf if none applies), recordTo (1 x 3 arg-min record ids))
    %   q   = E.groupMargin(theta, c, group, L)  q.status ('OK', or
    %         'EXCLUDED' / 'NOT_ASSESSED' / 'NOT_APPLICABLE'), q.margin (to the
    %         Level-L boundary), q.level, q.record, q.reason
    %   res = E.assessAt(theta)        a FRESH vital.fq.assess over the
    %         conditions (never cached; the confirmation of vital.uq.boundWorst)
    %   [m, cr] = vital.uq.F16Evaluator.levelMargin(res, group, L)
    %         in-envelope margin to the Level-L boundary (the M7 definition,
    %         ADR ctrl-5): min over the group's Level-L records of their
    %         in-envelope minimum margin; NaN if a record has unrated in-envelope
    %         points; Inf if no record applies. cr: record, cond, condLabel.
    %   T = vital.uq.F16Evaluator.inEnvelopeMargins(res, group, L)
    %         per in-envelope point (index, cond, label, margin, record), sorted
    %         by margin (stable): the candidate conditions of the search.
    %   lbl = vital.uq.F16Evaluator.condLabel(c)   'h_ft=13000 mach=0.45 cg_pct_mac=30'
    %   Counters: nPointEvals (single-point assessments run), nCacheHits, nAssess.
    %   Errors: vital:badInput (unknown AeroScale field, theta of the wrong size,
    %   unknown group).

    properties (SetAccess = private)
        fields
        rules
        conditions
        builder
        nPointEvals = 0
        nCacheHits = 0
        nAssess = 0
    end

    properties (Access = private)
        cache
    end

    methods
        function E = F16Evaluator(fields, opts)
            arguments
                fields cell
                opts.Rules struct = struct([])
                opts.Conditions struct = struct([])
                opts.Controller = 'augmented'
            end
            allowed = fieldnames(vital.aircraft.f16.config().aeroScale);
            if isempty(fields) || ~iscellstr(fields) || ~all(ismember(fields, allowed)) || numel(unique(fields)) < numel(fields)
                error('vital:badInput', 'fields must be distinct AeroScale fields (%s).', strjoin(allowed, ', '));
            end
            E.fields = fields(:).';
            E.rules = opts.Rules;
            if isempty(E.rules), E.rules = vital.fq.loadRules(); end
            E.conditions = opts.Conditions;
            if isempty(E.conditions), E.conditions = vital.ctrl.inEnvelopeConditions(); end
            b = opts.Controller;
            if ischar(b) && strcmp(b, 'augmented')
                b = vital.uq.augmentedBuilder();
            elseif ~isempty(b) && ~isa(b, 'function_handle')
                error('vital:badInput', 'Controller must be ''augmented'', a builder function handle, or [].');
            end
            E.builder = b;
            E.cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function fac = factory(E, theta)
            fac = vital.fq.f16Factory('AeroScale', E.scaleStruct(theta), 'Controller', E.builder);
        end

        function S = pointSummary(E, theta, c)
            k = E.key(theta, c);
            if isKey(E.cache, k)
                E.nCacheHits = E.nCacheHits + 1;
                S = E.cache(k);
                return
            end
            C1 = E.conditions;
            for a = 1:numel(C1.axes)
                C1.axes(a).values = c.(C1.axes(a).name);
            end
            res = vital.fq.assess(E.rules, E.factory(theta), C1);
            E.nPointEvals = E.nPointEvals + 1;
            p = res.points(1);
            S.status = p.status; S.stage = p.stage; S.reason = p.reason;
            S.cond = p.cond;
            G = res.groups;
            S.groups = struct('group', {}, 'pointClass', {}, 'why', {}, 'level', {}, 'marginTo', {}, 'recordTo', {});
            for g = 1:numel(G)
                e = struct('group', G(g).group, 'pointClass', G(g).pointClass{1}, 'why', '', ...
                    'level', G(g).levelAtPoint(1), 'marginTo', NaN(1, 3), 'recordTo', {{'', '', ''}});
                if ~isempty(G(g).excludedBy), e.why = G(g).excludedBy(1).reason; end
                recs = res.rules(strcmp({res.rules.group}, G(g).group));
                for L = 1:3
                    rl = recs([recs.level] == L);
                    if isempty(rl), continue; end
                    m = arrayfun(@(r) r.margin(1), rl);
                    na = cellfun(@(pc) strcmp(pc{1}, 'NOT_APPLICABLE'), {rl.pointClass});
                    m(na) = NaN;
                    if all(isnan(m))
                        if all(na), e.marginTo(L) = Inf; end
                        continue
                    end
                    [e.marginTo(L), j] = min(m);
                    e.recordTo{L} = rl(j).id;
                end
                S.groups(end+1) = e;
            end
            E.cache(k) = S;
        end

        function q = groupMargin(E, theta, c, group, L)
            S = E.pointSummary(theta, c);
            g = S.groups(strcmp({S.groups.group}, group));
            if isempty(g)
                error('vital:badInput', 'unknown group "%s".', group);
            end
            q = struct('status', 'OK', 'margin', NaN, 'level', g.level, 'record', '', 'reason', '');
            if ~strcmp(g.pointClass, 'OK')
                q.status = g.pointClass;
                if strcmp(S.status, 'OK')
                    q.reason = sprintf('group %s %s (%s)', group, g.pointClass, g.why);
                else
                    q.reason = sprintf('point %s at stage %s: %s', S.status, S.stage, S.reason);
                end
                return
            end
            q.margin = g.marginTo(L);
            q.record = g.recordTo{L};
            if isnan(q.margin)
                q.status = 'NO_RECORD';
                q.reason = sprintf('group %s has no rated Level-%d record at the point', group, L);
            end
        end

        function res = assessAt(E, theta)
            res = vital.fq.assess(E.rules, E.factory(theta), E.conditions);
            E.nAssess = E.nAssess + 1;
        end

        function s = scaleStruct(E, theta)
            if numel(theta) ~= numel(E.fields) || ~isnumeric(theta)
                error('vital:badInput', 'theta must have %d elements (%s).', numel(E.fields), strjoin(E.fields, ', '));
            end
            s = cell2struct(num2cell(double(theta(:))), E.fields(:), 1);
        end
    end

    methods (Access = private)
        function k = key(E, theta, c)
            f = fieldnames(c);
            k = [sprintf('%.17g|', theta), '#', ...
                strjoin(cellfun(@(n) sprintf('%s=%.17g', n, c.(n)), f.', 'UniformOutput', false), '|')];
            k = [k '#' sprintf('%d', numel(E.fields))];
        end
    end

    methods (Static)
        function [m, cr] = levelMargin(res, group, L)
            m = Inf;
            cr = struct('record', '', 'cond', struct(), 'condLabel', '');
            if ~any(strcmp({res.groups.group}, group))
                error('vital:badInput', 'unknown group "%s".', group);
            end
            recs = res.rules(strcmp({res.rules.group}, group) & [res.rules.level] == L);
            for r = recs(:).'
                ie = r.inEnvelope;
                if strcmp(ie.status, 'NOT_APPLICABLE'), continue; end
                if ie.nExcluded > 0 || isempty(ie.criticalIndex) || isnan(ie.minMargin)
                    m = NaN;
                    cr = struct('record', r.id, 'cond', struct(), 'condLabel', '');
                    return
                end
                if ie.minMargin < m || isempty(cr.record)
                    m = ie.minMargin;
                    cr = struct('record', r.id, 'cond', ie.critical, ...
                        'condLabel', vital.uq.F16Evaluator.condLabel(ie.critical));
                end
            end
        end

        function T = inEnvelopeMargins(res, group, L)
            idx = find(strcmp({res.points.envelope}, 'IN'));
            recs = res.rules(strcmp({res.rules.group}, group) & [res.rules.level] == L);
            n = numel(idx);
            m = Inf(n, 1); rec = repmat({''}, n, 1);
            for ii = 1:n
                for r = recs(:).'
                    v = r.margin(idx(ii));
                    if strcmp(r.pointClass{idx(ii)}, 'NOT_APPLICABLE'), continue; end
                    if isnan(v), m(ii) = NaN; rec{ii} = r.id; break; end
                    if v < m(ii) || isempty(rec{ii}), m(ii) = v; rec{ii} = r.id; end
                end
            end
            [ms, o] = sort(m);
            T = struct('index', num2cell(idx(o)).', 'cond', {res.points(idx(o)).cond}.', ...
                'label', cellfun(@(c) vital.uq.F16Evaluator.condLabel(c), {res.points(idx(o)).cond}, 'UniformOutput', false).', ...
                'margin', num2cell(ms), 'record', rec(o));
        end

        function t = condLabel(c)
            if ~isstruct(c) || isempty(fieldnames(c)), t = '(none)'; return; end
            f = fieldnames(c);
            f = f(~ismember(f, {'gamma_deg', 'g_ftps2'}));
            t = strjoin(cellfun(@(n) sprintf('%s=%g', n, c.(n)), f.', 'UniformOutput', false), ' ');
        end
    end
end
