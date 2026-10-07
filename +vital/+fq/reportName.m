function name = reportName(grid, aeroScale)
%REPORTNAME  Report file stem for run_f16_fq: f16_fq_<grid>_<AeroScale tag>.
%   name = vital.fq.reportName('default', struct())             'f16_fq_default_baseline'
%   name = vital.fq.reportName('readme', struct('Cm_q', 0.3))   'f16_fq_readme_Cm_q0.3'
%   The tag is 'baseline' without multipliers, otherwise <name><value> joined
%   by '_' in field order (review R2 M9: a report is named by what produced it).
%   Errors: vital:badInput (empty or unsafe grid name).
arguments
    grid (1,:) char
    aeroScale (1,1) struct
end
if isempty(grid) || ~all(isstrprop(grid, 'alphanum') | grid == '_')
    error('vital:badInput', 'grid name "%s" must be non-empty letters, digits or _.', grid);
end
f = fieldnames(aeroScale);
if isempty(f)
    tag = 'baseline';
else
    tag = strjoin(cellfun(@(n) sprintf('%s%g', n, aeroScale.(n)), f.', 'UniformOutput', false), '_');
end
name = sprintf('f16_fq_%s_%s', grid, tag);
end
