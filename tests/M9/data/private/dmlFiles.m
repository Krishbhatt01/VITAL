function F = dmlFiles()
%DMLFILES  The nine NASA DAVE-ML files of D1 (docs/PLAN_DATA_LAYER.md criterion 1):
%   path relative to the data root, the aircraft, how the data object holds it
%   (accessor on vital.data.AircraftData) and the generated function of the same file.
f16 = 'nesc/extracted/Atmospheric_models/F16_package/F16_package/F16_S119_source/';
atm = 'nesc/extracted/Atmospheric_models/';
F = struct('rel', {}, 'aircraft', {}, 'part', {}, 'generated', {});
F(end+1) = struct('rel', [f16 'F16_aero.dml'], 'aircraft', 'f16', 'part', 'aero', 'generated', 'vital.models.f16.aero');
F(end+1) = struct('rel', [f16 'F16_prop.dml'], 'aircraft', 'f16', 'part', 'propulsion', 'generated', 'vital.models.f16.prop');
F(end+1) = struct('rel', [f16 'F16_inertia.dml'], 'aircraft', 'f16', 'part', 'mass', 'generated', 'vital.models.f16.inertia');
F(end+1) = struct('rel', [f16 'F16_control.dml'], 'aircraft', 'f16', 'part', 'control', 'generated', 'vital.models.f16.control');
F(end+1) = struct('rel', [f16 'F16_gnc.dml'], 'aircraft', 'f16', 'part', 'gnc', 'generated', 'vital.models.f16.gnc');
F(end+1) = struct('rel', [atm 'brick_aero.dml'], 'aircraft', 'brick', 'part', 'aero', 'generated', 'vital.models.nesc.brick_aero');
F(end+1) = struct('rel', [atm 'brick_inertia.dml'], 'aircraft', 'brick', 'part', 'mass', 'generated', 'vital.models.nesc.brick_inertia');
F(end+1) = struct('rel', [atm 'cannonball_aero.dml'], 'aircraft', 'cannonball', 'part', 'aero', 'generated', 'vital.models.nesc.cannonball_aero');
F(end+1) = struct('rel', [atm 'cannonball_inertia.dml'], 'aircraft', 'cannonball', 'part', 'mass', 'generated', 'vital.models.nesc.cannonball_inertia');
end
