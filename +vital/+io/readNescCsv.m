function t = readNescCsv(caseFolder, sim)
%READNESCCSV  Read one NESC reference time history (English units, as published).
%   t = vital.io.readNescCsv('Atmos_01_DroppedSphere', 5) reads
%   <data>/nesc/extracted/Atmospheric_checkcases/Atmospheric_checkcases/
%          Atmos_01_DroppedSphere/Atmos_01_sim_05.csv
%   Column names are kept exactly as published (TM Vol II Table 75). A
%   duplicated column name (sim 5 repeats feVelocity_ft_s_Z) is made unique
%   by MATLAB; the first occurrence keeps the published name.
arguments
    caseFolder (1,:) char
    sim (1,1) double {mustBeInteger, mustBePositive}
end
prefix = regexp(caseFolder, '^Atmos_[^_]+', 'match', 'once');
if isempty(prefix)
    error('vital:io:nescFileNotFound', 'case folder "%s" is not an NESC Atmos_* folder.', caseFolder);
end
f = fullfile(vital.paths('data'), 'nesc', 'extracted', 'Atmospheric_checkcases', ...
    'Atmospheric_checkcases', caseFolder, sprintf('%s_sim_%02d.csv', prefix, sim));
if ~isfile(f)
    error('vital:io:nescFileNotFound', 'no reference file %s', f);
end
w = warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');
c = onCleanup(@() warning(w));
t = readtable(f, 'VariableNamingRule', 'preserve', 'Delimiter', ',');
end
