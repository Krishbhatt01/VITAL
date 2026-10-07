function rows = readFailureCatalogue(file)
%READFAILURECATALOGUE  Parse the table in docs\FAILURE_CATALOGUE.md.
%   Rows are Markdown table lines whose first cell starts with "FC-":
%   | ID | Milestone | Failure mode | Detection | Error / status ID | Test |
%   Backticks are stripped. Returns a struct array with fields
%   id, milestone, mode, detection, errorId, test.
lines = splitlines(string(fileread(file)));
rows = struct('id', {}, 'milestone', {}, 'mode', {}, 'detection', {}, 'errorId', {}, 'test', {});
for L = lines'
    t = strtrim(L);
    if ~startsWith(t, "| FC-"), continue; end
    cells = strtrim(split(extractBetween(t, 2, strlength(t) - 1), "|"));
    if numel(cells) ~= 6
        error('vital:io:badCatalogueRow', 'catalogue row needs 6 cells: %s', t);
    end
    cells = erase(cells, "`");
    rows(end+1) = struct('id', cells(1), 'milestone', cells(2), 'mode', cells(3), ...
        'detection', cells(4), 'errorId', cells(5), 'test', cells(6)); %#ok<AGROW>
end
end
