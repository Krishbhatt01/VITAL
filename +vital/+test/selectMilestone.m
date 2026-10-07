function sel = selectMilestone(suite, milestone, opts)
%SELECTMILESTONE  Keep tests tagged M0..Mk (cumulative); drop FIXTURE tests.
%   sel = vital.test.selectMilestone(suite, 'M3') keeps every test that has
%   a tag M0, M1, M2 or M3 (exact tag match, so 'M1' never matches 'M10')
%   and no FIXTURE tag. 'IncludeFixtures', true keeps fixtures too (used
%   only by the runner's own tests).
arguments
    suite matlab.unittest.Test
    milestone (1,:) char
    opts.IncludeFixtures (1,1) logical = false
end
mk = vital.test.milestoneNumber(milestone);
keep = false(size(suite));
for i = 1:numel(suite)
    tags = string(suite(i).Tags);
    nums = vital.test.milestoneNumber(tags(matches(tags, regexpPattern('^M\d+$'))), 'Quiet', true);
    inRange = any(nums <= mk);
    isFixture = any(tags == "FIXTURE");
    keep(i) = inRange && (opts.IncludeFixtures || ~isFixture);
end
sel = suite(keep);
end
