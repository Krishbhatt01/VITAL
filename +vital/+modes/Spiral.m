classdef Spiral < vital.modes.Mode
%SPIRAL  Spiral mode (MIL-F-8785C 3.3.1.3; TDouble is the time to double amplitude).
%   See vital.modes.Mode (0.8.1-OOP, ADR-037).
    methods
        function obj = Spiral(s)
            obj@vital.modes.Mode(s);
        end
    end
end
