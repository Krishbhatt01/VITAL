function m = legacyF16Model(opts)
%LEGACYF16MODEL  The 0.9.1-CORE builder vital.aircraft.f16.model, FROZEN (commit 169995f,
%   +vital/+aircraft/+f16/model.m, copied verbatim apart from its name) as the
%   reference of D1 (docs/PLAN_DATA_LAYER.md criterion 4): the model built from the
%   data object must be bitwise equal to this one. It builds the model from
%   vital.aircraft.f16.config (the hand-copied numbers), NOT from the data object.
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
