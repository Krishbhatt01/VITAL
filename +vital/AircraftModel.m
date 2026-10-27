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
%   Bridge to the existing functional consumers (trim, linearize, sim, fq, uq):
%     AC = m.toRuntime()   the AC struct of vital.plant.derivatives with a loadsFcn
%                          that evaluates this model (needs 4 controls [de da dr
%                          throttle] for vital.plant.derivatives itself)
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
            c.isAero = cellfun(@(x) isa(x, 'vital.AeroTableComponent'), obj.Components);
            c.isProp = cellfun(@(x) isa(x, 'vital.PropulsorComponent'), obj.Components);
            mp = obj.MassProps;
            [~, rcg] = chainPose(mp.CgAxis, root);
            c.r_cg = rcg;
            c.mass = mp.Mass;
            c.J = mp.about(vital.Axis(rcg, eye(3), root, 'Name', 'cg_body'));
            c.ref = obj.Ref;
            c.controls = obj.Controls;
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
            [F_R, M_R, oe] = vital.AircraftModel.compiledLoads(c, fl);
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
                y = vital.AircraftModel.diagnostics(fl, F_R, M_R, F_b, M_cg, oe, c.mass, env, c.names);
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
                F_R = zeros(3, n); M_R = zeros(3, n); oe = false; names = cell(1, n);
                for k = 1:n
                    comp = obj.Components{k};
                    [~, ~, info] = comp.loadsNumeric(fl);
                    Lr = comp.loads(fl).transform(root);
                    F_R(:, k) = Lr.F; M_R(:, k) = Lr.M; oe = oe || info.outOfEnvelope; names{k} = comp.Name;
                end
                y = vital.AircraftModel.diagnostics(fl, F_R, M_R, L.F, L.M, oe, mp.Mass, env, names);
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
            ia = find(c.isAero, 1);
            if isempty(ia), AC.r_mrc = zeros(3, 1); else, AC.r_mrc = c.r(:, ia); end
            AC.limits = obj.Limits;
            AC.controlNames = obj.Controls;
            AC.loadsFcn = @(ad, u, h, atm, AC_) vital.AircraftModel.runtimeLoads(c, ad, u, h, atm); %#ok<INUSD>
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
                M_R(:, k) = M + cross(c.r(:, k), F);
                oe = oe || info.outOfEnvelope;
                infos{k} = info;
            end
        end

        function [F_R, M_R, info] = runtimeLoads(c, ad, u, h, atm)
            fl = vital.FlightContext.fromAirData(ad, u, h, atm, c.controls);
            [F_R, M_R, oe, infos, M_own] = vital.AircraftModel.compiledLoads(c, fl);
            info.outOfEnvelope = oe;
            ia = find(c.isAero); ip = find(c.isProp);
            % as vital.aircraft.f16.loads: aero and propulsive loads in body axes, each
            % about its own component origin (the MRC for the F-16)
            info.F_aero = sum(F_R(:, ia), 2); info.M_aero = sum(M_own(:, ia), 2);
            info.F_prop = sum(F_R(:, ip), 2); info.M_prop = sum(M_own(:, ip), 2);
            if ~isempty(ia) && isfield(infos{ia(1)}, 'coeff'), info.coeff = infos{ia(1)}.coeff; end
            if ~isempty(ip) && all(cellfun(@(s) isfield(s, 'thrust_lbf'), infos(ip)))
                info.thrust_lbf = sum(cellfun(@(s) s.thrust_lbf, infos(ip)));
            end
        end

        function y = diagnostics(fl, F_R, M_R, F_b, M_cg, oe, mass, env, names)
            % the y of vital.plant.derivatives (same formulas), plus the component loads
            ad = fl.Air; x = fl.X;
            y.V = ad.V; y.alpha = ad.alpha; y.beta = ad.beta; y.mach = ad.mach; y.qbar = ad.qbar; y.h = fl.H;
            y.F_b = F_b; y.M_cg = M_cg;
            y.outOfEnvelope = oe;
            y.F_R = F_R; y.M_R = M_R; y.componentNames = names;
            y.quatNorm = norm(x(7:10));
            e = vital.frames.dcm2eul(fl.C_bn);
            y.phi = e(1); y.theta = e(2); y.psi = e(3);
            y.p = x(4); y.q = x(5); y.r = x(6);
            y.specificForce_b = sum(F_R, 2) / mass;
            if env.g > 0
                y.nz = -y.specificForce_b(3) / env.g;
            else
                y.nz = NaN;
            end
        end
    end
end

function [C, r] = chainPose(ax, root)
% C_root_ax and the origin of ax in root coordinates, from the axis chain itself
[C, r] = ax.poseIn(root);
end
