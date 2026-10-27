classdef MassProperties
%MASSPROPERTIES  Mass, CG and inertia about the CG (value class).
%   mp = vital.MassProperties(m, axis_cg, inertia)
%     m        mass (kg, >= 0; negative: vital:mass:negativeMass)
%     axis_cg  a vital.Axis whose ORIGIN is the CG
%     inertia  a vital.InertiaTensor (about the CG), or a 3x3 tensor in axis_cg
%   J = mp.about(b)        tensor about b's ORIGIN in b's components (kg m^2):
%                          C J_cg C' + m (d'd I - d d'),  d = CG position in b
%                          (parallel axis theorem, valid only FROM the CG)
%   mp2 = mp.expressIn(b)  the same mass properties with the tensor's components in
%                          b's orientation (still about the CG)
%   mp = vital.MassProperties.combine(list, ref)
%                          total mass, composite CG (an axis 'cg' parallel to ref)
%                          and the inertia about the COMPOSITE CG by the parallel
%                          axis theorem (as vital.mass.massProps); ref defaults to
%                          the root of the first item
%   W = mp.weightLoads(C_bn, g)   the weight, m C_bn [0 0 g] (or m C_bn g_n for a
%                          3-vector g), acting AT THE CG: zero moment about axis_cg.
%                          This is the only load that comes from mass properties.
%                          C_bn maps NED to BODY axes; the tree root (the BFRP) is
%                          body-parallel by definition (CONVENTIONS 2).
%   D = mp.dAlembertLoads(a, w, wdot)   (-m a, -(J wdot + w x J w)) about the CG, in
%                          axis_cg components. FOR STATIC-BALANCE CHECKS ONLY: the
%                          equations of motion already contain these terms, so they
%                          are NEVER part of a load total (CONVENTIONS 6;
%                          tests/M9/core/tCoreModel.m#dAlembertNeverInTotal).

    properties (SetAccess = immutable)
        Mass (1,1) double = 0
        CgAxis
        Inertia
    end

    methods
        function obj = MassProperties(m, cgAxis, inertia)
            vital.validate.finite(m, 'mass');
            if ~isscalar(m)
                error('vital:badInput', 'mass must be a scalar.');
            end
            if m < 0
                error('vital:mass:negativeMass', 'mass %g is negative.', m);
            end
            if ~isa(cgAxis, 'vital.Axis') || ~isscalar(cgAxis)
                error('vital:badInput', 'MassProperties CG axis must be a single vital.Axis.');
            end
            if ~isa(inertia, 'vital.InertiaTensor')
                inertia = vital.InertiaTensor(inertia, cgAxis);
            end
            obj.Mass = double(m);
            obj.CgAxis = cgAxis;
            obj.Inertia = inertia;
        end

        function J = about(obj, b)
            C = obj.Inertia.Axis.dcmTo(b);
            d = obj.CgAxis.originIn(b);
            J = C * obj.Inertia.J * C.' + obj.Mass * ((d.' * d) * eye(3) - d * d.');
        end

        function mp = expressIn(obj, b)
            mp = vital.MassProperties(obj.Mass, obj.CgAxis, obj.Inertia.expressIn(b));
        end

        function W = weightLoads(obj, C_bn, g)
            vital.validate.finite(C_bn, 'DCM');
            vital.validate.finite(g, 'gravity');
            if isscalar(g), g_n = [0; 0; g]; else, g_n = g(:); end
            Fb = obj.Mass * (C_bn * g_n);                 % body (= BFRP) components
            root = obj.CgAxis.rootAxis();
            W = vital.Loads(root.dcmTo(obj.CgAxis) * Fb, zeros(3, 1), obj.CgAxis);
        end

        function D = dAlembertLoads(obj, a, w, wdot)
            vital.validate.finite([a(:); w(:); wdot(:)], 'accelerations and rates');
            C = obj.Inertia.Axis.dcmTo(obj.CgAxis);
            J = C * obj.Inertia.J * C.';
            D = vital.Loads(-obj.Mass * a(:), -(J * wdot(:) + cross(w(:), J * w(:))), obj.CgAxis);
        end

        function s = toStruct(obj)
            s = struct('mass_kg', obj.Mass, 'cgAxis', obj.CgAxis.Name, ...
                'cg_in_root_m', obj.CgAxis.originIn(obj.CgAxis.rootAxis()), 'J_cg_kgm2', obj.Inertia.J, ...
                'inertiaAxis', obj.Inertia.Axis.Name);
        end

        function disp(obj)
            for k = 1:numel(obj)
                mp = obj(k);
                r = mp.CgAxis.originIn(mp.CgAxis.rootAxis());
                fprintf('  MassProperties: m = %.3f kg, CG ''%s'' at [%.4f %.4f %.4f] m in ''%s''\n', ...
                    mp.Mass, mp.CgAxis.Name, r, mp.CgAxis.rootAxis().Name);
                fprintf('    J about the CG, components in ''%s'' (kg m^2):\n', mp.Inertia.Axis.Name);
                fprintf('    [%12.2f %12.2f %12.2f]\n', mp.Inertia.J.');
            end
        end
    end

    methods (Static)
        function mp = combine(list, ref)
            %COMBINE  Composite mass properties (parallel axis through the composite CG).
            if isempty(list)
                error('vital:mass:negativeMass', 'no mass items: total mass must be positive.');
            end
            if iscell(list), list = [list{:}]; end
            if nargin < 2, ref = list(1).CgAxis.rootAxis(); end
            n = numel(list);
            masses = [list.Mass];
            m = sum(masses);
            if m <= 0
                error('vital:mass:negativeMass', 'total mass %g must be positive.', m);
            end
            r = zeros(3, n);
            for k = 1:n
                r(:, k) = list(k).CgAxis.originIn(ref);
            end
            rcg = r * masses(:) / m;
            J = zeros(3);
            for k = 1:n
                C = list(k).Inertia.Axis.dcmTo(ref);
                d = r(:, k) - rcg;
                J = J + C * list(k).Inertia.J * C.' + masses(k) * ((d.' * d) * eye(3) - d * d.');
            end
            J = (J + J.') / 2;
            cg = vital.Axis(rcg, eye(3), ref, 'Name', 'cg');
            mp = vital.MassProperties(m, cg, vital.InertiaTensor(J, cg));
        end
    end
end
