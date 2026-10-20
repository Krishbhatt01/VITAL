classdef FlightCondition
%FLIGHTCONDITION  A trim condition and its environment (value class; 0.8.1-OOP, ADR-037).
%   fc = vital.FlightCondition('V', 172.4, 'h', 3052)          SI: m/s, m (geometric)
%   fc = vital.FlightCondition(..., 'Gamma', 0, 'Psi', 0, 'G', 9.80665, ...
%                              'Wind_n', [0;0;0], 'Atmosphere', vital.atmos.IsaAtmosphere())
%   fc = vital.FlightCondition.fromFeet(V_ftps, h_ft, 'g_ftps2', 32.174, 'gamma_deg', 0)
%        the unit conversion of vital.fq.f16Factory / trimLevel (NESC README units)
%   Type is 'level' when Gamma = 0, else 'climb' (vital.trim.solve), unless given.
%
%   env  = fc.toEnv()         struct(g, wind_n, deltaT) of vital.plant.derivatives
%   cond = fc.toTrimCond()    struct(type, V, h, gamma, psi) of vital.trim.solve
%   atm  = fc.air()           the atmosphere at h (Atmosphere.at)
%   st   = fc.toFixedWingState(aircraft)        Aero.FixedWing.State at V, h
%   st   = fc.toFixedWingState(aircraft, tr)    ... at the trim state (alpha,
%          Euler angles, rates and NED position from tr.X)
%   The State's environment is aircraftEnvironment(fw, 'ISA', H) with H the
%   GEOPOTENTIAL height (that call passes its height to atmosisa unchanged), and
%   its gravity is G; mass, inertia and CG are the aircraft's.
%   Errors: vital:badInput (V <= 0 or non-finite, non-finite h, unknown Type).

    properties (SetAccess = private)
        Type (1,:) char
        V (1,1) double
        h (1,1) double
        Gamma (1,1) double
        Psi (1,1) double
        G (1,1) double
        Wind_n (3,1) double
        Atmosphere
    end

    methods
        function obj = FlightCondition(opts)
            arguments
                opts.V (1,1) double
                opts.h (1,1) double
                opts.Gamma (1,1) double = 0
                opts.Psi (1,1) double = 0
                opts.G (1,1) double = 9.80665
                opts.Wind_n (3,1) double = [0; 0; 0]
                opts.Type (1,:) char = ''
                opts.Atmosphere = vital.atmos.IsaAtmosphere()
            end
            if ~isfield(opts, 'V') || ~isfield(opts, 'h')
                error('vital:badInput', 'a FlightCondition needs V (m/s) and h (m).');
            end
            vital.validate.finite([opts.V opts.h opts.Gamma opts.Psi opts.G], 'flight condition');
            vital.validate.finite(opts.Wind_n, 'wind');
            if opts.V <= 0
                error('vital:badInput', 'airspeed V must be > 0 m/s, got %g.', opts.V);
            end
            if isempty(opts.Type)
                if opts.Gamma == 0, opts.Type = 'level'; else, opts.Type = 'climb'; end
            end
            if ~any(strcmp(opts.Type, {'level', 'climb'}))
                error('vital:badInput', 'unknown condition type ''%s'' (level | climb).', opts.Type);
            end
            if ~isa(opts.Atmosphere, 'vital.atmos.Atmosphere')
                error('vital:badInput', 'Atmosphere must be a vital.atmos.Atmosphere.');
            end
            obj.Type = opts.Type; obj.V = opts.V; obj.h = opts.h; obj.Gamma = opts.Gamma;
            obj.Psi = opts.Psi; obj.G = opts.G; obj.Wind_n = opts.Wind_n; obj.Atmosphere = opts.Atmosphere;
        end

        function env = toEnv(obj)
            env = struct('g', obj.G, 'wind_n', obj.Wind_n, 'deltaT', obj.Atmosphere.DeltaT);
        end

        function c = toTrimCond(obj)
            c = struct('type', obj.Type, 'V', obj.V, 'h', obj.h, 'gamma', obj.Gamma, 'psi', obj.Psi);
        end

        function atm = air(obj)
            atm = obj.Atmosphere.at(obj.h);
        end

        function st = toFixedWingState(obj, aircraft, tr)
            arguments
                obj
                aircraft (1,1) vital.Aircraft
                tr = []
            end
            fw = aircraft.toFixedWing();
            atm = obj.air();
            env = aircraftEnvironment(fw, 'ISA', atm.H);
            env.Gravity = obj.G;
            if obj.Atmosphere.DeltaT ~= 0       % ISA + dT: carry the core's values
                env.Temperature = atm.T; env.Density = atm.rho; env.SpeedOfSound = atm.a;
            end
            env.WindVelocity = obj.Wind_n.';
            st = fixedWingState(fw, env);
            st = vital.Aircraft.massInto(st, aircraft.toRuntime());
            st.AltitudeMSL = obj.h;
            st.XD = -obj.h;
            if isempty(tr)
                st.U = obj.V; st.V = 0; st.W = 0;
                st.Psi = obj.Psi;
            else
                if ~isa(tr, 'vital.TrimResult')
                    error('vital:badInput', 'the trim must be a vital.TrimResult.');
                end
                x = tr.X;
                e = vital.frames.dcm2eul(vital.frames.quat2dcm(x(7:10)));
                st.U = x(1); st.V = x(2); st.W = x(3);
                st.P = x(4); st.Q = x(5); st.R = x(6);
                st.Phi = e(1); st.Theta = e(2); st.Psi = e(3);
                st.XN = x(11); st.XE = x(12); st.XD = x(13); st.AltitudeMSL = -x(13);
            end
        end
    end

    methods (Static)
        function fc = fromFeet(V_ftps, h_ft, opts)
            arguments
                V_ftps (1,1) double
                h_ft (1,1) double
                opts.g_ftps2 (1,1) double = 32.174
                opts.gamma_deg (1,1) double = 0
                opts.DeltaT (1,1) double = 0
            end
            ft = 0.3048;
            fc = vital.FlightCondition('V', V_ftps * ft, 'h', h_ft * ft, 'Gamma', deg2rad(opts.gamma_deg), ...
                'G', opts.g_ftps2 * ft, 'Atmosphere', vital.atmos.IsaAtmosphere('DeltaT', opts.DeltaT));
        end
    end
end
