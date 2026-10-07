function problems = checkCatalogue(rows, root, closed)
%CHECKCATALOGUE  Check failure-catalogue rows against the tests that exist.
%   problems = vital.io.checkCatalogue(rows, root, closed)
%     rows    from vital.io.readFailureCatalogue
%     root    VITAL root folder
%     closed  milestones whose gates are closed (docs/MILESTONES.json), e.g. {'M0','M1'}
%   Rules:
%     closed milestone        the row must name an existing test file and method
%     open, tests/M<k> exists the row may be PLANNED; if it names a test, that test must exist
%     not started             the row must be PLANNED
%   Returns a string array, one message per violation (empty when all rows comply).
arguments
    rows struct
    root (1,:) char
    closed cell
end
problems = strings(0);
for r = rows(:)'
    ms = char(r.milestone);
    planned = startsWith(string(r.test), "PLANNED");
    started = isfolder(fullfile(root, 'tests', ms));
    if ismember(ms, closed) && planned
        problems(end+1) = sprintf('%s: milestone %s is closed but its test is still PLANNED', r.id, ms); %#ok<AGROW>
        continue
    end
    if ~started
        if ~planned
            problems(end+1) = sprintf('%s: milestone %s not started, test must be PLANNED', r.id, ms); %#ok<AGROW>
        end
        continue
    end
    if planned, continue; end
    [file, method] = vital.io.splitTestRef(r.test);
    f = fullfile(root, file);
    if ~isfile(f)
        problems(end+1) = sprintf('%s: test file %s not found', r.id, file); %#ok<AGROW>
    elseif ~contains(fileread(f), "function " + method)
        problems(end+1) = sprintf('%s: method %s not in %s', r.id, method, file); %#ok<AGROW>
    end
end
end
