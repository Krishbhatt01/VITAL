classdef Aircraft
%AIRCRAFT  Object view of a VITAL aircraft (value class; 0.8.1-OOP, ADR-037).
%   a = vital.Aircraft()                                   NESC F-16, CG 25 % MAC
%   a = vital.Aircraft('CG_PCT_MAC', 30, 'AeroScale', s, 'BfrpOffset', d)
%   The options are those of vital.aircraft.f16.config, which builds the numeric
%   runtime struct; the object only holds that struct. Every method delegates to
%   the functional core (the hot loop stays on flat structs, ADR-005):
%     AC  = a.toRuntime()             the exact vital.aircraft.f16.config struct
%     tr  = a.trim(fc)                vital.trim.solve       -> vital.TrimResult
%     lin = a.linearize(tr)           vital.linear.linearize -> vital.LinearModel
%     m   = a.modes(lin)              vital.linear.modes     -> cell of vital.modes.*
%     A   = a.assess(conditions)      vital.fq.assess        -> vital.fq.Assessment
%     [fw, st] = a.toFixedWing()      Aero.FixedWing (S, b, cbar) and an
%                                     Aero.FixedWing.State with mass, inertia, CG
%   fc is a vital.FlightCondition. Extra arguments of trim/linearize/modes are
%   passed to the core function unchanged.
%   Errors: those of the core (e.g. vital:badInput for a CG outside 0..100 %).

    properties (SetAccess = private)
        CgPctMac (1,1) double
        AeroScale struct
        BfrpOffset (3,1) double
    end
    properties (Access = private)
        Runtime struct
    end
    properties (Dependent)
        Name
        S
        b
        cbar
        Mass
        Inertia
        CG
        Limits
    end

    methods
        function obj = Aircraft(opts)
            arguments
                opts.CG_PCT_MAC (1,1) double = 25
                opts.AeroScale (1,1) struct = struct()
                opts.BfrpOffset (3,1) double = [0; 0; 0]
            end
            obj.Runtime = vital.aircraft.f16.config('CG_PCT_MAC', opts.CG_PCT_MAC, ...
                'AeroScale', opts.AeroScale, 'BfrpOffset', opts.BfrpOffset);
            obj.CgPctMac = opts.CG_PCT_MAC;
            obj.AeroScale = obj.Runtime.aeroScale;
            obj.BfrpOffset = opts.BfrpOffset;
        end

        function AC = toRuntime(obj)
            AC = obj.Runtime;
        end

        function v = get.Name(obj), v = obj.Runtime.name; end
        function v = get.S(obj), v = obj.Runtime.S; end
        function v = get.b(obj), v = obj.Runtime.b; end
        function v = get.cbar(obj), v = obj.Runtime.cbar; end
        function v = get.Mass(obj), v = obj.Runtime.mass; end
        function v = get.Inertia(obj), v = obj.Runtime.J; end
        function v = get.CG(obj), v = obj.Runtime.r_cg; end
        function v = get.Limits(obj), v = obj.Runtime.limits; end

        function tr = trim(obj, fc, varargin)
            if ~isa(fc, 'vital.FlightCondition') || ~isscalar(fc)
                error('vital:badInput', 'Aircraft.trim needs one vital.FlightCondition.');
            end
            t = vital.trim.solve(obj.Runtime, fc.toEnv(), fc.toTrimCond(), varargin{:});
            tr = vital.TrimResult(t, fc);
        end

        function lin = linearize(obj, tr, varargin)
            if ~isa(tr, 'vital.TrimResult') || ~isscalar(tr)
                error('vital:badInput', 'Aircraft.linearize needs one vital.TrimResult.');
            end
            l = vital.linear.linearize(obj.Runtime, tr.Condition.toEnv(), tr.toStruct(), varargin{:});
            lin = vital.LinearModel(l);
        end

        function m = modes(~, lin, varargin)
            if ~isa(lin, 'vital.LinearModel') || ~isscalar(lin)
                error('vital:badInput', 'Aircraft.modes needs one vital.LinearModel.');
            end
            m = lin.modes(varargin{:});
        end

        function A = assess(obj, conditions, opts)
            %ASSESS  MIL-F-8785C assessment (vital.fq.assess with vital.fq.f16Factory
            %   carrying THIS aircraft's AeroScale; the CG of each point is the
            %   condition's cg_pct_mac, as in the functional chain).
            %   'Rules' a vital.rules.RuleSet or loadRules struct (default: all records)
            %   'Controller' a vital.ctrl.ControlLaw or a builder handle (M7)
            %   'EngineOptions' cell of name-value options for vital.fq.assess
            arguments
                obj
                conditions (1,1) struct
                opts.Rules = []
                opts.Controller = []
                opts.EngineOptions cell = {}
            end
            rules = opts.Rules;
            if isempty(rules), rules = vital.fq.loadRules(); end
            if isa(rules, 'vital.rules.RuleSet'), rules = rules.toStruct(); end
            ctrl = opts.Controller;
            if isa(ctrl, 'vital.ctrl.ControlLaw'), ctrl = ctrl.builder(); end
            fac = vital.fq.f16Factory('AeroScale', nonUnitScale(obj.AeroScale), 'Controller', ctrl);
            A = vital.fq.Assessment(vital.fq.assess(rules, fac, conditions, opts.EngineOptions{:}));
        end

        function [fw, st] = toFixedWing(obj, fc)
            %TOFIXEDWING  Aero.FixedWing with S, b, cbar, and an Aero.FixedWing.State
            %   carrying mass, inertia (VITAL J, body axes) and CG (r_cg, BFRP axes).
            %   The coefficient model is NOT filled: Aero.FixedWing's linear
            %   coefficient sums cannot reproduce the NASA F-16 tables (ADR-037), so
            %   VITAL's aero stays the reference; this is for display/interchange.
            %   With a vital.FlightCondition, the state is at that condition.
            arguments
                obj
                fc = []
            end
            fw = fixedWingAircraft("VITAL");
            fw.ReferenceArea = obj.Runtime.S;
            fw.ReferenceSpan = obj.Runtime.b;
            fw.ReferenceLength = obj.Runtime.cbar;
            if nargout > 1
                if isempty(fc)
                    st = vital.Aircraft.massInto(fixedWingState(fw), obj.Runtime);
                else
                    st = fc.toFixedWingState(obj);
                end
            end
        end
    end

    methods (Static, Hidden)
        function st = massInto(st, AC)
            st.Mass = AC.mass;
            I = st.Inertia;
            I.Variables = AC.J;
            st.Inertia = I;
            st.CenterOfGravity = AC.r_cg.';
        end
    end
end

function s = nonUnitScale(s)
f = fieldnames(s);
for k = 1:numel(f)
    if s.(f{k}) == 1, s = rmfield(s, f{k}); end
end
end
