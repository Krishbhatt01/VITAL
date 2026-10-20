classdef Mode
%MODE  One flight mode of a vital.linear.modes result (0.8.1-OOP, ADR-037).
%   m = vital.modes.Mode.fromStruct(s)  the subclass named by s.name:
%     short_period -> ShortPeriod, phugoid -> Phugoid, dutch_roll -> DutchRoll,
%     roll -> Roll, spiral -> Spiral; any other name (e.g. 'height', 'other',
%     a coupled roll-spiral) -> vital.modes.Mode itself.
%   Properties mirror the struct (eigenvalue, wn, zeta, period, tHalf, tDouble,
%   tau, status, reason); m.toStruct() returns it unchanged. The classification
%   is done by vital.linear.modes (participation factors); the classes add no
%   physics.
%   Errors: vital:badInput (not one vital.linear.modes entry).
    properties (SetAccess = protected)
        Name (1,:) char
        Eigenvalue double
        Oscillatory logical
        Wn double
        Zeta double
        Period double
        THalf double
        TDouble double
        Tau double
        Status (1,:) char
        Reason (1,:) char
    end
    properties (Access = protected)
        Raw struct
    end
    methods
        function obj = Mode(s)
            if nargin == 0, return; end
            need = {'name', 'eigenvalue', 'oscillatory', 'wn', 'zeta', 'period', 'tHalf', 'tDouble', 'tau', 'status', 'reason'};
            if ~isstruct(s) || ~isscalar(s) || ~all(isfield(s, need))
                error('vital:badInput', 'a Mode needs one vital.linear.modes entry.');
            end
            obj.Raw = s; obj.Name = s.name; obj.Eigenvalue = s.eigenvalue; obj.Oscillatory = s.oscillatory;
            obj.Wn = s.wn; obj.Zeta = s.zeta; obj.Period = s.period; obj.THalf = s.tHalf;
            obj.TDouble = s.tDouble; obj.Tau = s.tau; obj.Status = s.status; obj.Reason = s.reason;
        end
        function s = toStruct(obj)
            s = obj.Raw;
        end
    end
    methods (Static)
        function m = fromStruct(s)
            switch s.name
                case 'short_period', m = vital.modes.ShortPeriod(s);
                case 'phugoid',      m = vital.modes.Phugoid(s);
                case 'dutch_roll',   m = vital.modes.DutchRoll(s);
                case 'roll',         m = vital.modes.Roll(s);
                case 'spiral',       m = vital.modes.Spiral(s);
                otherwise,           m = vital.modes.Mode(s);
            end
        end
    end
end
