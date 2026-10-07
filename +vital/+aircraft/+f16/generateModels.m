function files = generateModels(folder)
%GENERATEMODELS  Compile the NESC F-16 DAVE-ML files into VITAL functions.
%   files = vital.aircraft.f16.generateModels() writes
%     +vital/+models/+f16/aero.m     from F16_aero.dml    (Garza/Stevens-Lewis subsonic aero)
%     +vital/+models/+f16/prop.m     from F16_prop.dml    (Stevens-Lewis thrust tables)
%     +vital/+models/+f16/inertia.m  from F16_inertia.dml (constant mass, CG input)
%   files = vital.aircraft.f16.generateModels(folder) writes them elsewhere
%   (used by tests to prove the committed files are current).
%   The sources are the hashed NASA files listed in data/MANIFEST.json.
if nargin < 1
    folder = fullfile(vital.paths('root'), '+vital', '+models', '+f16');
end
src = fullfile(vital.paths('data'), 'nesc', 'extracted', 'Atmospheric_models', ...
    'F16_package', 'F16_package', 'F16_S119_source');
map = {'aero', 'F16_aero.dml'; 'prop', 'F16_prop.dml'; 'inertia', 'F16_inertia.dml'};
files = cell(size(map, 1), 1);
for k = 1:size(map, 1)
    m = vital.daveml.read(fullfile(src, map{k, 2}));
    files{k} = vital.daveml.compile(m, map{k, 1}, folder);
end
end
