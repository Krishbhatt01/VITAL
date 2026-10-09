function L = headline(r)
%HEADLINE  The M8 headline table of a vital.uq.analyze result (Markdown lines).
%   L = vital.uq.headline(r)     cellstr
%   One row per group: nominal in-envelope Level and margin, then per width
%   (x0.5, x1, x1.5, ...; the widths are JUDGMENTS) the bound-worst margin and
%   status, the Monte Carlo successes/N with the one-sided 95 % Clopper-Pearson
%   lower bound, and the verdict. Used by vital.uq.writeReport and run_f16_uq.
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
    for w = W
        x = g.widths([g.widths.widthScale] == w);
        row = [row sprintf(' %s (%s) | %d/%d (%.4f) | **%s** |', num(x.bw.value), x.bw.status, x.mc.x, x.mc.N, ...
            x.mc.cpLower, x.verdict.verdict)]; %#ok<AGROW>
    end
    L{end+1} = row; %#ok<AGROW>
end
end

function t = lvl(L)
if isnan(L), t = '-'; elseif L == 4, t = 'worse than 3'; else, t = sprintf('%d', L); end
end

function t = num(v)
if isnan(v), t = 'NaN'; else, t = sprintf('%.4g', v); end
end
