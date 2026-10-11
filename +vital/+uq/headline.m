function L = headline(r)
%HEADLINE  The M8 headline table of a vital.uq.analyze result (Markdown lines).
%   L = vital.uq.headline(r)     cellstr
%   One row per group: nominal in-envelope Level and margin, then per width
%   (x0.5, x1, x1.5, ...; the widths are JUDGMENTS) the bound-worst margin and
%   status (tagged 'sampled only' for a binary or flat metric and 'surrogate'
%   for a +Inf group searched on Re(spiral root)), the Monte Carlo
%   successes/N with the one-sided 95 % Clopper-Pearson lower bound, and the
%   verdict. Below the table: what the bound-worst is (a search estimate, an
%   upper bound, not a proof), the box nesting, and the groups omitted for a
%   NaN headline (review R3 M2, m6, m9). Used by vital.uq.writeReport and
%   run_f16_uq.
arguments
    r (1,1) struct
end
W = r.widthScales;
h = '| group | nominal Level | nominal margin |';
s = '|---|---|---|';
for w = W
    h = [h sprintf(' x%g bound-worst (status) | x%g MC (CP lower) | x%g verdict |', w, w, w)]; %#ok<AGROW>
    s = [s '---|---|---|']; %#ok<AGROW>
end
L = {sprintf('Widths are %s multiples of the 1-sigma judgment widths (x1 = headline).', r.label), '', h, s};
for g = r.groups(:).'
    row = sprintf('| %s | %s | %s |', g.group, lvl(g.level0), num(g.margin0));
    if ~strcmp(g.status, 'DONE')
        row = [row sprintf(' %s: %s |', g.status, g.reason)]; %#ok<AGROW>
        L{end+1} = row; %#ok<AGROW>
        continue
    end
    tag = '';
    if isfield(g, 'plan') && isfield(g.plan, 'mode')
        if strcmp(g.plan.mode, 'surrogate'), tag = [tag ', surrogate']; end
        if g.plan.sampledOnly, tag = [tag ', sampled only']; end
    end
    for w = W
        x = g.widths([g.widths.widthScale] == w);
        row = [row sprintf(' %s (%s%s) | %d/%d (%.4f) | **%s** |', num(x.bw.value), x.bw.status, tag, x.mc.x, ...
            x.mc.N, x.mc.cpLower, x.verdict.verdict)]; %#ok<AGROW>
    end
    L{end+1} = row; %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = ['**The bound-worst margin is a search estimate (upper bound), not a proof:** it is the smallest margin ' ...
    'the search found (centre, 2^d corners, Latin hypercube, fmincon from the best points, re-searched at a moving ' ...
    'limit); the true minimum over the box can only be lower. "sampled only" marks a binary or flat metric (e.g. ' ...
    '3.3.1.4), where the optimizer''s convergence means nothing and the value rests on the sampled points.'];
L{end+1} = '';
L{end+1} = ['The boxes are nested (x0.5 inside x1 inside x1.5): robustness of a box implies robustness of every box ' ...
    'it contains. NOT_ASSESSABLE means "not established" (the search could not support a verdict), not "fails".'];
if isfield(r, 'omitted')
    L{end+1} = '';
    if isempty(r.omitted)
        L{end+1} = 'Groups omitted (no finite in-envelope headline Level of the nominal aircraft): none.';
    else
        L{end+1} = 'Groups omitted (no finite in-envelope headline Level of the nominal aircraft; nothing to hold):';
        for o = r.omitted(:).'
            L{end+1} = sprintf('- %s: %s', o.group, o.reason); %#ok<AGROW>
        end
    end
end
end

function t = lvl(L)
if isnan(L), t = '-'; elseif L == 4, t = 'worse than 3'; else, t = sprintf('%d', L); end
end

function t = num(v)
if isnan(v), t = 'NaN'; else, t = sprintf('%.4g', v); end
end
