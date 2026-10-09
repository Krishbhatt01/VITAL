function files = writeReport(r, folder, name)
%WRITEREPORT  Write a vital.uq.analyze result as JSON and Markdown.
%   files = vital.uq.writeReport(r, folder, name)
%   JSON: the result (Inf/-Inf as the strings "Inf"/"-Inf", NaN null; function
%   handles as text). Markdown: the JUDGMENT label of the widths, the spec
%   table with the box half-widths, the HEADLINE table per group (nominal Level,
%   bound-worst margin and status, Monte Carlo successes/N and Clopper-Pearson
%   lower bound, verdict at every width), then per group and width the active
%   set, the confirmation (and any moving limit), the optimizer exit flags and
%   the Monte Carlo failures.
%   files: struct(json, md) with the full paths.
arguments
    r (1,1) struct
    folder (1,:) char
    name (1,:) char
end
if ~isfolder(folder), mkdir(folder); end
files.json = fullfile(folder, [name '.json']);
files.md = fullfile(folder, [name '.md']);
out = r;
out.files = files;
fid = fopen(files.json, 'w', 'n', 'UTF-8');
fprintf(fid, '%s', jsonencode(sanitize(out), 'PrettyPrint', true));
fclose(fid);
L = mdLines(r);
fid = fopen(files.md, 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', L{:});
fclose(fid);
end

function x = sanitize(x)
if isstruct(x)
    if isempty(x), return; end
    f = fieldnames(x);
    y = x;
    for i = 1:numel(x)
        for k = 1:numel(f), y(i).(f{k}) = sanitize(x(i).(f{k})); end
    end
    x = y;
elseif iscell(x)
    x = cellfun(@sanitize, x, 'UniformOutput', false);
elseif isa(x, 'function_handle')
    x = func2str(x);
elseif isnumeric(x) && ~isreal(x)
    x = sanitize(struct('re', real(x), 'im', imag(x)));
elseif isnumeric(x) && any(isinf(x(:)))
    c = num2cell(x);
    c(x == Inf) = {'Inf'};
    c(x == -Inf) = {'-Inf'};
    x = c;
end
end

function L = mdLines(r)
L = {'# M8 uncertainty: does the augmented F-16''s in-envelope MIL-F-8785C Level hold?', ''};
L{end+1} = sprintf(['**The 1-sigma widths are %s (engineering judgment, docs/PLAN_M5_M8.md M8), not published ' ...
    'values.** Every Level is a REG result of the VITAL chain; only in-envelope points count.'], r.label);
L{end+1} = '';
g = r.gains;
if isfield(g, 'Kq')
    L{end+1} = sprintf('Aircraft: bare NESC F-16 + pitch SAS Kq = %g s, Ka = %g + yaw damper Kr = %g s (%s).', ...
        g.Kq, g.Ka, g.Kr, g.source);
else
    L{end+1} = sprintf('Aircraft: %s.', g.law);
end
L{end+1} = sprintf('Conditions `%s` grid `%s`: %s.', r.conditions.id, r.conditions.grid, ...
    strjoin(arrayfun(@(a) sprintf('%s %s', a.name, mat2str(a.values(:).', 6)), r.conditions.axes, 'UniformOutput', false), ', '));
o = r.options;
L{end+1} = sprintf(['Search: centre + 2^d corners + %d LHS points (seed %d) + fmincon sqp from %d best points x %d ' ...
    'evaluations, %d candidate conditions; Monte Carlo N = %d (seed %d); reserve %g; required CP lower bound %.2f. ' ...
    'Runtime %.0f s; %d single-point assessments, %d cache hits, %d full assessments.'], o.NumLHS, o.Seed, ...
    o.NumStarts, o.MaxEvals, o.NumCandidates, o.N, o.Seed, o.Reserve, o.Required, r.runtime_s, ...
    r.counts.pointEvals, r.counts.cacheHits, r.counts.assess);
L{end+1} = '';
L{end+1} = sprintf('## Uncertain parameters (%s; spec `%s`)', r.spec.label, r.spec.id);
L{end+1} = '';
W = r.widthScales;
h = '| parameter | AeroScale field | NASA term | group | sigma | d | k_g |';
s = '|---|---|---|---|---|---|---|';
for w = W, h = [h sprintf(' half-width x%g |', w)]; s = [s '---|']; end %#ok<AGROW>
L(end+1:end+2) = {h, s};
P = r.spec.parameters;
for i = 1:numel(P)
    row = sprintf('| %s | %s | %s | %s | %g | %d | %.4f |', P(i).name, P(i).aeroScale, P(i).term, P(i).group, ...
        P(i).sigma, r.spec.groups(strcmp({r.spec.groups.name}, P(i).group)).d, P(i).kg);
    for w = W, row = [row sprintf(' %.4f |', w * P(i).kg * P(i).sigma)]; end %#ok<AGROW>
    L{end+1} = row; %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = '## Headline';
L{end+1} = '';
L = [L, vital.uq.headline(r)];
L{end+1} = '';
L{end+1} = ['Verdict: ROBUST = bound-worst status OK with margin >= reserve AND Clopper-Pearson one-sided 95 % lower ' ...
    'bound >= required; NOT_ROBUST = a counterexample in the box OR the lower bound below required; ' ...
    'NOT_ASSESSABLE = anything else (e.g. the optimizer did not converge, FC-901, or a point in the box is not OK).'];
L{end+1} = '';
L{end+1} = '## Details per group';
for g = r.groups(:).'
    L{end+1} = ''; %#ok<AGROW>
    L{end+1} = sprintf('### %s', g.group); %#ok<AGROW>
    if ~strcmp(g.status, 'DONE')
        L{end+1} = sprintf('%s: %s', g.status, g.reason); %#ok<AGROW>
        continue
    end
    L{end+1} = sprintf('Nominal Level %d, margin %.6g, critical %s at %s.', g.level0, g.margin0, g.critical.record, ...
        g.critical.condLabel); %#ok<AGROW>
    L{end+1} = sprintf('Candidates: %s.', strjoin(arrayfun(@(k) sprintf('%s (%.4g)', g.candidates.labels{k}, ...
        g.candidates.margins(k)), 1:numel(g.candidates.labels), 'UniformOutput', false), '; ')); %#ok<AGROW>
    L{end+1} = ''; %#ok<AGROW>
    L{end+1} = '| width | bound-worst | status | arg-min theta | condition | record | confirmation | optimizer exit flags | points | MC x/N | not OK | worse Level | CP lower | verdict |'; %#ok<AGROW>
    L{end+1} = '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|'; %#ok<AGROW>
    for x = g.widths(:).'
        b = x.bw;
        cf = b.confirmation;
        if cf.moved, ct = sprintf('MOVING LIMIT: %.4g at %s (search %.4g)', cf.margin, cf.cond, b.searchValue);
        elseif cf.evaluated, ct = sprintf('%s %.4g', cf.status, cf.margin);
        else, ct = 'none'; end
        ex = strjoin(arrayfun(@(o) sprintf('%g', o.exitflag), b.optimizer, 'UniformOutput', false), ', ');
        L{end+1} = sprintf('| x%g | %.6g | %s | %s | %s | %s | %s | %s | %d | %d/%d | %d | %d | %.4f | %s |', ...
            x.widthScale, b.value, b.status, mat2str(b.theta, 4), b.cond, b.record, ct, ex, b.nEvaluated, ...
            x.mc.x, x.mc.N, x.mc.nNotOK, x.mc.nWorseLevel, x.mc.cpLower, x.verdict.verdict); %#ok<AGROW>
    end
    L{end+1} = ''; %#ok<AGROW>
    for x = g.widths(:).'
        L{end+1} = sprintf('- x%g: %s. Verdict reason: %s.', x.widthScale, x.bw.reason, x.verdict.reason); %#ok<AGROW>
        F = x.mc.failures;
        for k = 1:min(5, numel(F))
            L{end+1} = sprintf('  - MC sample %d not OK: %s (%s)', F(k).index, F(k).status, F(k).reason); %#ok<AGROW>
        end
        if numel(F) > 5, L{end+1} = sprintf('  - ... %d more not-OK samples (JSON)', numel(F) - 5); end %#ok<AGROW>
    end
end
L{end+1} = '';
L{end+1} = '## Nominal augmented aircraft (in-envelope headline, vital.fq.assess at theta = 1)';
L{end+1} = '';
L{end+1} = '| group | Level | critical margin | critical condition | status |';
L{end+1} = '|---|---|---|---|---|';
for n = r.nominal(:).'
    L{end+1} = sprintf('| %s | %s | %.4g | %s | %s |', n.group, n.levelText, n.criticalMargin, n.critical, n.status); %#ok<AGROW>
end
end
