classdef Vector
%VECTOR  A free vector (3xN) given in an axis: force, moment, velocity, rate,
%   position (a difference of points) or generic (value class).
%   v = vital.Vector(V, axis)                       quantity "generic"
%   v = vital.Vector(V, axis, 'Quantity', "force")
%   w = v.expressIn(b)    ROTATES ONLY: v_b = C_ba v_a (a free vector has no point)
%   v1 + v2, v1 - v2      same axis (else vital:axis:mismatch) and same quantity
%                         (else vital:vector:quantityMismatch)
%   -v, k * v             scalar multiples
%   cross(a, b)           same axis; position x force -> moment, rate x position ->
%                         velocity, otherwise generic
%   dot(a, b), v.norm()   numeric, 1xN
%   A force's point of application is NOT part of a Vector: it is the origin of the
%   reference axis of a vital.Loads. See docs/PLAN_CORE_FRAMES.md 2.1.

    properties (Constant, Hidden)
        QUANTITIES = ["force" "moment" "velocity" "rate" "position" "generic"]
    end

    properties (SetAccess = immutable)
        V (3,:) double = zeros(3, 1)
        Axis
        Quantity (1,1) string = "generic"
    end

    methods
        function obj = Vector(V, axis, opts)
            arguments
                V
                axis
                opts.Quantity = "generic"
            end
            obj.V = vital.Vector.checkData(V, 'Vector');
            if ~isa(axis, 'vital.Axis') || ~isscalar(axis)
                error('vital:badInput', 'Vector axis must be a single vital.Axis.');
            end
            q = string(opts.Quantity);
            if ~isscalar(q) || ~any(q == vital.Vector.QUANTITIES)
                error('vital:badInput', 'unknown quantity "%s" (allowed: %s).', strjoin(string(opts.Quantity)), ...
                    strjoin(vital.Vector.QUANTITIES, ', '));
            end
            obj.Axis = axis;
            obj.Quantity = q;
        end

        function w = expressIn(obj, b)
            w = vital.Vector(obj.Axis.dcmTo(b) * obj.V, b, 'Quantity', obj.Quantity);
        end

        function c = plus(a, b)
            vital.Vector.checkSame(a, b, 'add');
            c = vital.Vector(a.V + b.V, a.Axis, 'Quantity', a.Quantity);
        end

        function c = minus(a, b)
            vital.Vector.checkSame(a, b, 'subtract');
            c = vital.Vector(a.V - b.V, a.Axis, 'Quantity', a.Quantity);
        end

        function c = uminus(a)
            c = vital.Vector(-a.V, a.Axis, 'Quantity', a.Quantity);
        end

        function c = mtimes(a, b)
            if isnumeric(a) && isscalar(a) && isa(b, 'vital.Vector')
                c = vital.Vector(a * b.V, b.Axis, 'Quantity', b.Quantity);
            elseif isnumeric(b) && isscalar(b) && isa(a, 'vital.Vector')
                c = vital.Vector(b * a.V, a.Axis, 'Quantity', a.Quantity);
            else
                error('vital:badInput', 'a Vector can only be scaled by a numeric scalar.');
            end
        end

        function c = times(a, b)
            c = mtimes(a, b);
        end

        function c = cross(a, b)
            if ~a.Axis.isSame(b.Axis)
                error('vital:axis:mismatch', 'cross of Vectors in axes ''%s'' and ''%s''.', a.Axis.Name, b.Axis.Name);
            end
            pair = sort([a.Quantity b.Quantity]);
            if isequal(pair, ["force" "position"]), q = "moment";
            elseif isequal(pair, ["position" "rate"]), q = "velocity";
            else, q = "generic";
            end
            c = vital.Vector(cross(a.V, b.V, 1), a.Axis, 'Quantity', q);
        end

        function d = dot(a, b)
            if ~a.Axis.isSame(b.Axis)
                error('vital:axis:mismatch', 'dot of Vectors in axes ''%s'' and ''%s''.', a.Axis.Name, b.Axis.Name);
            end
            d = sum(a.V .* b.V, 1);
        end

        function n = norm(obj)
            n = sqrt(sum(obj.V .^ 2, 1));
        end

        function s = toStruct(obj)
            s = struct('axis', obj.Axis.Name, 'quantity', char(obj.Quantity), 'v', obj.V);
        end

        function disp(obj)
            units = struct('force', 'N', 'moment', 'N m', 'velocity', 'm/s', 'rate', 'rad/s', 'position', 'm', 'generic', '-');
            for k = 1:numel(obj)
                fprintf('  %s in ''%s'' (%s):\n', obj(k).Quantity, obj(k).Axis.Name, units.(obj(k).Quantity));
                fprintf('    [%12.4f %12.4f %12.4f]\n', obj(k).V);
            end
        end
    end

    methods (Static, Hidden)
        function V = checkData(V, what)
            if ~(isnumeric(V) && isreal(V)) || ~(size(V, 1) == 3 || isequal(size(V), [1 3]))
                error('vital:badInput', '%s data must be real 3xN (or a 1x3 row), got %s.', what, mat2str(size(V)));
            end
            vital.validate.finite(V, what);
            if isequal(size(V), [1 3]), V = V.'; end
            V = double(V);
        end
    end

    methods (Static, Access = private)
        function checkSame(a, b, what)
            if ~isa(a, 'vital.Vector') || ~isa(b, 'vital.Vector')
                error('vital:badInput', 'can only %s two Vectors.', what);
            end
            if ~a.Axis.isSame(b.Axis)
                error('vital:axis:mismatch', 'cannot %s Vectors in axes ''%s'' and ''%s'': express one in the other''s axis first.', ...
                    what, a.Axis.Name, b.Axis.Name);
            end
            if a.Quantity ~= b.Quantity
                error('vital:vector:quantityMismatch', 'cannot %s a %s and a %s.', what, a.Quantity, b.Quantity);
            end
        end
    end
end
