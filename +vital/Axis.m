classdef Axis
%AXIS  A right-handed axis system placed relative to a parent axis (value class).
%   a = vital.Axis(t, orient, parent, 'Name', name)
%   a = vital.Axis(t, orient, parent, 'Name', name, 'Units', ["ft" "deg"])
%     t       translation: the origin of a in the PARENT's coordinates (3-vector, m;
%             'Units' "ft" converts it once by 0.3048)
%     orient  the orientation of a relative to the parent, one of
%               3x3 DCM C_a_parent (passive: v_a = C v_parent), orthonormal, det +1
%               [phi theta psi] 3-2-1 Euler angles, rad ('Units' "deg" allowed),
%                 C = R1(phi) R2(theta) R3(psi) (vital.frames.dcm321, angle2dcm ZYX)
%               a scalar MATLAB quaternion with VITAL's meaning (parent -> a):
%                 C = rotmat(q, 'frame')
%               an so3 object (ACTIVE rotation, the toolbox convention): C = rotm(R)'
%             anything else is vital:badInput
%     parent  a vital.Axis, or [] for a root
%   a = vital.Axis.root(name)                        the root of a tree (BFRP, NED, ...)
%
%   ONE CONVENTION (CONVENTIONS 3): a.C maps parent components to a's components.
%   Value class: an Axis never changes after construction; a tree is built from the
%   root outwards and every axis holds its whole chain (Parent), so a cycle is
%   impossible by construction.
%
%   Queries (both axes must share a root, else vital:axis:noCommonRoot):
%     C = a.dcmTo(b)        C_ba: maps a components to b components
%     r = a.originIn(b)     origin of a in b coordinates (m)
%     [C, r] = a.poseIn(b)  both
%     k = a.chain()         [a, a.Parent, ..., root]
%     r = a.rootAxis()      the root
%     tf = a.isSame(b)      same name and same geometry all the way to the root
%   Factories (state-dependent axes are built per evaluation, never stored):
%     vital.Axis.station(stationOfParent, parent)  station frame (x aft, y right, z up):
%                         body rotated 180 deg about y, C = diag(-1, 1, -1) exactly;
%                         stationOfParent = station coordinates of the parent's
%                         origin (the datum of vital.frames.stationToBody)
%     vital.Axis.wind(alpha, beta, body)          C_wb (= dcmbody2wind)
%     vital.Axis.stability(alpha, body)           C_sb = R2(alpha)
%     vital.Axis.bodyInNed(x, ned)                body (at the CG) in NED from the state
%                         x (q = x(7:10) N->B, p_n = x(11:13))
%   Boundary conversions: a.toSe3() (pose in the parent: R = C', t = Origin),
%   a.toQuaternion() (rotmat(q, 'frame') = C), a.toStruct(), a.triad(ax).
%   Roots are identified by value (name and geometry): two roots built separately
%   with the same name are the same root.
%   See docs/PLAN_CORE_FRAMES.md and docs/DECISIONS.md ADR-040.

    properties (SetAccess = immutable)
        Name (1,:) char = 'axis'      % unique inside an aircraft model
        Origin (3,1) double = zeros(3, 1)   % origin in the parent's coordinates (m)
        C (3,3) double = eye(3)       % C_this_parent (passive)
        Parent = []                   % vital.Axis or [] (root)
    end

    methods
        function obj = Axis(t, orient, parent, opts)
            arguments
                t = zeros(3, 1)
                orient = eye(3)
                parent = []
                opts.Name = 'axis'
                opts.Units = strings(0)
            end
            [lenScale, angScale] = vital.Axis.parseUnits(opts.Units);
            if ~(ischar(opts.Name) || (isstring(opts.Name) && isscalar(opts.Name))) || strlength(opts.Name) == 0
                error('vital:badInput', 'Axis Name must be a non-empty text scalar.');
            end
            if ~(isnumeric(t) && isreal(t) && numel(t) == 3)
                error('vital:badInput', 'Axis translation must be a real 3-vector (m).');
            end
            vital.validate.finite(t, 'axis translation');
            if ~isempty(parent) && ~isa(parent, 'vital.Axis')
                error('vital:badInput', 'Axis parent must be a vital.Axis or [].');
            end
            if isa(parent, 'vital.Axis') && ~isscalar(parent)
                error('vital:badInput', 'Axis parent must be a single vital.Axis.');
            end
            obj.Name = char(opts.Name);
            obj.Origin = double(t(:)) * lenScale;
            obj.C = vital.Axis.parseOrientation(orient, angScale);
            if isempty(parent), obj.Parent = []; else, obj.Parent = parent; end
        end

        function C = dcmTo(obj, b)
            %DCMTO  C_ba: maps this axis' components to b's components.
            [Ca, ~, ra] = obj.toRoot();
            [Cb, ~, rb] = b.toRoot();
            vital.Axis.checkRoots(ra, rb, obj, b);
            C = Cb * Ca.';
        end

        function r = originIn(obj, b)
            %ORIGININ  This axis' origin in b's coordinates (m).
            [~, oa, ra] = obj.toRoot();
            [Cb, ob, rb] = b.toRoot();
            vital.Axis.checkRoots(ra, rb, obj, b);
            r = Cb * (oa - ob);
        end

        function [C, r] = poseIn(obj, b)
            %POSEIN  [C_ba, origin of this axis in b] in one walk.
            [Ca, oa, ra] = obj.toRoot();
            [Cb, ob, rb] = b.toRoot();
            vital.Axis.checkRoots(ra, rb, obj, b);
            C = Cb * Ca.';
            r = Cb * (oa - ob);
        end

        function [C, o, root] = toRoot(obj)
            %TOROOT  C_this_root, this origin in root coordinates, and the root axis.
            C = obj.C; o = obj.Origin; p = obj.Parent; root = obj;
            while ~isempty(p)
                o = p.Origin + p.C.' * o;
                C = C * p.C;
                root = p;
                p = p.Parent;
            end
        end

        function k = chain(obj)
            %CHAIN  [this, parent, ..., root].
            k = obj; p = obj.Parent;
            while ~isempty(p)
                k(end+1) = p; %#ok<AGROW>
                p = p.Parent;
            end
        end

        function r = rootAxis(obj)
            [~, ~, r] = obj.toRoot();
        end

        function tf = isSame(obj, b)
            tf = isa(b, 'vital.Axis') && isequal(obj, b);
        end

        function T = toSe3(obj)
            %TOSE3  This axis' pose in its parent: transform(T, p_this) = p_parent.
            T = se3(obj.C.', obj.Origin.');
        end

        function q = toQuaternion(obj)
            %TOQUATERNION  quaternion with rotmat(q, 'frame') = C (VITAL's meaning).
            q = quaternion(vital.frames.dcm2quat(obj.C).');
        end

        function s = toStruct(obj)
            s = struct('name', obj.Name, 'parent', '', 'origin_m', obj.Origin, 'C', obj.C, ...
                'euler321_deg', rad2deg(vital.frames.dcm2eul(obj.C)));
            if ~isempty(obj.Parent), s.parent = obj.Parent.Name; end
        end

        function disp(obj)
            if isempty(obj), fprintf('  0x0 vital.Axis\n'); return; end
            for k = 1:numel(obj)
                a = obj(k);
                if isempty(a.Parent), p = '(root)'; else, p = ['in ''' a.Parent.Name '''']; end
                e = rad2deg(vital.frames.dcm2eul(a.C)) + 0;     % + 0: print -0 as 0
                fprintf('  Axis ''%s'' %s: origin [%.4f %.4f %.4f] m, 3-2-1 Euler [%.2f %.2f %.2f] deg\n', ...
                    a.Name, p, a.Origin + 0, e);
            end
        end

        function h = triad(obj, ax, opts)
            %TRIAD  Draw this axis (x red, y green, z blue) in ROOT coordinates on a 3-D
            %   axes, through vital.viz.displayMap (the one plot mapping).
            arguments
                obj
                ax = []
                opts.Length (1,1) double = 1
            end
            if isempty(ax), ax = gca; end
            M = vital.viz.displayMap();
            [C, o] = obj.toRoot();
            cols = 'rgb';
            hold(ax, 'on');
            h = gobjects(1, 3);
            for i = 1:3
                tip = o + opts.Length * C(i, :).';
                P = M * [o tip];
                h(i) = plot3(ax, P(1, :), P(2, :), P(3, :), cols(i), 'LineWidth', 1.5);
            end
            Pt = M * o;
            text(ax, Pt(1), Pt(2), Pt(3), [' ' obj.Name]);
        end

        function h = plot(obj, varargin)
            h = obj.triad(varargin{:});
        end
    end

    methods (Static)
        function a = root(name)
            arguments
                name = 'root'
            end
            a = vital.Axis(zeros(3, 1), eye(3), [], 'Name', name);
        end

        function a = station(stationOfParent, parent, opts)
            arguments
                stationOfParent
                parent
                opts.Name = 'station'
                opts.Units = strings(0)
            end
            lenScale = vital.Axis.parseUnits(opts.Units);
            vital.validate.finite(stationOfParent, 'station datum');
            if numel(stationOfParent) ~= 3
                error('vital:badInput', 'station datum must be a 3-vector.');
            end
            T = diag([-1 1 -1]);
            a = vital.Axis(-T * (double(stationOfParent(:)) * lenScale), T, parent, 'Name', opts.Name);
        end

        function a = wind(alpha, beta, body, opts)
            arguments
                alpha
                beta
                body
                opts.Name = 'wind'
            end
            vital.validate.finite([alpha beta], 'alpha, beta');
            ca = cos(alpha); sa = sin(alpha); cb = cos(beta); sb = sin(beta);
            C = [ca*cb, sb, sa*cb; -ca*sb, cb, -sa*sb; -sa, 0, ca];
            a = vital.Axis(zeros(3, 1), C, body, 'Name', opts.Name);
        end

        function a = stability(alpha, body, opts)
            arguments
                alpha
                body
                opts.Name = 'stability'
            end
            vital.validate.finite(alpha, 'alpha');
            ca = cos(alpha); sa = sin(alpha);
            a = vital.Axis(zeros(3, 1), [ca 0 sa; 0 1 0; -sa 0 ca], body, 'Name', opts.Name);
        end

        function a = bodyInNed(x, ned, opts)
            arguments
                x
                ned
                opts.Name = 'body'
            end
            vital.validate.finite(x, 'state');
            if numel(x) ~= 13
                error('vital:badInput', 'state must have 13 elements, got %d.', numel(x));
            end
            x = x(:);
            a = vital.Axis(x(11:13), vital.frames.quat2dcm(x(7:10)), ned, 'Name', opts.Name);
        end
    end

    methods (Static, Access = private)
        function [lenScale, angScale] = parseUnits(units)
            lenScale = 1; angScale = 1;
            if isempty(units), return; end
            if ~(isstring(units) || ischar(units) || iscellstr(units))
                error('vital:badInput', 'Units must be text: "m", "ft", "rad" or "deg".');
            end
            for u = string(units(:)).'
                switch lower(u)
                    case "m"
                    case "ft", lenScale = vital.units.constants().ft;
                    case "rad"
                    case "deg", angScale = pi / 180;
                    otherwise
                        error('vital:badInput', 'unknown unit "%s" (allowed: m, ft, rad, deg).', u);
                end
            end
        end

        function C = parseOrientation(orient, angScale)
            if isa(orient, 'quaternion')
                if ~isscalar(orient)
                    error('vital:badInput', 'a quaternion orientation must be scalar.');
                end
                [w, x, y, z] = parts(orient);
                vital.validate.finite([w x y z], 'quaternion');
                if w == 0 && x == 0 && y == 0 && z == 0
                    error('vital:badInput', 'zero quaternion has no rotation.');
                end
                C = rotmat(normalize(orient), 'frame');
            elseif isa(orient, 'so3')
                if ~isscalar(orient)
                    error('vital:badInput', 'an so3 orientation must be scalar.');
                end
                C = rotm(orient).';           % so3 is active (toolbox convention)
            elseif isnumeric(orient) && isreal(orient) && isequal(size(orient), [3 3])
                vital.validate.finite(orient, 'DCM');
                C = double(orient);
                if max(max(abs(C * C.' - eye(3)))) > 1e-10 || det(C) <= 0
                    error('vital:badInput', 'DCM must be orthonormal with det +1 (right-handed).');
                end
            elseif isnumeric(orient) && isreal(orient) && isvector(orient) && numel(orient) == 3
                vital.validate.finite(orient, 'Euler angles');
                e = double(orient) * angScale;
                C = vital.frames.dcm321(e(1), e(2), e(3));
            else
                error('vital:badInput', ['orientation must be a 3x3 DCM, 3-2-1 Euler [phi theta psi], ' ...
                    'a scalar quaternion or an so3 object.']);
            end
        end

        function checkRoots(ra, rb, a, b)
            if ~isequal(ra, rb)
                error('vital:axis:noCommonRoot', 'axes ''%s'' (root ''%s'') and ''%s'' (root ''%s'') share no root.', ...
                    a.Name, ra.Name, b.Name, rb.Name);
            end
        end
    end
end
