classdef CombinedLaw < vital.ctrl.ControlLaw
%COMBINEDLAW  vital.ctrl.combine of several laws as an object (0.8.1-OOP, ADR-037).
%   law = vital.ctrl.CombinedLaw(law1, law2, ...)   each a vital.ctrl.ControlLaw
%   u = u_ref + sum_i (u_i - u_ref); see vital.ctrl.combine.
%   Errors: vital:badInput (no member, a member that is not a ControlLaw).
    properties (SetAccess = private)
        Members cell
    end
    methods
        function obj = CombinedLaw(varargin)
            if nargin == 0 || ~all(cellfun(@(m) isa(m, 'vital.ctrl.ControlLaw'), varargin))
                error('vital:badInput', 'CombinedLaw needs one or more vital.ctrl.ControlLaw members.');
            end
            obj.Name = 'combine'; obj.Members = varargin;
        end
        function c = buildStruct(obj, AC, env, tr)
            cs = cellfun(@(m) m.buildStruct(AC, env, tr), obj.Members, 'UniformOutput', false);
            c = vital.ctrl.combine(cs{:});
        end
    end
end
