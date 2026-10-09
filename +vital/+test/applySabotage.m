function applySabotage(srcRoot, dstRoot, sab)
%APPLYSABOTAGE  Copy a source tree and apply ONE deliberate code defect.
%   The source tree is never modified. The top-level 'data' folder is not
%   copied (sabotage runs read data through the VITAL_DATA_ROOT environment
%   variable instead). 'reports' IS copied, except its scratch subfolder
%   'reports/work': tests read committed reports (reports/fq, reports/ctrl),
%   and without them every edit "fails" those tests, i.e. a vacuous detection
%   (review R3 B1; tests/M0/tSabotageReports.m). Copying, rather than pointing
%   the child at the real reports, keeps anything a sabotaged test writes
%   inside the copy. The pattern must occur
%   exactly once in the target file:
%     0 occurrences -> sabotage:patternNotFound  (a silent no-op would make
%                      a sabotage look "undetected" for the wrong reason)
%     >1            -> sabotage:patternAmbiguous
arguments
    srcRoot (1,:) char
    dstRoot (1,:) char
    sab (1,1) struct
end
if isfolder(dstRoot)
    error('sabotage:destinationExists', 'destination %s already exists', dstRoot);
end
mkdir(dstRoot);
items = dir(srcRoot);
items = items(~ismember({items.name}, {'.', '..', 'data', 'reports'}));
for k = 1:numel(items)
    copyfile(fullfile(srcRoot, items(k).name), fullfile(dstRoot, items(k).name));
end
rep = fullfile(srcRoot, 'reports');
if isfolder(rep)
    mkdir(fullfile(dstRoot, 'reports'));
    sub = dir(rep);
    sub = sub(~ismember({sub.name}, {'.', '..', 'work'}));
    for k = 1:numel(sub)
        copyfile(fullfile(rep, sub(k).name), fullfile(dstRoot, 'reports', sub(k).name));
    end
end
target = fullfile(dstRoot, sab.file);
if ~isfile(target)
    error('sabotage:fileNotFound', 'sabotage %s: file %s not found', sab.id, sab.file);
end
txt = fileread(target);
n = numel(strfind(txt, sab.pattern));
if n == 0
    error('sabotage:patternNotFound', 'sabotage %s: pattern not found in %s', sab.id, sab.file);
elseif n > 1
    error('sabotage:patternAmbiguous', 'sabotage %s: pattern occurs %d times in %s', sab.id, n, sab.file);
end
txt = strrep(txt, sab.pattern, sab.replacement);
fid = fopen(target, 'w');
fwrite(fid, txt, 'char');
fclose(fid);
end
