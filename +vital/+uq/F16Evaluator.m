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
    %   res = E.assessShared(theta)    the same fresh assessment, kept per theta so
    %         that the groups confirming at one theta share it (amendment R5-5 M2:
    %         the corners of R(1)); counters nAssess (run) and nAssessHits
    %   [m, cr] = vital.uq.F16Evaluator.levelMargin(res, group, L)
    %         in-envelope margin to the Level-L boundary (the M7 definition,
    %         ADR ctrl-5): min over the group's Level-L records of their
    %         in-envelope minimum margin; NaN if a record has unrated in-envelope
    %         points; Inf if no record applies. cr: record, cond, condLabel.
    %   T = vital.uq.F16Evaluator.inEnvelopeMargins(res, group, L)
    %         per in-envelope point (index, cond, label, margin, record), sorted
    %         by margin (stable): the candidate conditions of the search.
    %   T = vital.uq.F16Evaluator.inEnvelopeSurrogate(res, group, L)
    %         the same points with field surrogate = Re of the point's spiral
    %         root (1/s), sorted most unstable first (NaN last; stable): the
    %         candidates of a +Inf group (review R3 M3: never grid order).
    %   T = vital.uq.F16Evaluator.candidates(res, group, L, mode)
    %         inEnvelopeSurrogate for mode 'surrogate', else inEnvelopeMargins.
    %   q = E.spiralPoint(theta, c)  the spiral surrogate at a point (q.status,
    %         q.value = Re of the spiral root, q.record, q.reason); S.spiralRe
    %         is kept in the cached point summary.
    %   lbl = vital.uq.F16Evaluator.condLabel(c)   'h_ft=13000 mach=0.45 cg_pct_mac=30'
    %   Counters: nPointEvals (single-point assessments run), nCacheHits, nAssess.
    %
    %   BREAKPOINT BRACKETING (M8 amendment R4b, R4-7; option 'Bracket', default
    %   true): a point whose linearization is NOT_CONVERGED with its trim alpha
    %   or elevator within 0.01 deg of a NESC aero-table breakpoint is evaluated
    %   at theta x (1 -/+ d) (vital.uq.bracket: d = 1e-3 up to 1e-2). If the two
    %   sides trim on opposite sides of the breakpoint and both are OK, the
    %   point's summary is the WORSE of the two (vital.uq.F16Evaluator.worseOf),
    %   status 'OK', S.bracket.label 'BRACKETED', and the point is listed in
    %   E.bracketed with both sides' group margins. Otherwise the point stays
    %   exactly as it was. Physical failures (trim INFEASIBLE / NOT_CONVERGED,
    %   DIVERGENT, non-classical modes) are never bracketed. Every summary has
    %   S.alpha_deg, S.de_deg (the trim; NaN without a trim) and S.bracket (the
    %   vital.uq.bracket result, or [] when the point is not a linearization
    %   failure). The fresh assessment E.assessAt is NOT bracketed.
    %   S = vital.uq.F16Evaluator.worseOf(SA, SB)  per group: pointClass OK only
    %   if both are OK (else the first non-OK side's entry), level = max,
    %   marginTo = min per Level (NaN if either is NaN), recordTo of the worse
    %   side; spiralRe = max (NaN if either is NaN).
    %   nPointEvals counts every single-point assessment, the sides included.
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
        nAssessHits = 0
        bracketOn = true
        bracketed = struct('label', {}, 'theta', {}, 'cond', {}, 'variable', {}, 'breakpoint', {}, 'd', {}, ...
            'alpha_deg', {}, 'de_deg', {}, 'sides', {}, 'reason', {})
    end

    properties (Access = private)
        cache
        raw
        fresh
    end

    methods
        function E = F16Evaluator(fields, opts)
            arguments
                fields cell
                opts.Rules struct = struct([])
                opts.Conditions struct = struct([])
                opts.Controller = 'augmented'
                opts.Bracket (1,1) logical = true
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
            E.raw = containers.Map('KeyType', 'char', 'ValueType', 'any');
            E.fresh = containers.Map('KeyType', 'char', 'ValueType', 'any');
            E.bracketOn = opts.Bracket;
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
            S = E.rawSummary(theta, c);
            S.bracket = [];
            if E.bracketOn && strcmp(S.status, 'NOT_CONVERGED') && strcmp(S.stage, 'linearize')
                b = vital.uq.bracket(S, theta, @(t) E.rawSummary(t, c));
                S.bracket = rmfield(b, 'sides');
                S.bracket.sides = arrayfun(@(x) rmfield(x, 'point'), b.sides);
                if strcmp(b.status, 'BRACKETED')
                    SA = b.sides(1).point; SB = b.sides(2).point;
                    W = vital.uq.F16Evaluator.worseOf(SA, SB);
                    S.status = 'OK'; S.stage = 'done'; S.reason = b.reason;
                    S.spiralRe = W.spiralRe; S.groups = W.groups;
                    sd = struct('factor', {b.sides.factor}, 'theta', {b.sides.theta}, 'alpha_deg', {b.sides.alpha_deg}, ...
                        'de_deg', {b.sides.de_deg}, 'groups', {E.lightGroups(SA), E.lightGroups(SB)});
                    E.bracketed(end+1) = struct('label', 'BRACKETED', 'theta', theta, ...
                        'cond', vital.uq.F16Evaluator.condLabel(c), 'variable', b.variable, 'breakpoint', b.breakpoint, ...
                        'd', b.d, 'alpha_deg', S.alpha_deg, 'de_deg', S.de_deg, 'sides', sd, 'reason', b.reason);
                end
            end
            E.cache(k) = S;
        end

        function S = rawSummary(E, theta, c)
            % one single-point assessment, never bracketed (cached separately)
            k = E.key(theta, c);
            if isKey(E.raw, k)
                S = E.raw(k);
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
            S.alpha_deg = NaN; S.de_deg = NaN;
            if isfield(p, 'info') && isstruct(p.info)
                if isfield(p.info, 'alpha_deg'), S.alpha_deg = p.info.alpha_deg; end
                if isfield(p.info, 'de_deg'), S.de_deg = p.info.de_deg; end
            end
            S.spiralRe = vital.uq.F16Evaluator.spiralRe(p);
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
            E.raw(k) = S;
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
            elseif isstruct(S.bracket) && strcmp(S.bracket.status, 'BRACKETED')
                q.reason = S.reason;                 % R4-7: an OK point labelled BRACKETED
            end
        end

        function q = spiralPoint(E, theta, c)
            % the spiral surrogate at one point (R3-M3(b); cached with the point):
            % q.status ('OK', the point's status, or 'NO_SPIRAL'), q.value (Re of
            % the spiral root, 1/s), q.record, q.reason
            S = E.pointSummary(theta, c);
            q = struct('status', 'OK', 'value', S.spiralRe, 'record', 'spiral root', 'reason', '');
            if ~strcmp(S.status, 'OK')
                q.status = S.status; q.value = NaN;
                q.reason = sprintf('point %s at stage %s: %s', S.status, S.stage, S.reason);
            elseif isnan(S.spiralRe)
                q.status = 'NO_SPIRAL';
                q.reason = 'no single mode named spiral at the point (no surrogate)';
            end
        end

        function res = assessAt(E, theta)
            res = vital.fq.assess(E.rules, E.factory(theta), E.conditions);
            E.nAssess = E.nAssess + 1;
        end

        function res = assessShared(E, theta)
            % a fresh assessment, shared by every group that confirms at the same theta
            % (amendment R5-5 M2: the corners of R(1) are the same for every lattice group);
            % deterministic, so sharing changes no value; counted in nAssess once
            k = sprintf('%.17g|', theta);
            if isKey(E.fresh, k)
                E.nAssessHits = E.nAssessHits + 1;
                res = E.fresh(k);
                return
            end
            res = E.assessAt(theta);
            E.fresh(k) = res;
        end

        function s = scaleStruct(E, theta)
            if numel(theta) ~= numel(E.fields) || ~isnumeric(theta)
                error('vital:badInput', 'theta must have %d elements (%s).', numel(E.fields), strjoin(E.fields, ', '));
            end
            s = cell2struct(num2cell(double(theta(:))), E.fields(:), 1);
        end
    end

    methods (Access = private)
        function G = lightGroups(~, S)
            % per group of a side summary: pointClass, level, marginTo, recordTo (both
            % values of a bracketed point are reported)
            G = rmfield(S.groups, 'why');
        end

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

        function T = inEnvelopeSurrogate(res, group, L)
            % the in-envelope points ranked by the spiral surrogate (R3-M3(b)):
            % surrogate = Re of the point's 'spiral' mode (NaN if the point is
            % not OK or has no single spiral mode), most unstable first (NaN last)
            T = vital.uq.F16Evaluator.inEnvelopeMargins(res, group, L);
            s = NaN(numel(T), 1);
            for ii = 1:numel(T)
                s(ii) = vital.uq.F16Evaluator.spiralRe(res.points(T(ii).index));
            end
            [~, o] = sort(-s);                  % descending, NaN last, stable
            T = T(o);
            for ii = 1:numel(T)
                T(ii).surrogate = s(o(ii));
            end
        end

        function T = candidates(res, group, L, mode)
            % candidate conditions of a search plan mode (vital.uq.searchPlan):
            % 'surrogate' -> inEnvelopeSurrogate, otherwise inEnvelopeMargins
            if strcmp(mode, 'surrogate')
                T = vital.uq.F16Evaluator.inEnvelopeSurrogate(res, group, L);
            else
                T = vital.uq.F16Evaluator.inEnvelopeMargins(res, group, L);
            end
        end

        function re = spiralRe(p)
            % real part of the 'spiral' mode of an assessed point (NaN if none)
            re = NaN;
            if isstruct(p) && isfield(p, 'status') && strcmp(p.status, 'OK') && isfield(p, 'info') ...
                    && isfield(p.info, 'modes')
                md = p.info.modes;
                k = strcmp({md.name}, 'spiral');
                if sum(k) == 1, re = md(k).re; end
            end
        end

        function S = worseOf(SA, SB)
            % R4-7: the summary of a bracketed point = the WORSE of its two sides
            S = SA;
            S.status = 'OK';
            for g = 1:numel(SA.groups)
                a = SA.groups(g);
                b = SB.groups(strcmp({SB.groups.group}, a.group));
                if isempty(b)
                    error('vital:badInput', 'group "%s" missing on one side.', a.group);
                end
                if ~strcmp(a.pointClass, 'OK')
                    S.groups(g) = a;
                    continue
                end
                if ~strcmp(b.pointClass, 'OK')
                    S.groups(g) = b;
                    continue
                end
                e = a;
                e.level = max(a.level, b.level);
                for L = 1:3
                    ma = a.marginTo(L); mb = b.marginTo(L);
                    if isnan(ma) || isnan(mb)
                        e.marginTo(L) = NaN;
                        if isnan(ma), e.recordTo{L} = a.recordTo{L}; else, e.recordTo{L} = b.recordTo{L}; end
                    elseif mb < ma
                        e.marginTo(L) = mb; e.recordTo{L} = b.recordTo{L};
                    else
                        e.marginTo(L) = ma; e.recordTo{L} = a.recordTo{L};
                    end
                end
                S.groups(g) = e;
            end
            if isnan(SA.spiralRe) || isnan(SB.spiralRe)
                S.spiralRe = NaN;
            else
                S.spiralRe = max(SA.spiralRe, SB.spiralRe);
            end
        end

        function t = condLabel(c)
            if ~isstruct(c) || isempty(fieldnames(c)), t = '(none)'; return; end
            f = fieldnames(c);
            f = f(~ismember(f, {'gamma_deg', 'g_ftps2'}));
            t = strjoin(cellfun(@(n) sprintf('%s=%g', n, c.(n)), f.', 'UniformOutput', false), ' ');
        end
    end
end
