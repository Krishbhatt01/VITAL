function m = model(opts)
%MODEL  The NESC F-16 as a vital.AircraftModel, built from its data object
%   (0.9.1-CORE, PLAN_CORE_FRAMES 4; since D1 from vital.aircraft.f16.data, ADR-042).
%   f16 = vital.aircraft.f16.model()
%   f16 = vital.aircraft.f16.model('CG_PCT_MAC', 30, 'BfrpOffset', d, 'AeroScale', s)
%   = vital.AircraftModel.fromData(vital.aircraft.f16.data('CG_PCT_MAC', .., 'BfrpOffset', ..), ...
%                                  'AeroScale', s)
%   The data object is read from the NASA DAVE-ML files (SHA-256 checked); options as
%   vital.aircraft.f16.config:
%     axis_bfrp    root, the geometry datum (= the NESC MRC at 35 % MAC by default)
%     axis_mrc     the aero reference point, at -BfrpOffset
%     axis_cg      the CG (F16_inertia.dml DXCG = 0.01 cbar (35 - CG) ft forward of the MRC)
%     axis_engine  the engine, at the MRC (F16_prop.dml: thrust along body x, zero
%                  moments about the MRC); all axes body-parallel
%     aero    vital.AeroTableComponent on axis_mrc: vital.aircraft.f16.aeroCoefficients
%             (the generated NASA DAVE-ML aero model with the AeroScale multipliers)
%     engine  vital.PropulsorComponent on axis_engine, channel 'throttle'
%             (vital.aircraft.f16.engineThrust)
%     mass    vital.MassProperties(m, axis_cg, InertiaTensor(J, axis_cg))
%     controls {'de', 'da', 'dr', 'throttle'}, limits and reference geometry
%   The model is returned COMPILED. It is BITWISE the 0.9.1-CORE model built from
%   config() (tests/M9/data/tDataModel.m), and f16.derivatives(x, u, env) equals
%   vital.plant.derivatives(x, u, config(...), env) (tests/M9/core/tCoreModel.m).
arguments
    opts.CG_PCT_MAC (1,1) double = 25
    opts.BfrpOffset (3,1) double = [0; 0; 0]
    opts.AeroScale (1,1) struct = struct()
end
f16_data = vital.aircraft.f16.data('CG_PCT_MAC', opts.CG_PCT_MAC, 'BfrpOffset', opts.BfrpOffset);
m = vital.AircraftModel.fromData(f16_data, 'AeroScale', opts.AeroScale);
end
