classdef Phugoid < vital.modes.Mode
%PHUGOID  Longitudinal phugoid mode (MIL-F-8785C 3.2.1.2).
%   See vital.modes.Mode (0.8.1-OOP, ADR-037).
    methods
        function obj = Phugoid(s)
            obj@vital.modes.Mode(s);
        end
    end
end
