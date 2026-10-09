function spec = loadSpec(file)
%LOADSPEC  Load the uncertainty specification of the M8 analysis (JSON).
%   spec = vital.uq.loadSpec()        <root>\uq\f16_uncertainty.json
%   spec = vital.uq.loadSpec(file)
%
%   The 1-sigma widths are ENGINEERING JUDGMENTS (docs/PLAN_M5_M8.md, M8), not
%   published values; the file must say so (label "JUDGMENT").
%   File fields: id, label ('JUDGMENT'), source, rationale, distribution,
%   coverage (0 < c < 1), groups[] {name, parameters[] {name, aeroScale, term,
%   sigma > 0}}. aeroScale must be an AeroScale field accepted by
%   vital.aircraft.f16.config; a field may appear only once.
%   spec fields: id, label, source, rationale, distribution, coverage, file,
%     groups (struct array: name, d (number of parameters), kg =
%     sqrt(chi2inv(coverage, d)), parameters (name, aeroScale, term, sigma)),
%     parameters (flat struct array in group order: name, aeroScale, term,
%     sigma, group, kg).
%   Errors: vital:uq:badSpec (missing file or field, label not JUDGMENT, sigma
%   not finite > 0, coverage outside (0, 1), unknown or repeated AeroScale field).
arguments
    file (1,:) char = fullfile(vital.paths('root'), 'uq', 'f16_uncertainty.json')
end
if ~isfile(file)
    error('vital:uq:badSpec', 'uncertainty specification "%s" not found.', file);
end
try
    raw = jsondecode(fileread(file));
catch err
    error('vital:uq:badSpec', 'uncertainty specification "%s" is not valid JSON: %s', file, err.message);
end
need(raw, {'id', 'label', 'source', 'coverage', 'groups'}, 'specification');
if ~strcmp(raw.label, 'JUDGMENT')
    error('vital:uq:badSpec', ['the uncertainty widths are engineering judgments: the specification must be ' ...
        'labelled "JUDGMENT", not "%s".'], char(string(raw.label)));
end
c = raw.coverage;
if ~(isnumeric(c) && isscalar(c) && isfinite(c) && c > 0 && c < 1)
    error('vital:uq:badSpec', 'coverage must be a number in (0, 1).');
end
spec.id = raw.id;
spec.label = raw.label;
spec.source = raw.source;
spec.rationale = opt(raw, 'rationale');
spec.distribution = opt(raw, 'distribution');
spec.coverage = c;
spec.file = file;
G = raw.groups;
if isstruct(G), G = num2cell(G); end
if isempty(G)
    error('vital:uq:badSpec', 'the specification has no group.');
end
spec.groups = struct('name', {}, 'd', {}, 'kg', {}, 'parameters', {});
spec.parameters = struct('name', {}, 'aeroScale', {}, 'term', {}, 'sigma', {}, 'group', {}, 'kg', {});
allowed = fieldnames(vital.aircraft.f16.config().aeroScale);
for i = 1:numel(G)
    g = G{i};
    need(g, {'name', 'parameters'}, sprintf('group %d', i));
    P = g.parameters;
    if isstruct(P), P = num2cell(P); end
    if isempty(P)
        error('vital:uq:badSpec', 'group "%s" has no parameter.', g.name);
    end
    d = numel(P);
    kg = sqrt(chi2inv(c, d));
    pars = struct('name', {}, 'aeroScale', {}, 'term', {}, 'sigma', {});
    for k = 1:d
        p = P{k};
        need(p, {'name', 'aeroScale', 'term', 'sigma'}, sprintf('group "%s" parameter %d', g.name, k));
        s = p.sigma;
        if ~(isnumeric(s) && isscalar(s) && isfinite(s) && s > 0)
            error('vital:uq:badSpec', 'parameter "%s": sigma must be a finite number > 0.', p.name);
        end
        if ~any(strcmp(p.aeroScale, allowed))
            error('vital:uq:badSpec', 'parameter "%s": "%s" is not an AeroScale field (allowed: %s).', ...
                p.name, p.aeroScale, strjoin(allowed, ', '));
        end
        if any(strcmp(p.aeroScale, {spec.parameters.aeroScale})) || any(strcmp(p.aeroScale, {pars.aeroScale}))
            error('vital:uq:badSpec', 'AeroScale field "%s" appears twice.', p.aeroScale);
        end
        pars(end+1) = struct('name', p.name, 'aeroScale', p.aeroScale, 'term', p.term, 'sigma', double(s)); %#ok<AGROW>
    end
    spec.groups(end+1) = struct('name', g.name, 'd', d, 'kg', kg, 'parameters', pars);
    for k = 1:d
        spec.parameters(end+1) = struct('name', pars(k).name, 'aeroScale', pars(k).aeroScale, 'term', pars(k).term, ...
            'sigma', pars(k).sigma, 'group', g.name, 'kg', kg);
    end
end
if numel(unique({spec.parameters.name})) < numel(spec.parameters)
    error('vital:uq:badSpec', 'a parameter name appears twice.');
end
end

function need(s, f, what)
for k = 1:numel(f)
    if ~isstruct(s) || ~isfield(s, f{k})
        error('vital:uq:badSpec', '%s: missing field "%s".', what, f{k});
    end
end
end

function v = opt(s, f)
if isfield(s, f), v = s.(f); else, v = ''; end
end
