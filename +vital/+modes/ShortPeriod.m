classdef ShortPeriod < vital.modes.Mode
%SHORTPERIOD  Longitudinal short-period mode (MIL-F-8785C 3.2.2.1).
%   See vital.modes.Mode (0.8.1-OOP, ADR-037).
    methods
        function obj = ShortPeriod(s)
            obj@vital.modes.Mode(s);
        end
    end
end
