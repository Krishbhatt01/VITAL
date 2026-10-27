classdef InertiaTensor
%INERTIATENSOR  An inertia tensor about the CG, with components in an axis (value class).
%   T = vital.InertiaTensor(J, axis)   J 3x3 tensor (kg m^2), symmetric, physical
%   T = vital.InertiaTensor.fromProducts(Ixx, Iyy, Izz, Ixy, Ixz, Iyz, axis)
%       products as positive integrals (Ixz = int x z dm), so J13 = -Ixz
%       (CONVENTIONS 6; vital.mass.inertiaTensor)
%   T2 = T.expressIn(b)  ROTATION ONLY: J_b = C_ba J C_ba'. The point stays the CG.
%   The axis gives the ORIENTATION of the components only. The reference point is
%   always the CG of the owning vital.MassProperties; moving the point (parallel
%   axis theorem) is MassProperties.about, which is valid only from the CG.
%   Errors: vital:badInput (not 3x3, not finite, not symmetric),
%   vital:mass:nonPhysicalInertia (principal moments < 0 or triangle inequality
%   violated, as vital.mass.inertiaTensor; FC-105).

    properties (SetAccess = immutable)
        J (3,3) double = zeros(3)
        Axis
    end

    methods
        function obj = InertiaTensor(J, axis)
            if ~(isnumeric(J) && isreal(J) && isequal(size(J), [3 3]))
                error('vital:badInput', 'inertia tensor must be a real 3x3 matrix.');
            end
            vital.validate.finite(J, 'inertia tensor');
            if ~isa(axis, 'vital.Axis') || ~isscalar(axis)
                error('vital:badInput', 'InertiaTensor axis must be a single vital.Axis.');
            end
            J = double(J);
            if max(max(abs(J - J.'))) > 1e-12 * max(1, max(abs(J(:))))
                error('vital:badInput', 'inertia tensor must be symmetric.');
            end
            lam = sort(eig((J + J.') / 2));
            tol = 1e-12 * max(1, sum(abs(lam)));
            if lam(1) < -tol || lam(3) > lam(1) + lam(2) + tol
                error('vital:mass:nonPhysicalInertia', ...
                    'principal moments [%g %g %g] are not those of a real body.', lam(1), lam(2), lam(3));
            end
            obj.J = J;
            obj.Axis = axis;
        end

        function T = expressIn(obj, b)
            C = obj.Axis.dcmTo(b);
            Jb = C * obj.J * C.';
            T = vital.InertiaTensor((Jb + Jb.') / 2, b);
        end

        function s = toStruct(obj)
            s = struct('axis', obj.Axis.Name, 'J_kgm2', obj.J);
        end

        function disp(obj)
            for k = 1:numel(obj)
                fprintf('  InertiaTensor about the CG, components in ''%s'' (kg m^2):\n', obj(k).Axis.Name);
                fprintf('    [%12.2f %12.2f %12.2f]\n', obj(k).J.');
            end
        end
    end

    methods (Static)
        function T = fromProducts(Ixx, Iyy, Izz, Ixy, Ixz, Iyz, axis)
            T = vital.InertiaTensor(vital.mass.inertiaTensor(Ixx, Iyy, Izz, Ixy, Ixz, Iyz), axis);
        end
    end
end
