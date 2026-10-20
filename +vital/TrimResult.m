classdef TrimResult
%TRIMRESULT  A vital.trim.solve result as an object (0.8.1-OOP, ADR-037).
%   tr = vital.TrimResult(t, fc)   t: the vital.trim.solve struct; fc: the
%                                  vital.FlightCondition it was solved at
%   Properties: Status, Reason, Alpha, Theta (rad), U [de da dr throttle],
%   X (13-state), Residual, Condition. tr.toStruct() returns t unchanged (the
%   functional chain takes it); tr.isOK() is true only for status 'OK' (only OK
%   may be used for analysis, CONVENTIONS 9).
%   Errors: vital:badInput (t lacks status/reason; fc not a FlightCondition).
    properties (SetAccess = private)
        Status (1,:) char
        Reason (1,:) char
        Alpha double = NaN
        Theta double = NaN
        U double = []
        X double = []
        Residual double = NaN
        Condition
    end
    properties (Access = private)
        Raw struct
    end
    methods
        function obj = TrimResult(t, fc)
            arguments
                t (1,1) struct
                fc = []
            end
            if ~all(isfield(t, {'status', 'reason'}))
                error('vital:badInput', 'a TrimResult needs a vital.trim.solve struct (status, reason, ...).');
            end
            if ~isempty(fc) && ~isa(fc, 'vital.FlightCondition')
                error('vital:badInput', 'the condition must be a vital.FlightCondition.');
            end
            obj.Raw = t;
            obj.Status = t.status; obj.Reason = t.reason; obj.Condition = fc;
            if isfield(t, 'alpha'), obj.Alpha = t.alpha; end
            if isfield(t, 'theta'), obj.Theta = t.theta; end
            if isfield(t, 'u'), obj.U = t.u; end
            if isfield(t, 'x'), obj.X = t.x; end
            if isfield(t, 'residual'), obj.Residual = t.residual; end
        end
        function t = toStruct(obj)
            t = obj.Raw;
        end
        function tf = isOK(obj)
            tf = strcmp(obj.Status, 'OK');
        end
    end
end
