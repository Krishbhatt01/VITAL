function files = generateModels(root)
%GENERATEMODELS  Compile the NESC sphere, brick and F-16 control-law DAVE-ML files.
%   files = vital.nesc.generateModels() writes, under the VITAL root,
%     +vital/+models/+nesc/cannonball_aero.m     from cannonball_aero.dml   (sphere, CD = 0.1)
%     +vital/+models/+nesc/cannonball_inertia.m  from cannonball_inertia.dml (1 slug, 3.6 slug ft2)
%     +vital/+models/+nesc/brick_aero.m          from brick_aero.dml        (rate damping, CD = 0.01)
%     +vital/+models/+nesc/brick_inertia.m       from brick_inertia.dml
%     +vital/+models/+f16/control.m              from F16_control.dml (Rev F)
%     +vital/+models/+f16/gnc.m                  from F16_gnc.dml (Rev C)
%   files = vital.nesc.generateModels(root) writes the same tree under another
%   root folder (tests use it to prove the committed files are current).
%   Every file goes through the existing path vital.daveml.read ->
%   vital.daveml.compile (minValue/maxValue are saturations, ADR-014). None of
%   these six DAVE-ML files carries checkData; the control laws are verified
%   by hand-evaluated cases (tests/M5/tF16ControlLaw.m). The F-16 aero, prop
%   and inertia models remain vital.aircraft.f16.generateModels' job.
%   Sources are the hashed NASA files in data/MANIFEST.json.
if nargin < 1 || isempty(root)
    root = vital.paths('root');
end
atm = fullfile(vital.paths('data'), 'nesc', 'extracted', 'Atmospheric_models');
f16 = fullfile(atm, 'F16_package', 'F16_package', 'F16_S119_source');
map = {fullfile(atm, 'cannonball_aero.dml'),    'cannonball_aero',    '+nesc';
       fullfile(atm, 'cannonball_inertia.dml'), 'cannonball_inertia', '+nesc';
       fullfile(atm, 'brick_aero.dml'),         'brick_aero',         '+nesc';
       fullfile(atm, 'brick_inertia.dml'),      'brick_inertia',      '+nesc';
       fullfile(f16, 'F16_control.dml'),        'control',            '+f16';
       fullfile(f16, 'F16_gnc.dml'),            'gnc',                '+f16'};
files = cell(size(map, 1), 1);
for k = 1:size(map, 1)
    folder = fullfile(root, '+vital', '+models', map{k, 3});
    m = vital.daveml.read(map{k, 1});
    files{k} = vital.daveml.compile(m, map{k, 2}, folder);
end
end
