classdef Loads
%LOADS  A force and a moment about the origin of a reference axis (a "wrench";
%   value class). The user-facing name of VITAL's load object.
%   L = vital.Loads(F, M)              F, M vital.Vectors in the SAME axis
%                                      (quantities force/generic and moment/generic)
%   L = vital.Loads(Fnum, Mnum, axis)  numeric 3xN force (N) and moment (N m)
%   L.Force, L.Moment   the Vectors;  L.F, L.M  their numeric values (3xN)
%   L.RefAxis           the moment is about RefAxis' origin, in RefAxis' components
%   L2 = L.transform(b)  move to b (CONVENTIONS 6, = vital.loads.transferLoad):
%                        F_b = C_ba F,  M_b = C_ba (M - r_b x F),  r_b = origin of b in a
%   L = vital.Loads.aggregate(list, b)  transfer each load EXPLICITLY to b and sum
%   L1 + L2              only with the same reference axis (else vital:loads:refMismatch);
%                        never a silent transfer
%   vital.Loads.zero(axis)
%   Batches: 3xN data (time histories), one axis for all columns.
%   (The class file Loads.m sits next to the +loads package of the functional core;
%   MATLAB resolves vital.Loads and vital.loads.* separately: verified in
%   reports/work/core/red_console.txt.)

    properties (SetAccess = immutable)
        Force       % vital.Vector, quantity force
        Moment      % vital.Vector, quantity moment, about RefAxis' origin
        RefAxis     % vital.Axis
    end

    properties (Dependent)
        F
        M
    end

    methods
        function obj = Loads(F, M, axis)
            if nargin == 2 && isa(F, 'vital.Vector') && isa(M, 'vital.Vector')
                if ~F.Axis.isSame(M.Axis)
                    error('vital:axis:mismatch', 'Loads force (axis ''%s'') and moment (axis ''%s'') must share an axis.', ...
                        F.Axis.Name, M.Axis.Name);
                end
                if ~any(F.Quantity == ["force" "generic"]) || ~any(M.Quantity == ["moment" "generic"])
                    error('vital:badInput', 'Loads(F, M) needs a force and a moment, got a %s and a %s.', F.Quantity, M.Quantity);
                end
                axis = F.Axis; Fv = F.V; Mv = M.V;
            elseif nargin == 3
                if ~isa(axis, 'vital.Axis') || ~isscalar(axis)
                    error('vital:badInput', 'Loads axis must be a single vital.Axis.');
                end
                Fv = vital.Vector.checkData(F, 'force'); Mv = vital.Vector.checkData(M, 'moment');
            else
                error('vital:badInput', 'use vital.Loads(F, M) with Vectors or vital.Loads(Fnum, Mnum, axis).');
            end
            if size(Fv, 2) ~= size(Mv, 2)
                error('vital:badInput', 'force and moment must have the same number of columns.');
            end
            obj.Force = vital.Vector(Fv, axis, 'Quantity', "force");
            obj.Moment = vital.Vector(Mv, axis, 'Quantity', "moment");
            obj.RefAxis = axis;
        end

        function v = get.F(obj)
            v = obj.Force.V;
        end

        function v = get.M(obj)
            v = obj.Moment.V;
        end

        function L = transform(obj, b)
            %TRANSFORM  The same load about b's origin, in b's components.
            [C, r] = b.poseIn(obj.RefAxis);          % C_ab, origin of b in a
            C = C.';                                  % C_ba
            F = obj.F;
            n = size(F, 2);
            L = vital.Loads(C * F, C * (obj.M - cross(repmat(r, 1, n), F, 1)), b);
        end

        function c = plus(a, b)
            if ~isa(a, 'vital.Loads') || ~isa(b, 'vital.Loads')
                error('vital:badInput', 'can only add two Loads.');
            end
            if ~a.RefAxis.isSame(b.RefAxis)
                error('vital:loads:refMismatch', ['Loads about ''%s'' and ''%s'': a moment depends on its point; ' ...
                    'use transform or vital.Loads.aggregate.'], a.RefAxis.Name, b.RefAxis.Name);
            end
            c = vital.Loads(a.F + b.F, a.M + b.M, a.RefAxis);
        end

        function s = toStruct(obj)
            s = struct('axis', obj.RefAxis.Name, 'F_N', obj.F, 'M_Nm', obj.M);
        end

        function disp(obj)
            for k = 1:numel(obj)
                L = obj(k);
                fprintf('  Loads about ''%s'' (components in ''%s''):\n', L.RefAxis.Name, L.RefAxis.Name);
                fprintf('    F = [%12.2f %12.2f %12.2f] N\n', L.F);
                fprintf('    M = [%12.2f %12.2f %12.2f] N m\n', L.M);
            end
        end
    end

    methods (Static)
        function L = aggregate(list, b)
            %AGGREGATE  Transfer each load explicitly to b and sum.
            if iscell(list), items = list; else, items = num2cell(list); end
            if isempty(items)
                L = vital.Loads.zero(b);
                return
            end
            L = items{1}.transform(b);
            for k = 2:numel(items)
                L = L + items{k}.transform(b);
            end
        end

        function L = zero(axis, n)
            arguments
                axis
                n (1,1) double = 1
            end
            L = vital.Loads(zeros(3, n), zeros(3, n), axis);
        end
    end
end
