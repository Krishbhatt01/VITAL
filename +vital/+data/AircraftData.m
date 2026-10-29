classdef AircraftData
%AIRCRAFTDATA  All the data of one aircraft, as objects with units and sources
%   (value class; D1, docs/PLAN_DATA_LAYER.md, ADR-042). Aircraft-agnostic: the
%   NESC F-16, brick and cannonball are built from their NASA DAVE-ML files
%   (vital.aircraft.f16.data, vital.aircraft.nesc.brick.data, ...); later aircraft
%   (X-57) are written in the same .vital.json format and read with load().
%
%   Properties
%     name, description
%     geometry     struct of vital.data.Parameter: S, b, cbar (= aero.reference)
%     axes         struct of vital.Axis by name (bfrp root, mrc, cg, engine, ...),
%                  built from axisDefs; e.g. d.axes.cg
%     axisDefs     struct array: name, parent ('' for the root), origin (Parameter in
%                  m, in the parent's axes, with its source), dcm (C_this_parent)
%     aero         vital.data.AeroDatabase
%     propulsion   vital.data.PropulsionData (empty for an unpowered body)
%     mass         vital.data.MassData
%     controlLaws  vital.data.ControlData array (F-16: 'control', 'gnc')
%     controls     struct array: name (runtime channel, e.g. 'de'), role, varID (the
%                  data's input it drives, e.g. 'el'), limit (a field of limits)
%     limits       struct of Parameters (the runtime AC.limits: alpha_deg, de_deg, ...)
%     checkCases   all check cases (aero, propulsion), with a field 'model'
%     provenance   struct array: file (relative to the data root), sha256, role, name
%     runtime      how a vital.AircraftModel is built from the data (function NAMES in
%                  the vital namespace only): loadsFcn, components (name, kind
%                  'aero'|'propulsor', axis, fcn, channels, args), aeroScaleNames,
%                  configMeta, cgAxis, root
%     options      the builder options used (e.g. CG_PCT_MAC, BfrpOffset)
%     meta         free struct (e.g. cgPctMac)
%   Calls
%     d.aero.table('CXT').at('alpha', 5, 'el', 0)
%     d.mass.massProperties(d.axes.cg)
%     m = vital.AircraftModel.fromData(d)       the model built from the data
%     AC = d.toConfig('AeroScale', s)          the runtime AC struct (= config())
%     d.save('f16.vital.json'); d = vital.data.AircraftData.load('f16.vital.json')
%     d.summary(), d.validate(), d.verifySources('DataRoot', root), d.models(),
%     d.controlLaw('gnc'), d.toStruct(), vital.data.AircraftData.fromStruct(s)
%   The constructor VALIDATES: an object without units or provenance cannot exist
%   (vital:data:noUnits, vital:data:noProvenance; also badFormat, badRuntime).

    properties (SetAccess = private)
        name (1,:) char = ''
        description (1,:) char = ''
        options struct = struct()
        axisDefs struct = struct('name', {}, 'parent', {}, 'origin', {}, 'dcm', {})
        aero = vital.data.AeroDatabase.empty
        propulsion = vital.data.PropulsionData.empty
        mass = vital.data.MassData.empty
        controlLaws = vital.data.ControlData.empty
        controls struct = struct('name', {}, 'role', {}, 'varID', {}, 'limit', {})
        limits struct = struct()
        provenance struct = struct('file', {}, 'sha256', {}, 'role', {}, 'name', {})
        runtime struct = struct()
        meta struct = struct()
    end

    properties (Dependent)
        geometry
        axes
        checkCases
    end

    properties (Constant, Hidden)
        FORMAT = 'vital.aircraftdata'
        FORMAT_VERSION = 1
    end

    methods
        function obj = AircraftData(p)
            %AIRCRAFTDATA  d = vital.data.AircraftData(parts): parts has the fields of the
            %   properties above (geometry comes from aero.reference). Validates.
            if nargin == 0, return; end
            g = @(f, d) vital.data.internal.field(p, f, d);
            obj.name = char(p.name);
            obj.description = char(g('description', ''));
            obj.options = g('options', struct());
            obj.axisDefs = normalizeAxes(g('axisDefs', []));
            obj.aero = p.aero;
            obj.propulsion = g('propulsion', vital.data.PropulsionData.empty);
            if isempty(obj.propulsion), obj.propulsion = vital.data.PropulsionData.empty; end
            obj.mass = p.mass;
            obj.controlLaws = g('controlLaws', vital.data.ControlData.empty);
            if isempty(obj.controlLaws), obj.controlLaws = vital.data.ControlData.empty; end
            obj.controls = normalizeControls(g('controls', []));
            obj.limits = g('limits', struct());
            if isempty(obj.limits), obj.limits = struct(); end
            obj.provenance = normalizeProvenance(g('provenance', []));
            obj.runtime = normalizeRuntime(g('runtime', struct()));
            obj.meta = g('meta', struct());
            if isempty(obj.meta), obj.meta = struct(); end
            obj.validate();
        end

        function g = get.geometry(obj)
            g = obj.aero.reference;
        end

        function a = get.axes(obj)
            a = struct();
            for k = 1:numel(obj.axisDefs)
                d = obj.axisDefs(k);
                if isempty(d.parent)
                    a.(d.name) = vital.Axis(d.origin.si(), d.dcm, [], 'Name', d.name);
                else
                    a.(d.name) = vital.Axis(d.origin.si(), d.dcm, a.(d.parent), 'Name', d.name);
                end
            end
        end

        function c = get.checkCases(obj)
            c = struct('model', {}, 'name', {}, 'line', {}, 'inputs', {}, 'outputs', {}, 'internal', {});
            for m = [{obj.aero}, {obj.propulsion}]
                if isempty(m{1}), continue; end
                for x = m{1}.checkCases
                    x.model = m{1}.role;
                    c(end+1) = orderfields(x, c); %#ok<AGROW>
                end
            end
        end

        function ms = models(obj)
            %MODELS  Every DAVE-ML file object: {aero, propulsion, mass, control laws ...}
            ms = {obj.aero};
            if ~isempty(obj.propulsion), ms{end+1} = obj.propulsion; end
            ms{end+1} = obj.mass;
            for k = 1:numel(obj.controlLaws), ms{end+1} = obj.controlLaws(k); end %#ok<AGROW>
        end

        function c = controlLaw(obj, role)
            k = find(strcmp({obj.controlLaws.role}, role), 1);
            if isempty(k)
                error('vital:data:unknownName', 'aircraft ''%s'' has no control law ''%s''.', obj.name, role);
            end
            c = obj.controlLaws(k);
        end

        function validate(obj)
            w = sprintf('aircraft ''%s'': ', obj.name);
            if ~isa(obj.aero, 'vital.data.AeroDatabase') || ~isscalar(obj.aero)
                error('vital:data:badFormat', '%sneeds one AeroDatabase.', w);
            end
            if ~isa(obj.mass, 'vital.data.MassData') || ~isscalar(obj.mass)
                error('vital:data:badFormat', '%sneeds one MassData.', w);
            end
            ms = obj.models();
            for k = 1:numel(ms)
                ms{k}.validate();
            end
            names = {obj.axisDefs.name};
            if numel(unique(names)) ~= numel(names)
                error('vital:data:badFormat', '%saxis names must be unique.', w);
            end
            for k = 1:numel(obj.axisDefs)
                d = obj.axisDefs(k);
                d.origin.validate(sprintf('%saxis %s: ', w, d.name));
                if ~isempty(d.parent) && ~any(strcmp(names(1:k-1), d.parent))
                    error('vital:data:badFormat', '%saxis %s: its parent %s must be defined before it.', w, d.name, d.parent);
                end
            end
            for f = fieldnames(obj.limits).'
                obj.limits.(f{1}).validate(sprintf('%slimit %s: ', w, f{1}));
            end
            for c = obj.controls
                if ~isempty(c.limit) && ~isfield(obj.limits, c.limit)
                    error('vital:data:badFormat', '%scontrol %s: no limit %s.', w, c.name, c.limit);
                end
            end
            files = {obj.provenance.file};
            for k = 1:numel(ms)
                s = ms{k}.source;
                j = find(strcmp(files, s.file), 1);
                if isempty(j) || ~strcmp(obj.provenance(j).sha256, s.sha256)
                    error('vital:data:noProvenance', '%s%s (%s) is not in the provenance list with its SHA-256.', w, ...
                        ms{k}.role, s.file);
                end
            end
            for k = 1:numel(obj.provenance)
                if isempty(regexp(obj.provenance(k).sha256, '^[0-9a-f]{64}$', 'once'))
                    error('vital:data:noProvenance', '%sprovenance %s has no SHA-256.', w, obj.provenance(k).file);
                end
            end
            checkRuntime(obj.runtime, w);
            if ~isempty(obj.runtime.cgAxis) && ~any(strcmp(names, obj.runtime.cgAxis))
                error('vital:data:badRuntime', '%sruntime cgAxis %s is not an axis.', w, obj.runtime.cgAxis);
            end
        end

        function verifySources(obj, opts)
            %VERIFYSOURCES  Re-hash every source file (data/MANIFEST.json and the
            %   recorded SHA-256): vital:data:hashMismatch, notInManifest.
            arguments
                obj
                opts.DataRoot (1,:) char = ''
            end
            for k = 1:numel(obj.provenance)
                [~, sha] = vital.data.sourceFile(obj.provenance(k).file, 'DataRoot', opts.DataRoot);
                if ~strcmp(sha, obj.provenance(k).sha256)
                    error('vital:data:hashMismatch', '%s: SHA-256 %s, the data object was built from %s.', ...
                        obj.provenance(k).file, sha, obj.provenance(k).sha256);
                end
            end
        end

        function AC = toConfig(obj, opts)
            %TOCONFIG  The runtime AC struct of vital.plant.derivatives, from the data
            %   (field for field what vital.aircraft.f16.config returns for the F-16).
            arguments
                obj
                opts.AeroScale (1,1) struct = struct()
            end
            rt = obj.runtime;
            ax = obj.axes;
            root = ax.(rt.root);
            AC.name = obj.name;
            AC.S = obj.geometry.S.si();
            AC.b = obj.geometry.b.si();
            AC.cbar = obj.geometry.cbar.si();
            for f = rt.configMeta
                AC.(f{1}) = obj.meta.(f{1});
            end
            AC.mass = obj.mass.massSI();
            AC.J = obj.mass.inertiaSI();
            AC.r_mrc = ax.(obj.aero.mrcAxis).originIn(root);
            AC.r_cg = ax.(rt.cgAxis).originIn(root);
            if ~isempty(rt.loadsFcn), AC.loadsFcn = str2func(rt.loadsFcn); end
            lim = struct();
            for f = fieldnames(obj.limits).'
                lim.(f{1}) = obj.limits.(f{1}).value;
            end
            AC.limits = lim;
            AC.controlNames = {obj.controls.name};
            if ~isempty(rt.aeroScaleNames)
                AC.aeroScale = cell2struct(num2cell(ones(1, numel(rt.aeroScaleNames))), rt.aeroScaleNames, 2);
            end
            for f = fieldnames(opts.AeroScale).'
                if ~any(strcmp(rt.aeroScaleNames, f{1}))
                    error('vital:badInput', 'unknown AeroScale multiplier "%s" (allowed: %s).', f{1}, strjoin(rt.aeroScaleNames, ', '));
                end
                v = opts.AeroScale.(f{1});
                if ~(isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v) && v >= 0)
                    error('vital:badInput', 'AeroScale.%s must be a finite real scalar >= 0.', f{1});
                end
                AC.aeroScale.(f{1}) = double(v);
            end
        end

        function s = toStruct(obj)
            s.format = obj.FORMAT;
            s.formatVersion = obj.FORMAT_VERSION;
            s.name = obj.name;
            s.description = obj.description;
            s.options = obj.options;
            s.axes = arrayfun(@(a) struct('name', a.name, 'parent', a.parent, 'dcm', a.dcm, 'origin', a.origin.toStruct()), ...
                obj.axisDefs, 'UniformOutput', false);
            s.aero = obj.aero.toStruct();
            if isempty(obj.propulsion), s.propulsion = {}; else, s.propulsion = obj.propulsion.toStruct(); end   % {}: JSON []
            s.mass = obj.mass.toStruct();
            s.controlLaws = arrayfun(@(c) c.toStruct(), obj.controlLaws, 'UniformOutput', false);
            s.controls = obj.controls;
            s.limits = struct();
            for f = fieldnames(obj.limits).'
                s.limits.(f{1}) = obj.limits.(f{1}).toStruct();
            end
            s.provenance = obj.provenance;
            s.runtime = obj.runtime;
            s.meta = obj.meta;
        end

        function save(obj, file)
            vital.data.writeJson(file, obj.toStruct());
        end

        function S = summary(obj)
            S.name = obj.name;
            S.S_m2 = obj.geometry.S.si(); S.b_m = obj.geometry.b.si(); S.cbar_m = obj.geometry.cbar.si();
            S.mass_kg = obj.mass.massSI();
            S.J_kgm2 = obj.mass.inertiaSI();
            S.axes = {obj.axisDefs.name};
            ms = obj.models();
            S.files = cellfun(@(m) m.source.file, ms, 'UniformOutput', false);
            S.tables = sum(cellfun(@(m) numel(m.tables), ms));
            S.variables = sum(cellfun(@(m) numel(m.variables), ms));
            S.checkCases = numel(obj.checkCases);
            if nargout == 0
                fprintf('%s\n', obj.name);
                g = obj.geometry;
                fprintf('  reference: S %g %s, b %g %s, cbar %g %s  (SI: %.6g m2, %.6g m, %.6g m)\n', g.S.value, g.S.units, ...
                    g.b.value, g.b.units, g.cbar.value, g.cbar.units, S.S_m2, S.b_m, S.cbar_m);
                fprintf('  mass %.6g kg, Ixx %.6g, Iyy %.6g, Izz %.6g, Ixz %.6g kg m2\n', S.mass_kg, S.J_kgm2(1, 1), ...
                    S.J_kgm2(2, 2), S.J_kgm2(3, 3), -S.J_kgm2(1, 3));
                for a = obj.axisDefs
                    fprintf('  axis %-8s in %-6s origin %s m\n', a.name, a.parent, mat2str(a.origin.value(:).', 6));
                end
                for k = 1:numel(ms)
                    fprintf('  %-10s %3d variables, %2d tables, %2d check cases  %s\n', ms{k}.role, numel(ms{k}.variables), ...
                        numel(ms{k}.tables), numel(ms{k}.checkCases), char(ms{k}.source));
                end
                if ~isempty(obj.controls)
                    fprintf('  controls: %s\n', strjoin(arrayfun(@(c) sprintf('%s (%s, %s %s)', c.name, c.varID, ...
                        mat2str(obj.limits.(c.limit).value), obj.limits.(c.limit).units), obj.controls, 'UniformOutput', false), ', '));
                end
                clear S
            end
        end

        function disp(obj)
            if isempty(obj), fprintf('  empty AircraftData\n'); return; end
            obj.summary();
        end
    end

    methods (Static)
        function d = load(file)
            s = vital.data.readJson(file);
            d = vital.data.AircraftData.fromStruct(s);
        end

        function d = fromStruct(s)
            g = @(f, x) vital.data.internal.field(s, f, x);
            if ~isstruct(s) || ~strcmp(char(g('format', '')), vital.data.AircraftData.FORMAT)
                error('vital:data:badFormat', 'not a %s file (format "%s").', vital.data.AircraftData.FORMAT, char(g('format', '')));
            end
            if vital.data.internal.num(g('formatVersion', NaN)) ~= vital.data.AircraftData.FORMAT_VERSION
                error('vital:data:badFormat', 'formatVersion %g is not %d.', vital.data.internal.num(g('formatVersion', NaN)), ...
                    vital.data.AircraftData.FORMAT_VERSION);
            end
            p.name = char(s.name);
            p.description = char(g('description', ''));
            p.options = numStruct(g('options', struct()));
            p.axisDefs = g('axes', []);
            p.aero = vital.data.DaveModel.fromStruct(s.aero);
            pr = g('propulsion', []);
            if isempty(pr), p.propulsion = vital.data.PropulsionData.empty; else, p.propulsion = vital.data.DaveModel.fromStruct(pr); end
            p.mass = vital.data.DaveModel.fromStruct(s.mass);
            cl = vital.data.ControlData.empty;
            for c = vital.data.internal.asList(g('controlLaws', []))
                cl(end+1) = vital.data.DaveModel.fromStruct(c{1}); %#ok<AGROW>
            end
            p.controlLaws = cl;
            p.controls = g('controls', []);
            lim = struct();
            L = g('limits', struct());
            if isstruct(L)
                for f = fieldnames(L).'
                    lim.(f{1}) = vital.data.Parameter.fromStruct(L.(f{1}));
                end
            end
            p.limits = lim;
            p.provenance = g('provenance', []);
            p.runtime = g('runtime', struct());
            p.meta = numStruct(g('meta', struct()));
            d = vital.data.AircraftData(p);
        end
    end
end

% ============================================================================
function A = normalizeAxes(raw)
A = struct('name', {}, 'parent', {}, 'origin', {}, 'dcm', {});
for c = vital.data.internal.asList(raw)
    a = c{1};
    o = a.origin;
    if ~isa(o, 'vital.data.Parameter'), o = vital.data.Parameter.fromStruct(o); end
    dcm = vital.data.internal.num(vital.data.internal.field(a, 'dcm', eye(3)));
    A(end+1) = struct('name', char(a.name), 'parent', char(vital.data.internal.field(a, 'parent', '')), ...
        'origin', o, 'dcm', dcm); %#ok<AGROW>
end
A = reshape(A, 1, []);
end

function C = normalizeControls(raw)
C = struct('name', {}, 'role', {}, 'varID', {}, 'limit', {});
for c = vital.data.internal.asList(raw)
    g = @(f) char(vital.data.internal.field(c{1}, f, ''));
    C(end+1) = struct('name', g('name'), 'role', g('role'), 'varID', g('varID'), 'limit', g('limit')); %#ok<AGROW>
end
C = reshape(C, 1, []);
end

function P = normalizeProvenance(raw)
P = struct('file', {}, 'sha256', {}, 'role', {}, 'name', {});
for c = vital.data.internal.asList(raw)
    g = @(f) char(vital.data.internal.field(c{1}, f, ''));
    P(end+1) = struct('file', strrep(g('file'), '\', '/'), 'sha256', g('sha256'), 'role', g('role'), 'name', g('name')); %#ok<AGROW>
end
P = reshape(P, 1, []);
end

function R = normalizeRuntime(raw)
g = @(f, d) vital.data.internal.field(raw, f, d);
R.loadsFcn = char(g('loadsFcn', ''));
comps = struct('name', {}, 'kind', {}, 'axis', {}, 'fcn', {}, 'channels', {}, 'args', {});
for c = vital.data.internal.asList(g('components', []))
    h = @(f, d) vital.data.internal.field(c{1}, f, d);
    comps(end+1) = struct('name', char(h('name', '')), 'kind', char(h('kind', '')), 'axis', char(h('axis', '')), ...
        'fcn', char(h('fcn', '')), 'channels', {vital.data.internal.asCellstr(h('channels', {}))}, ...
        'args', char(h('args', ''))); %#ok<AGROW>
end
R.components = reshape(comps, 1, []);
R.aeroScaleNames = vital.data.internal.asCellstr(g('aeroScaleNames', {}));
R.configMeta = vital.data.internal.asCellstr(g('configMeta', {}));
R.cgAxis = char(g('cgAxis', 'cg'));
R.root = char(g('root', 'bfrp'));
end

function checkRuntime(R, w)
ok = @(f) isempty(f) || ~isempty(regexp(f, '^vital(\.[A-Za-z]\w*)+$', 'once'));
if ~ok(R.loadsFcn)
    error('vital:data:badRuntime', '%sruntime loadsFcn "%s" is not a function in the vital namespace.', w, R.loadsFcn);
end
for c = R.components
    if ~ok(c.fcn) || isempty(c.fcn)
        error('vital:data:badRuntime', '%sruntime component %s: "%s" is not a function in the vital namespace.', w, c.name, c.fcn);
    end
    if ~any(strcmp(c.kind, {'aero', 'propulsor'})) || ~any(strcmp(c.args, {'', 'config'}))
        error('vital:data:badRuntime', '%sruntime component %s: kind "%s" / args "%s" not supported.', w, c.name, c.kind, c.args);
    end
end
end

function s = numStruct(s)
% decode the numbers of a flat struct (options, meta) written by vital.data.writeJson
if ~isstruct(s) || isempty(s), s = struct(); return; end
for f = fieldnames(s).'
    v = s.(f{1});
    if isnumeric(v) || (isstruct(v) && isfield(v, 'size')) || (ischar(v) && any(strcmp(v, {'NaN', 'Inf', '-Inf'})))
        s.(f{1}) = vital.data.internal.num(v);
    end
end
end
