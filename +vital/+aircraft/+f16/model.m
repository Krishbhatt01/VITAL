function m = model(opts)
%MODEL  The NESC F-16 as a vital.AircraftModel (0.9.1-CORE; PLAN_CORE_FRAMES 4).
%   f16 = vital.aircraft.f16.model()
%   f16 = vital.aircraft.f16.model('CG_PCT_MAC', 30, 'BfrpOffset', d, 'AeroScale', s)
%   Options and every number are those of vital.aircraft.f16.config (called here),
%   so the model and the config struct describe the same aircraft:
%     axis_bfrp    root, the geometry datum (= the NESC MRC at 35 % MAC by default)
%     axis_mrc     the aero reference point, at AC.r_mrc (= -BfrpOffset)
%     axis_cg      the CG, at AC.r_cg (F16_inertia.dml DXCG = 0.01 cbar (35 - CG) ft
%                  forward of the MRC)
%     axis_engine  the engine, at the MRC (F16_prop.dml: thrust along body x, zero
%                  moments about the MRC); all axes body-parallel
%     aero    vital.AeroTableComponent on axis_mrc: the generated NASA DAVE-ML aero
%             model with the AeroScale multipliers (vital.aircraft.f16.aeroCoefficients)
%     engine  vital.PropulsorComponent on axis_engine, channel 'throttle'
%             (vital.aircraft.f16.engineThrust)
%     mass    vital.MassProperties(m, axis_cg, InertiaTensor(J, axis_cg))
%     controls {'de', 'da', 'dr', 'throttle'}, limits and reference geometry of config
%   The model is returned COMPILED. f16.derivatives(x, u, env) equals
%   vital.plant.derivatives(x, u, config(...), env) (tests/M9/core/tCoreModel.m).
arguments
    opts.CG_PCT_MAC (1,1) double = 25
    opts.BfrpOffset (3,1) double = [0; 0; 0]
    opts.AeroScale (1,1) struct = struct()
end
AC = vital.aircraft.f16.config('CG_PCT_MAC', opts.CG_PCT_MAC, 'BfrpOffset', opts.BfrpOffset, 'AeroScale', opts.AeroScale);
axis_bfrp = vital.Axis.root('bfrp');
axis_mrc = vital.Axis(AC.r_mrc, eye(3), axis_bfrp, 'Name', 'mrc');
axis_cg = vital.Axis(AC.r_cg, eye(3), axis_bfrp, 'Name', 'cg');
axis_engine = vital.Axis(AC.r_mrc, eye(3), axis_bfrp, 'Name', 'engine');
aero = vital.AeroTableComponent('aero', axis_mrc, @vital.aircraft.f16.aeroCoefficients, 'CoeffArgs', {AC}, ...
    'S', AC.S, 'b', AC.b, 'cbar', AC.cbar, 'Channels', {'de', 'da', 'dr'});
engine = vital.PropulsorComponent('engine', axis_engine, @vital.aircraft.f16.engineThrust, 'throttle');
mp = vital.MassProperties(AC.mass, axis_cg, vital.InertiaTensor(AC.J, axis_cg));
meta = struct('cgPctMac', AC.cgPctMac, 'aeroScale', AC.aeroScale, ...
    'source', 'vital.aircraft.f16.config (NASA NESC DAVE-ML F-16)');
m = vital.AircraftModel(AC.name, [axis_bfrp axis_mrc axis_cg axis_engine], {aero, engine}, mp, AC.controlNames, ...
    'Ref', struct('S', AC.S, 'b', AC.b, 'cbar', AC.cbar), 'Limits', AC.limits, 'Meta', meta);
m = m.compile();
end
