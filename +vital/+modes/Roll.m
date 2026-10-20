classdef Roll < vital.modes.Mode
%ROLL  Roll subsidence mode (MIL-F-8785C 3.3.1.2; Tau is the roll time constant).
%   See vital.modes.Mode (0.8.1-OOP, ADR-037).
    methods
        function obj = Roll(s)
            obj@vital.modes.Mode(s);
        end
    end
end
