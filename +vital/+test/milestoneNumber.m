function n = milestoneNumber(names, opts)
%MILESTONENUMBER  'M7' -> 7. Errors vital:test:badMilestone on anything else.
arguments
    names
    opts.Quiet (1,1) logical = false   % Quiet: caller already filtered to valid tags
end
names = string(names);
n = zeros(size(names));
for i = 1:numel(names)
    tok = regexp(names(i), '^M(\d+)$', 'tokens', 'once');
    if isempty(tok)
        error('vital:test:badMilestone', 'milestone must look like M0, M1, ... not "%s"', names(i));
    end
    n(i) = str2double(tok{1});
end
end
