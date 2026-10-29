classdef AircraftModel
%AIRCRAFTMODEL  An aircraft as an axis tree, components and mass properties
%   (value class; docs/PLAN_CORE_FRAMES.md, ADR-040). Nothing in it is F-16 specific.
%   m = vital.AircraftModel(name, axes, components, massProps, controls, ...
%                           'Ref', struct('S', S, 'b', b, 'cbar', cbar), ...
%                           'Limits', limits, 'Meta', meta, 'Root', 'bfrp')
%     axes        vital.Axis array: the fixed tree rooted at the BFRP (body-parallel,
%                 CONVENTIONS 2); every axis has a unique name
%     components  cell array of vital.Component (each in one of the axes)
%     massProps   vital.MassProperties (its CG axis is in the tree)
%     controls    cellstr of control channel names, e.g. {'de','da','dr','throttle'}
%   The constructor validates (m.validate()): unique axis names
%   (vital:model:duplicateAxis), every axis, component axis and the CG axis in the
%   tree (vital:model:axisOutsideTree), every component channel a control
%   (vital:model:unknownControl), unique component names
%   (vital:model:duplicateComponent).
%
%   Object path (the DEFINITION; builds Loads objects):
%     Ls = m.componentLoads(x, u, env)        cell of vital.Loads, each in its own axis
%     L  = m.loadsTotal(x, u, env, axis)      components + weight, transferred
%                                             explicitly to axis (vital.Axis or a name;
%                                             default the root). NO d'Alembert terms.
%     [xdot, y] = m.derivativesObject(x, u, env)
%   Compiled path (the fast path, proven equal to the object path in the tests):
%     m = m.compile()                         numeric DCMs and offsets of every
%                                             component axis to the root, the CG and
%                                             the inertia, rebuilt from the axes on
%                                             EVERY call (never cached by name)
%     [xdot, y] = m.derivatives(x, u, env)    compiled if m is compiled, else the
%                                             object path. x, u, env and y as
%                                             vital.plant.derivatives (u ordered as
%                                             m.Controls, or a struct by name), plus
%                                             y.F_R, y.M_R (3xK, root/BFRP axes, about
%                                             the root) and y.componentNames.
%   The model IS the aircraft (ADR-043, increment I1): hand it to the plant,
%     [xdot, y] = vital.plant.derivatives(x, u, m, env)   (= m.derivatives, compiled)
%   with u a vector of numel(m.Controls) in that order or a struct by name; y has
%   every field of the struct path (incl. F_aero, M_aero, F_prop, M_prop, coeff,
%   thrust_lbf, summed by component Kind; NaN when a component is 'unclassified').
%   Bridge to the existing functional consumers (trim, linearize, sim, fq, uq):
%     AC = m.toRuntime()   the legacy AC struct: copies of S, b, cbar, mass, J,
%                          r_cg, r_mrc (the origin of the first 'aero' component;
%                          informational, finding F-6), limits, controlNames,
%                          Meta (e.g. aeroScale), PLUS AC.runtimeModel (this model,
%                          compiled). vital.plant.derivatives and
%                          derivativesRotating evaluate AC.runtimeModel; the copied
%                          fields are never the truth, so the plant refuses a struct
%                          whose S, b, cbar, mass, J, r_cg, r_mrc, aeroScale,
%                          controlNames or loadsFcn were edited
%                          (vital:model:staleRuntime; limits and name may be edited).
%                          AC.loadsFcn cannot be called on its own
%                          (vital:model:runtimeLoadsFcn: a context needs the state).
%   Edits return new (uncompiled) models: m.withComponentEnabled(name, tf).
%   Lookups: m.axis(name), m.component(name).

    properties (SetAccess = private)
        Name (1,:) char = 'aircraft'
        Axes
        Components cell = {}
        MassProps
        Controls cell = {}
        Ref struct = struct('S', 1, 'b', 1, 'cbar', 1)
        Limits struct = struct()
        Meta struct = struct()
        RootName (1,:) char = 'bfrp'
        Compiled = []
    end

    methods
        function obj = AircraftModel(name, axes, components, massProps, controls, opts)
            arguments
                name
                axes
                components
                massProps
                controls
                opts.Ref (1,1) struct = struct('S', 1, 'b', 1, 'cbar', 1)
                opts.Limits (1,1) struct = struct()
                opts.Meta (1,1) struct = struct()
                opts.Root = 'bfrp'
            end
            if ~isa(axes, 'vital.Axis')
                error('vital:badInput', 'axes must be a vital.Axis array.');
            end
            if ~iscell(components), components = num2cell(components); end
            if ~isa(massProps, 'vital.MassProperties') || ~isscalar(massProps)
                error('vital:badInput', 'massProps must be a single vital.MassProperties.');
            end
            obj.Name = char(name);
            obj.Axes = axes(:).';
            obj.Components = components(:).';
            obj.MassProps = massProps;
            obj.Controls = cellstr(controls(:).');
            obj.Ref = opts.Ref;
            obj.Limits = opts.Limits;
            obj.Meta = opts.Meta;
            obj.RootName = char(opts.Root);
            obj.validate();
        end

        function validate(obj)
            names = {obj.Axes.Name};
            [u, ~, j] = unique(names);
            dup = u(accumarray(j(:), 1) > 1);
            if ~isempty(dup)
                error('vital:model:duplicateAxis', 'axis name(s) used more than once: %s.', strjoin(dup, ', '));
            end
            iRoot = find(strcmp(names, obj.RootName));
            if isempty(iRoot) || ~isempty(obj.Axes(iRoot).Parent)
                error('vital:model:axisOutsideTree', 'the model needs a root axis named ''%s''.', obj.RootName);
            end
            root = obj.Axes(iRoot);
            for k = 1:numel(obj.Axes)
                a = obj.Axes(k);
                if ~isequal(a.rootAxis(), root)
                    error('vital:model:axisOutsideTree', 'axis ''%s'' is not in the tree of ''%s''.', a.Name, obj.RootName);
                end
                if ~isempty(a.Parent) && ~obj.hasAxis(a.Parent)
                    error('vital:model:axisOutsideTree', 'the parent ''%s'' of axis ''%s'' is not one of the model''s axes.', ...
                        a.Parent.Name, a.Name);
                end
            end
            if ~obj.hasAxis(obj.MassProps.CgAxis)
                error('vital:model:axisOutsideTree', 'the CG axis ''%s'' is not one of the model''s axes.', obj.MassProps.CgAxis.Name);
            end
            if ~isempty(obj.MassProps.Inertia.Axis) && ~isequal(obj.MassProps.Inertia.Axis.rootAxis(), root)
                error('vital:model:axisOutsideTree', 'the inertia axis is not in the tree of ''%s''.', obj.RootName);
            end
            if numel(unique(obj.Controls)) ~= numel(obj.Controls)
                error('vital:badInput', 'control names must be unique.');
            end
            cn = cell(1, numel(obj.Components));
            for k = 1:numel(obj.Components)
                c = obj.Components{k};
                if ~isa(c, 'vital.Component')
                    error('vital:badInput', 'components{%d} is not a vital.Component.', k);
                end
                cn{k} = c.Name;
                if ~obj.hasAxis(c.Axis)
                    error('vital:model:axisOutsideTree', 'component ''%s'': its axis ''%s'' is not one of the model''s axes.', ...
                        c.Name, c.Axis.Name);
                end
                bad = setdiff(c.Channels, obj.Controls);
                if ~isempty(bad)
                    error('vital:model:unknownControl', 'component ''%s'' reads unknown control(s) %s (model controls: %s).', ...
                        c.Name, strjoin(bad, ', '), strjoin(obj.Controls, ', '));
                end
            end
            if numel(unique(cn)) ~= numel(cn)
                error('vital:model:duplicateComponent', 'component names must be unique.');
            end
        end

        function a = axis(obj, name)
            k = find(strcmp({obj.Axes.Name}, name), 1);
            if isempty(k)
                error('vital:model:unknownAxis', 'no axis ''%s'' in model ''%s''.', name, obj.Name);
            end
            a = obj.Axes(k);
        end

        function c = component(obj, name)
            k = find(cellfun(@(c) strcmp(c.Name, name), obj.Components), 1);
            if isempty(k)
                error('vital:model:unknownComponent', 'no component ''%s'' in model ''%s''.', name, obj.Name);
            end
            c = obj.Components{k};
        end

        function tf = isCompiled(obj)
            tf = ~isempty(obj.Compiled);
        end

        function obj = compile(obj)
            %COMPILE  Numeric DCMs and offsets of every component axis to the root.
            root = obj.axis(obj.RootName);
            n = numel(obj.Components);
            c.names = cell(1, n);
            c.C = zeros(3, 3, n);
            c.r = zeros(3, n);
            c.identity = false(1, n);
            for k = 1:n
                comp = obj.Components{k};
                [C, r] = chainPose(comp.Axis, root);
                c.names{k} = comp.Name;
                c.C(:, :, k) = C;
                c.r(:, k) = r;
                c.identity(k) = isequal(C, eye(3));
            end
            c.comps = obj.Components;
            c.enabled = cellfun(@(x) x.Enabled, obj.Components);
            kinds = cellfun(@(x) x.Kind, obj.Components, 'UniformOutput', false);
            c.isAero = strcmp(kinds, 'aero');
            c.isProp = strcmp(kinds, 'propulsion');
            c.iAero = find(c.isAero);
            c.iProp = find(c.isProp);
            c.unclassified = any(strcmp(kinds, 'unclassified'));
            mp = obj.MassProps;
            [~, rcg] = chainPose(mp.CgAxis, root);
            c.r_cg = rcg;
            c.mass = mp.Mass;
            c.J = mp.about(vital.Axis(rcg, eye(3), root, 'Name', 'cg_body'));
            c.ref = obj.Ref;
            c.controls = obj.Controls;
            % the toRuntime guard (ADR-043): the physical fields a toRuntime struct
            % copies, as ONE stored numeric fingerprint, plus names and aeroScale
            if isempty(c.iAero), c.r_mrc = zeros(3, 1); else, c.r_mrc = c.r(:, c.iAero(1)); end
            c.fingerprint = [obj.Ref.S; obj.Ref.b; obj.Ref.cbar; c.mass; c.J(:); c.r_cg(:); c.r_mrc(:)];
            c.hasAeroScale = isfield(obj.Meta, 'aeroScale');
            c.aeroScale = [];
            if c.hasAeroScale, c.aeroScale = obj.Meta.aeroScale; end
            obj.Compiled = c;
        end

        function m = withComponentEnabled(obj, name, tf)
            m = obj;
            k = find(cellfun(@(c) strcmp(c.Name, name), obj.Components), 1);
            if isempty(k)
                error('vital:model:unknownComponent', 'no component ''%s'' in model ''%s''.', name, obj.Name);
            end
            m.Components{k} = m.Components{k}.withEnabled(tf);
            m.Compiled = [];
        end

        function fl = flight(obj, x, u, env)
            fl = vital.FlightContext(x, u, env, obj.Controls, obj.Ref);
        end

        function Ls = componentLoads(obj, x, u, env)
            fl = obj.flight(x, u, env);
            Ls = cellfun(@(c) c.loads(fl), obj.Components, 'UniformOutput', false);
        end

        function L = loadsTotal(obj, x, u, env, ax)
            %LOADSTOTAL  Components + weight about ax (default the root). Object path.
            if nargin < 5, ax = obj.RootName; end
            if ~isa(ax, 'vital.Axis'), ax = obj.axis(ax); end
            L = obj.loadsTotalAt(obj.flight(x, u, env), ax);
        end

        function [xdot, y] = derivatives(obj, x, u, env)
            c = obj.Compiled;
            if isempty(c)
                [xdot, y] = obj.derivativesObject(x, u, env);
                return
            end
            fl = vital.FlightContext(x, u, env, c.controls, c.ref);
            [F_R, M_R, oe, infos, M_own] = vital.AircraftModel.compiledLoads(c, fl);
            if any(~isfinite(F_R(:))) || any(~isfinite(M_R(:)))
                error('vital:plant:nonFinite', 'aircraft loads are not finite at this state.');
            end
            x = fl.X;
            [F_b, M_cg] = vital.loads.sumLoadsAtCG(F_R, M_R, c.r_cg, c.mass, fl.C_bn, [0; 0; env.g]);
            xdot = vital.eom.rigidBodyDerivs(x(1:3), x(4:6), x(7:10), F_b, M_cg, c.mass, c.J);
            if any(~isfinite(xdot))
                error('vital:plant:nonFinite', 'state derivative is not finite.');
            end
            if nargout > 1
                [Fa, Ma, Fp, Mp, MaR, cf, th] = vital.AircraftModel.kindSums(c, F_R, M_R, M_own, infos);
                y = vital.AircraftModel.diagnostics(fl, F_R, M_R, F_b, M_cg, oe, c.mass, env, c.names, Fa, Ma, Fp, Mp, MaR, cf, th);
            end
        end

        function [xdot, y] = derivativesObject(obj, x, u, env)
            %DERIVATIVESOBJECT  The object path: Loads objects all the way.
            fl = obj.flight(x, u, env);
            root = obj.axis(obj.RootName);
            mp = obj.MassProps;
            cgBody = vital.Axis(mp.CgAxis.originIn(root), eye(3), root, 'Name', 'cg_body');
            L = obj.loadsTotalAt(fl, cgBody);
            J = mp.about(cgBody);
            x = fl.X;
            xdot = vital.eom.rigidBodyDerivs(x(1:3), x(4:6), x(7:10), L.F, L.M, mp.Mass, J);
            if any(~isfinite(xdot))
                error('vital:plant:nonFinite', 'state derivative is not finite.');
            end
            if nargout > 1
                n = numel(obj.Components);
                F_R = zeros(3, n); M_R = zeros(3, n); M_own = zeros(3, n); oe = false; names = cell(1, n);
                infos = cell(1, n); kinds = cell(1, n);
                for k = 1:n
                    comp = obj.Components{k};
                    [~, M, info] = comp.loadsNumeric(fl);
                    Lr = comp.loads(fl).transform(root);
                    F_R(:, k) = Lr.F; M_R(:, k) = Lr.M; oe = oe || info.outOfEnvelope; names{k} = comp.Name;
                    M_own(:, k) = comp.Axis.dcmTo(root) * M;
                    infos{k} = info; kinds{k} = comp.Kind;
                end
                ck.iAero = find(strcmp(kinds, 'aero')); ck.iProp = find(strcmp(kinds, 'propulsion'));
                ck.unclassified = any(strcmp(kinds, 'unclassified'));
                [Fa, Ma, Fp, Mp, MaR, cf, th] = vital.AircraftModel.kindSums(ck, F_R, M_R, M_own, infos);
                y = vital.AircraftModel.diagnostics(fl, F_R, M_R, L.F, L.M, oe, mp.Mass, env, names, Fa, Ma, Fp, Mp, MaR, cf, th);
            end
        end

        function AC = toRuntime(obj)
            %TORUNTIME  The AC struct of vital.plant.derivatives, evaluating this model.
            if isempty(obj.Compiled), obj = obj.compile(); end
            c = obj.Compiled;
            AC = obj.Meta;
            AC.name = obj.Name;
            AC.S = obj.Ref.S; AC.b = obj.Ref.b; AC.cbar = obj.Ref.cbar;
            AC.mass = c.mass;
            AC.J = c.J;
            AC.r_cg = c.r_cg;
            AC.r_mrc = c.r_mrc;
            AC.limits = obj.Limits;
            AC.controlNames = obj.Controls;
            AC.loadsFcn = @vital.AircraftModel.runtimeLoadsFcn;
            AC.runtimeModel = obj;
        end

        function s = toStruct(obj)
            s.name = obj.Name;
            s.root = obj.RootName;
            s.axes = arrayfun(@(a) a.toStruct(), obj.Axes);
            s.components = cellfun(@(c) c.toStruct(), obj.Components);
            s.massProps = obj.MassProps.toStruct();
            s.controls = obj.Controls;
            s.ref = obj.Ref;
            s.compiled = obj.isCompiled();
        end

        function disp(obj)
            fprintf('  AircraftModel ''%s'' (root ''%s'', %s)\n', obj.Name, obj.RootName, ...
                char(string(obj.isCompiled()).replace("true", "compiled").replace("false", "not compiled")));
            fprintf('  axes:\n');
            disp(obj.Axes);
            fprintf('  components:\n');
            for k = 1:numel(obj.Components)
                c = obj.Components{k};
                fprintf('    %-12s %-22s axis ''%s'', channels {%s}, enabled %d\n', c.Name, class(c), c.Axis.Name, ...
                    strjoin(c.Channels, ', '), c.Enabled);
            end
            fprintf('  controls: {%s}\n', strjoin(obj.Controls, ', '));
            disp(obj.MassProps);
        end
    end

    methods (Static)
        function m = fromData(data, opts)
            %FROMDATA  The model built from a vital.data.AircraftData (D1; ADR-042).
            %   m = vital.AircraftModel.fromData(d)
            %   m = vital.AircraftModel.fromData(d, 'AeroScale', struct('Cm_q', 0.5))
            %   Nothing aircraft-specific here: the axes are d.axes (in d.axisDefs order),
            %   the mass properties d.mass.massProperties(d.axes.(d.runtime.cgAxis)), the
            %   components those of d.runtime.components (an 'aero' component gets
            %   CoeffArgs {AC} when its args are 'config', with AC = d.toConfig(AeroScale),
            %   and the reference geometry of d.geometry; a 'propulsor' its channel), the
            %   controls d.controls, the limits AC.limits. Returned COMPILED. For the F-16
            %   the result is bitwise the 0.9.1-CORE model (tests/M9/data/tDataModel.m).
            %   Errors: vital:data:noRuntime (the data declare no runtime components),
            %   vital:badInput (unknown AeroScale name).
            arguments
                data (1,1) vital.data.AircraftData
                opts.AeroScale (1,1) struct = struct()
            end
            rt = data.runtime;
            if isempty(rt.components)
                error('vital:data:noRuntime', ['aircraft ''%s'' declares no runtime components ' ...
                    '(runtime.components), so no AircraftModel can be built from it.'], data.name);
            end
            AC = data.toConfig('AeroScale', opts.AeroScale);
            ax = data.axes;
            axList = cellfun(@(n) ax.(n), {data.axisDefs.name});
            comps = cell(1, numel(rt.components));
            for k = 1:numel(rt.components)
                c = rt.components(k);
                fh = str2func(c.fcn);
                switch c.kind
                    case 'aero'
                        args = {};
                        if strcmp(c.args, 'config'), args = {AC}; end
                        comps{k} = vital.AeroTableComponent(c.name, ax.(c.axis), fh, 'CoeffArgs', args, ...
                            'S', AC.S, 'b', AC.b, 'cbar', AC.cbar, 'Channels', c.channels);
                    case 'propulsor'
                        comps{k} = vital.PropulsorComponent(c.name, ax.(c.axis), fh, c.channels{1});
                end
            end
            axis_cg = ax.(rt.cgAxis);
            mp = data.mass.massProperties(axis_cg);
            meta = struct();
            for f = rt.configMeta
                meta.(f{1}) = AC.(f{1});
            end
            if isfield(AC, 'aeroScale'), meta.aeroScale = AC.aeroScale; end
            meta.source = sprintf('vital.data.AircraftData ''%s'' (vital.AircraftModel.fromData)', data.name);
            m = vital.AircraftModel(data.name, axList, comps, mp, AC.controlNames, ...
                'Ref', struct('S', AC.S, 'b', AC.b, 'cbar', AC.cbar), 'Limits', AC.limits, 'Meta', meta, 'Root', rt.root);
            m = m.compile();
        end
    end

    methods (Access = private)
        function tf = hasAxis(obj, a)
            k = find(strcmp({obj.Axes.Name}, a.Name), 1);
            tf = ~isempty(k) && isequal(obj.Axes(k), a);
        end

        function L = loadsTotalAt(obj, fl, ax)
            parts = cellfun(@(c) c.loads(fl), obj.Components, 'UniformOutput', false);
            parts{end+1} = obj.MassProps.weightLoads(fl.C_bn, fl.Env.g);
            L = vital.Loads.aggregate(parts, ax);
        end
    end

    methods (Static, Hidden)
        function [F_R, M_R, oe, infos, M_own] = compiledLoads(c, fl)
            % component loads moved to the root: F_R = C F, M_R = C M + r x (C F)
            % (CONVENTIONS 6); M_own = C M (about each component's own origin)
            n = numel(c.comps);
            F_R = zeros(3, n); M_R = zeros(3, n); M_own = zeros(3, n); oe = false;
            infos = cell(1, n);
            for k = 1:n
                if c.enabled(k)
                    [F, M, info] = c.comps{k}.computeLoads(fl);
                else
                    F = zeros(3, 1); M = zeros(3, 1); info = struct('outOfEnvelope', false);
                end
                if ~c.identity(k)
                    C = c.C(:, :, k);
                    F = C * F; M = C * M;
                end
                F_R(:, k) = F;
                M_own(:, k) = M;
                r = c.r(:, k);                  % M + r x F, the arithmetic of cross() written out
                M_R(:, k) = M + [r(2) * F(3) - r(3) * F(2); r(3) * F(1) - r(1) * F(3); r(1) * F(2) - r(2) * F(1)];
                oe = oe || info.outOfEnvelope;
                infos{k} = info;
            end
        end

        function [F_R, M_R, info] = runtimeLoads(c, fl)
            % the loads of a compiled model in a context built by a plant with its own
            % kinematics (vital.plant.derivativesRotating, ADR-043), in the info
            % layout of an AC.loadsFcn: outOfEnvelope and the kind sums
            [F_R, M_R, oe, infos, M_own] = vital.AircraftModel.compiledLoads(c, fl);
            [info.F_aero, info.M_aero, info.F_prop, info.M_prop, info.M_aero_R, cf, th] = ...
                vital.AircraftModel.kindSums(c, F_R, M_R, M_own, infos);
            if ~isempty(cf), info.coeff = cf; end
            if ~isempty(th), info.thrust_lbf = th; end
            info.outOfEnvelope = oe;
            % F-6: the aero moment about the first aero point AC.r_mrc is M_aero +
            % M_aero_transfer, exact for aero components at several points (zero
            % for one point); derivativesRotating adds (r_mrc - r_cg) x F_aero
            ia = c.iAero;
            info.M_aero_transfer = zeros(3, 1);
            for k = ia(2:end)
                info.M_aero_transfer = info.M_aero_transfer + cross(c.r(:, k) - c.r_mrc, F_R(:, k));
            end
        end

        function [F_R, M_R, info] = runtimeLoadsFcn(ad, u, h, atm, AC) %#ok<STOUT,INUSD>
            % the loadsFcn of a toRuntime struct: never evaluated on its own
            error('vital:model:runtimeLoadsFcn', ['the loadsFcn of a toRuntime struct cannot be called on its own ' ...
                '(a component context needs the state): pass the struct, or the model itself, to ' ...
                'vital.plant.derivatives or vital.plant.derivativesRotating (ADR-043).']);
        end

        function checkRuntime(AC)
            %CHECKRUNTIME  vital:model:staleRuntime unless the physical fields of a
            %   toRuntime struct still equal the model it carries (ADR-043): one
            %   stored numeric fingerprint (S b cbar mass J r_cg r_mrc), the control
            %   names, the loadsFcn and aeroScale (present iff the model has one).
            m = AC.runtimeModel;
            ok = isa(m, 'vital.AircraftModel') && ~isempty(m.Compiled);
            if ok
                c = m.Compiled;
                try
                    ok = isequal([AC.S(:); AC.b(:); AC.cbar(:); AC.mass(:); AC.J(:); AC.r_cg(:); AC.r_mrc(:)], c.fingerprint) && ...
                        isequal(AC.controlNames, c.controls) && isequal(AC.loadsFcn, @vital.AircraftModel.runtimeLoadsFcn) && ...
                        isfield(AC, 'aeroScale') == c.hasAeroScale;
                    if ok && c.hasAeroScale, ok = isequal(AC.aeroScale, c.aeroScale); end
                catch
                    ok = false;
                end
            end
            if ~ok
                error('vital:model:staleRuntime', ['this AC struct was made by AircraftModel.toRuntime() and one of its ' ...
                    'physical fields (S, b, cbar, mass, J, r_cg, r_mrc, aeroScale, controlNames, loadsFcn) was edited ' ...
                    'afterwards; the plant evaluates the model, so the edit would be ignored. Change the model (or its ' ...
                    'data) and call toRuntime() again (ADR-043).']);
            end
        end

        function [F_aero, M_aero, F_prop, M_prop, M_aero_R, coeff, thrust] = kindSums(c, F_R, M_R, M_own, infos)
            % y.F_aero, M_aero, F_prop, M_prop, coeff, thrust_lbf by component Kind
            % (ADR-043, findings F-7/F-8): forces in the root (body) axes, moments
            % each about its own component origin (the MRC for the F-16), as
            % vital.aircraft.f16.loads; M_aero_R the aero moment about the root.
            % NaN when any component is 'unclassified' (never a silent 0). coeff
            % (one aero component) and thrust (every propulsor reports thrust_lbf)
            % are [] when not defined. Plain outputs, no struct (cost).
            coeff = []; thrust = [];
            if c.unclassified
                F_aero = nan(3, 1); M_aero = F_aero; F_prop = F_aero; M_prop = F_aero; M_aero_R = F_aero;
                return
            end
            ia = c.iAero; ip = c.iProp;
            F_aero = sum(F_R(:, ia), 2); M_aero = sum(M_own(:, ia), 2);
            if isscalar(ip)                     % one column: the same numbers as sum(., 2), cheaper
                F_prop = F_R(:, ip); M_prop = M_own(:, ip);
                if isfield(infos{ip}, 'thrust_lbf'), thrust = infos{ip}.thrust_lbf; end
            else
                F_prop = sum(F_R(:, ip), 2); M_prop = sum(M_own(:, ip), 2);
                if ~isempty(ip)
                    thrust = 0;
                    for k = ip
                        if ~isfield(infos{k}, 'thrust_lbf'), thrust = []; break; end
                        thrust = thrust + infos{k}.thrust_lbf;
                    end
                end
            end
            if isscalar(ia)
                if isfield(infos{ia}, 'coeff'), coeff = infos{ia}.coeff; end
                M_aero_R = M_R(:, ia);
            else
                M_aero_R = sum(M_R(:, ia), 2);
            end
        end

        function y = diagnostics(fl, F_R, M_R, F_b, M_cg, oe, mass, env, names, F_aero, M_aero, F_prop, M_prop, M_aero_R, coeff, thrust)
            % the y of vital.plant.derivatives (same formulas and fields, incl. the
            % kind sums of kindSums), plus the component loads F_R, M_R, componentNames and
            % M_aero_R. Built by ONE struct() call (ADR-043 cost note: about 3x
            % cheaper than ~30 single field assignments).
            ad = fl.Air; x = fl.X;
            e = vital.frames.dcm2eul(fl.C_bn);
            sf = sum(F_R, 2) / mass;
            if env.g > 0, nz = -sf(3) / env.g; else, nz = NaN; end
            y = struct('V', ad.V, 'alpha', ad.alpha, 'beta', ad.beta, 'mach', ad.mach, 'qbar', ad.qbar, 'h', fl.H, ...
                'F_b', F_b, 'M_cg', M_cg, 'outOfEnvelope', oe, ...
                'F_aero', F_aero, 'M_aero', M_aero, 'F_prop', F_prop, 'M_prop', M_prop, ...
                'quatNorm', norm(x(7:10)), 'phi', e(1), 'theta', e(2), 'psi', e(3), 'p', x(4), 'q', x(5), 'r', x(6), ...
                'specificForce_b', sf, 'nz', nz, 'F_R', F_R, 'M_R', M_R, 'componentNames', {names}, 'M_aero_R', M_aero_R);
            if ~isempty(coeff), y.coeff = coeff; end
            if ~isempty(thrust), y.thrust_lbf = thrust; end
        end
    end
end

function [C, r] = chainPose(ax, root)
% C_root_ax and the origin of ax in root coordinates, from the axis chain itself
[C, r] = ax.poseIn(root);
end
