classdef DutchRoll < vital.modes.Mode
%DUTCHROLL  Lateral-directional Dutch-roll mode (MIL-F-8785C 3.3.1.1).
%   See vital.modes.Mode (0.8.1-OOP, ADR-037).
    methods
        function obj = DutchRoll(s)
            obj@vital.modes.Mode(s);
        end
    end
end
