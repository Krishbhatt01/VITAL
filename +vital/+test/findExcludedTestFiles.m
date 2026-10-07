function excluded = findExcludedTestFiles(folders, suite)
%FINDEXCLUDEDTESTFILES  Test files in FOLDERS that produced no tests in SUITE.
%   Every .m file under the scanned test folders is a test class by
%   convention, except files inside package (+pkg) or private folders,
%   which are support code. A test file that matlab.unittest could not load
%   (parse error, missing superclass, shadowing) contributes no element to
%   the suite; such files are returned (absolute paths) so the runner can
%   fail the gate (FC-111).
excluded = {};
loaded = unique(string({suite.TestParentName}));
for k = 1:numel(folders)
    files = dir(fullfile(folders{k}, '**', '*.m'));
    for f = files(:)'
        full = fullfile(f.folder, f.name);
        if contains(full, [filesep '+']) || contains(full, [filesep 'private' filesep])
            continue
        end
        [~, cls] = fileparts(f.name);
        if ~any(loaded == cls)
            excluded{end+1} = full; %#ok<AGROW>
        end
    end
end
end
