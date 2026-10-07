function C = loadConditions(file, opts)
%LOADCONDITIONS  Load a registered condition space (JSON) and select a grid.
%   C = vital.fq.loadConditions()                         default grid
%   C = vital.fq.loadConditions(file, 'Grid', 'test')     a named grid
%   C = vital.fq.loadConditions(file, 'Axes', struct('h_ft', [5000 15000], ...
%         'mach', [0.4 0.6], 'cg_pct_mac', 25))           a user grid (axis
%                                                          order = field order)
%   File fields: id, model, fixed (added to every point), category_policy
%   (A/B/C: {assess, reason}), ofe_proxy (text), grids.<name>.<axis> = values.
%   C fields: id, file, grid, model, axes (struct array name/values), fixed,
%   categoryPolicy, ofe, validity (the model's validity envelope {description,
%   judgment, bounds(quantity, min, max)}, or [] when the file has none),
%   points (vital.fq.gridPoints).
%   Errors: vital:fq:badConditions (unknown grid, bad axes).
arguments
    file (1,:) char = fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json')
    opts.Grid (1,:) char = 'default'
    opts.Axes struct = struct([])
end
raw = jsondecode(fileread(file));
C.id = raw.id;
C.file = file;
C.model = raw.model;
if isempty(opts.Axes)
    if ~isfield(raw.grids, opts.Grid)
        error('vital:fq:badConditions', 'no grid "%s" in %s (have: %s).', opts.Grid, file, ...
            strjoin(fieldnames(raw.grids), ', '));
    end
    G = raw.grids.(opts.Grid);
    C.grid = opts.Grid;
else
    G = opts.Axes;
    C.grid = 'user';
end
an = fieldnames(G).';
vals = cellfun(@(f) double(G.(f)(:).'), an, 'UniformOutput', false);
C.axes = struct('name', an, 'values', vals);
C.fixed = raw.fixed;
C.categoryPolicy = raw.category_policy;
C.ofe = raw.ofe_proxy;
C.validity = [];
if isfield(raw, 'validity'), C.validity = raw.validity; end
C.points = vital.fq.gridPoints(C);
end
