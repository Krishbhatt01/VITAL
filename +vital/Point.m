classdef Point
%POINT  A position (3xN, m) given in an axis (value class).
%   p = vital.Point(r, axis)            r 3xN, metres
%   p = vital.Point(r, axis, 'Units', "ft")
%   q = p.expressIn(b)    the same physical point(s) in axis b: ROTATES AND TRANSLATES,
%                         r_b = o_ab + C_ba r_a  (o_ab = origin of a in b)
%   v = p1 - p2           a vital.Vector of quantity "position" (same axis only,
%                         else vital:axis:mismatch)
%   Compare vital.Vector (a free vector: changing axis only rotates) and
%   vital.Loads (force + moment about a point). See docs/PLAN_CORE_FRAMES.md 2.1.

    properties (SetAccess = immutable)
        R (3,:) double = zeros(3, 1)     % coordinates in Axis (m)
        Axis                              % vital.Axis
    end

    methods
        function obj = Point(r, axis, opts)
            arguments
                r
                axis
                opts.Units = strings(0)
            end
            obj.R = vital.Vector.checkData(r, 'Point');
            if ~isa(axis, 'vital.Axis') || ~isscalar(axis)
                error('vital:badInput', 'Point axis must be a single vital.Axis.');
            end
            if ~isempty(opts.Units)
                if ~strcmpi(string(opts.Units), "ft") && ~strcmpi(string(opts.Units), "m")
                    error('vital:badInput', 'Point Units must be "m" or "ft".');
                end
                if strcmpi(string(opts.Units), "ft"), obj.R = obj.R * vital.units.constants().ft; end
            end
            obj.Axis = axis;
        end

        function p = expressIn(obj, b)
            [C, o] = obj.Axis.poseIn(b);
            p = vital.Point(o + C * obj.R, b);
        end

        function v = minus(a, b)
            if ~isa(a, 'vital.Point') || ~isa(b, 'vital.Point')
                error('vital:badInput', 'Point minus needs two Points.');
            end
            if ~a.Axis.isSame(b.Axis)
                error('vital:axis:mismatch', 'Points in axes ''%s'' and ''%s'': express one in the other''s axis first.', ...
                    a.Axis.Name, b.Axis.Name);
            end
            v = vital.Vector(a.R - b.R, a.Axis, 'Quantity', "position");
        end

        function s = toStruct(obj)
            s = struct('axis', obj.Axis.Name, 'r_m', obj.R);
        end

        function disp(obj)
            for k = 1:numel(obj)
                fprintf('  Point in ''%s'' (m):\n', obj(k).Axis.Name);
                fprintf('    [%10.4f %10.4f %10.4f]\n', obj(k).R);
            end
        end
    end
end
