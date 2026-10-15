classdef (TestTags = {'M5'}) tAxisChecksDisplay < vital.test.VitalTestCase
%TAXISCHECKSDISPLAY  The visual axis checks must be DRAWN right-handed and
%   must explain themselves (user request, 2026-10-14).
%
%   Finding (user, 2026-10-14, figure 04_combined): with North into the screen
%   and Up up, East appeared on the LEFT. Cause: the drawing helper mapped
%   (forward, right, down) to plot (x, y, -z), i.e. diag(1, 1, -1), a
%   reflection (det -1). NED is right-handed but North-East-Up is left-handed,
%   so 10 of the 13 figures (yaw, pitch, roll, combined, level, climb,
%   sideslip, gravity, control, path) were mirror images. The 58 numeric checks
%   were unaffected (computed before drawing), which is why no test caught it.
%   The two 2-D side views (cg, station) and the Earth-centred plot (earth)
%   were drawn correctly.
%
%   PRE-REGISTERED (written before the fix; coordinator, 2026-10-14):
%   1. vital.viz.displayMap() returns the 3x3 matrix M that takes a vector in
%      (forward/North, right/East, down) components to plot (x, y, z):
%      a. M is a proper rotation: M'M = I and det M = +1 (1e-15).
%      b. forward/North -> plot +y, right/East -> plot +x, down -> plot -z
%         (so Up is drawn up): M = [0 1 0; 1 0 0; 0 0 -1] exactly.
%      c. drawn North x drawn East = drawn Down (the frame stays right-handed).
%   2. Every 3-D figure that shows ground axes (yaw, pitch, roll, combined,
%      level, climb, path) labels x 'East', y 'North', z 'Up'; every 3-D
%      figure in body axes (sideslip, gravity, control) labels x as the right
%      wing, y as the nose and z as up. The two side views say from which side
%      they are seen ('right wing' for cg, 'left wing' for station).
%   3. vital.viz.axisNotes(id) gives, for each of the 13 cases, an explanation
%      (what the figure shows and why it matters, >= 80 characters) and one
%      meaning line per numeric check (count equal to the case's checks, each
%      >= 15 characters). axisChecks attaches them: R.cases(k).explain and
%      R.cases(k).checks(j).meaning.
%   4. Each drawn figure carries the explanation text, and each check's
%      meaning appears in the check panel.
%   5. run_axis_checks with plotting and a SaveDir writes README.md there,
%      naming all 13 cases with their explanations and every check meaning.
%      The console output is unchanged (tAxisChecks counts its PASS lines).
%   Sabotage: tests/M5/sabotages_axisdisplay.json restores the mirrored map
%   (S5AX-5) and drops the meanings from the panel (S5AX-6).
%   Test 2 calls displayMap first, so before the fix it is RED for the right
%   reason (vital:notImplemented), not by assertion.

    properties (Constant)
        GROUND = {'yaw', 'pitch', 'roll', 'combined', 'level', 'climb', 'path'}
        BODY = {'sideslip', 'gravity', 'control'}
        IDS = {'yaw', 'pitch', 'roll', 'combined', 'level', 'climb', 'sideslip', ...
            'gravity', 'cg', 'station', 'control', 'path', 'earth'}
    end

    methods (Test)
        function displayMapIsProperRotation(tc)
            M = vital.viz.displayMap();
            tc.verifyTol(M' * M, eye(3), 1e-15, 'abs', 'ANALYTIC', 'orthogonal', 'Quantity', 'M''M');
            tc.verifyTol(det(M), 1, 1e-15, 'abs', 'ANALYTIC', 'proper rotation, not a mirror', 'Quantity', 'det M');
            tc.verifyExact(M, [0 1 0; 1 0 0; 0 0 -1], 'ANALYTIC', 'x = right/East, y = forward/North, z = up');
            tc.verifyTol(cross(M * [1; 0; 0], M * [0; 1; 0]), M * [0; 0; 1], 1e-15, 'abs', 'ANALYTIC', ...
                'drawn North x drawn East = drawn Down', 'Quantity', 'handedness');
        end

        function figuresAreLabelledRightHanded(tc)
            vital.viz.displayMap();                       % RED for the right reason before the fix
            R = vital.viz.axisChecks('Plot', true, 'Visible', false);
            closer = onCleanup(@() close([R.cases.figure]));
            for k = 1:numel(R.cases)
                c = R.cases(k);
                ax = findobj(c.figure, 'Type', 'axes');
                ax = ax(end);
                xl = lower(ax.XLabel.String); yl = lower(ax.YLabel.String); zl = lower(ax.ZLabel.String);
                if ismember(c.id, tc.GROUND)
                    tc.verifySubstring(xl, 'east', [c.id ': x label']);
                    tc.verifySubstring(yl, 'north', [c.id ': y label']);
                    tc.verifySubstring(zl, 'up', [c.id ': z label']);
                elseif ismember(c.id, tc.BODY)
                    tc.verifySubstring(xl, 'right', [c.id ': x label']);
                    tc.verifySubstring(yl, 'nose', [c.id ': y label']);
                    tc.verifySubstring(zl, 'up', [c.id ': z label']);
                elseif strcmp(c.id, 'cg')
                    tc.verifySubstring(lower(strjoin(cellstr(ax.Subtitle.String), ' ')), 'right wing', 'cg: view side');
                elseif strcmp(c.id, 'station')
                    tc.verifySubstring(lower(strjoin(cellstr(ax.Subtitle.String), ' ')), 'left wing', 'station: view side');
                end
            end
        end

        function everyCaseAndCheckIsExplained(tc)
            for k = 1:numel(tc.IDS)
                n = vital.viz.axisNotes(tc.IDS{k});
                tc.verifyGreaterThanOrEqual(strlength(string(n.explain)), 80, [tc.IDS{k} ': explanation too short']);
            end
            R = vital.viz.axisChecks('Plot', false);
            tc.verifyEqual({R.cases.id}, tc.IDS);
            for k = 1:numel(R.cases)
                c = R.cases(k);
                tc.verifyGreaterThanOrEqual(strlength(string(c.explain)), 80, [c.id ': explain']);
                tc.assertTrue(isfield(c.checks, 'meaning'), [c.id ': checks carry a meaning']);
                for j = 1:numel(c.checks)
                    tc.verifyGreaterThanOrEqual(strlength(string(c.checks(j).meaning)), 15, ...
                        sprintf('%s check %d: meaning', c.id, j));
                end
            end
        end

        function figuresShowExplanationAndMeanings(tc)
            vital.viz.axisNotes('yaw');
            R = vital.viz.axisChecks('Plot', true, 'Visible', false, 'Cases', {'yaw', 'cg'});
            closer = onCleanup(@() close([R.cases.figure]));
            for k = 1:numel(R.cases)
                c = R.cases(k);
                txt = strjoin(cellfun(@(s) strjoin(cellstr(s), ' '), ...
                    get(findall(c.figure, 'Type', 'textboxshape'), {'String'}), 'UniformOutput', false), ' ');
                tc.verifySubstring(txt, c.explain(1:40), [c.id ': explanation on the figure']);
                for j = 1:numel(c.checks)
                    tc.verifySubstring(txt, c.checks(j).meaning, sprintf('%s check %d: meaning on the figure', c.id, j));
                end
            end
        end

        function readmeIsWritten(tc)
            vital.viz.axisNotes('yaw');
            d = tempname; mkdir(d); cl = onCleanup(@() rmdir(d, 's'));
            txt = evalc('R = run_axis_checks(''Visible'', false, ''SaveDir'', d);');
            closer = onCleanup(@() close(findall(0, 'Type', 'figure', '-regexp', 'Name', '^VITAL axis check')));
            tc.verifyEqual(count(txt, 'PASS'), 14, 'console output unchanged: 13 case lines + verdict');
            f = fullfile(d, 'README.md');
            tc.assertTrue(isfile(f), 'README.md written');
            md = fileread(f);
            for k = 1:numel(R.cases)
                c = R.cases(k);
                tc.verifySubstring(md, c.id, 'case id in README');
                tc.verifySubstring(md, c.explain(1:40), [c.id ': explanation in README']);
                for j = 1:numel(c.checks)
                    tc.verifySubstring(md, c.checks(j).meaning, sprintf('%s check %d in README', c.id, j));
                end
            end
        end
    end
end
