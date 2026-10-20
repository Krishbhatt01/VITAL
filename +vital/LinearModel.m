classdef LinearModel
%LINEARMODEL  A vital.linear.linearize result as an object (0.8.1-OOP, ADR-037).
%   lin = vital.LinearModel(l)    l: the vital.linear.linearize struct
%   Properties: A (12x12), B (12x4), StateNames, InputNames, Status.
%   lin.toStruct()      the struct unchanged
%   lin.eig()           eigenvalues of the 8 dynamic states A(1:8, 1:8)
%   m = lin.modes(...)  vital.linear.modes(l, ...) as a cell array of
%                       vital.modes.Mode objects (vital.modes.Mode.fromStruct)
%   Errors: vital:badInput (l is not a linearize struct).
    properties (SetAccess = private)
        A double
        B double
        StateNames cell
        InputNames cell
        Status (1,:) char
    end
    properties (Access = private)
        Raw struct
    end
    methods
        function obj = LinearModel(l)
            arguments
                l (1,1) struct
            end
            if ~all(isfield(l, {'A', 'B', 'status', 'stateNames', 'inputNames'}))
                error('vital:badInput', 'a LinearModel needs a vital.linear.linearize struct.');
            end
            obj.Raw = l; obj.A = l.A; obj.B = l.B; obj.Status = l.status;
            obj.StateNames = l.stateNames; obj.InputNames = l.inputNames;
        end
        function l = toStruct(obj)
            l = obj.Raw;
        end
        function e = eig(obj)
            e = eig(obj.A(1:8, 1:8));
        end
        function m = modes(obj, varargin)
            s = vital.linear.modes(obj.Raw, varargin{:});
            m = cell(1, numel(s));
            for k = 1:numel(s), m{k} = vital.modes.Mode.fromStruct(s(k)); end
        end
    end
end
