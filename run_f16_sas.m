function r = run_f16_sas(V_ftps, h_ft, opts)
%RUN_F16_SAS  Bare vs augmented NESC F-16: modes and MIL-F-8785C Levels side by
%   side, and (on request) the design-feedback gain suggestion (M7; the entry
%   point for users).
%
%   run_f16_sas                              NESC README condition (565.6854 ft/s,
%                                            10,013 ft, CG 25 %), illustrative
%                                            gains Kq 0.1 s, Ka 0.2, Kr 0.5 s
%   run_f16_sas(700, 12000, 'CG', 30)        another condition (true airspeed ft/s,
%                                            altitude ft, CG % MAC)
%   run_f16_sas(..., 'Kq', 0.15, 'Ka', 0.3, 'Kr', 0.6, 'Kari', 0)
%                                            pitch SAS (vital.ctrl.pitchSas) and yaw
%                                            damper (vital.ctrl.yawDamper) gains
%   run_f16_sas(..., 'Law', 'lqr')           NASA's NESC LQR SAS (vital.ctrl.nescLqr)
%                                            instead of the pitch SAS + yaw damper
%   run_f16_sas(..., 'Suggest', true)        also run vital.ctrl.suggestGains over
%                                            the in-envelope points and confirm it
%                                            (several minutes); writes
%                                            <ReportDir>\f16_sas_suggestion.json/.md
%                                            (never overwritten unless 'Overwrite')
%   run_f16_sas(..., 'Suggest', true, 'SuggestOptions', {'MaxIter', 2})
%                                            name-value options passed on to
%                                            vital.ctrl.suggestGains
%   res = run_f16_sas(..., 'Quiet', true)    no printout
%
%   Prints: the trim; the 8-state modes of the BARE airframe and of the
%   AUGMENTED aircraft side by side (vital.ctrl.closedLoop: STABLE / UNSTABLE,
%   damping change, equivalent-system flag); the MIL-F-8785C group Levels AT
%   THIS CONDITION, each column labelled with the aircraft it belongs to (BARE
%   AIRFRAME or AUGMENTED with its gains), and whether the condition is inside
%   the NESC validity envelope (Levels outside it are indicative only).
%   Every Level is a REG result of the VITAL chain, not a published value.
%
%   res fields: condition, envelope, trim, law, gains, closedLoop
%   (vital.ctrl.closedLoop), levels (group, paragraph, category, bareLevel,
%   augLevel, bareMargin, augMargin, bareText, augText, bareStatus, augStatus;
%   a group with no rated point prints its status, e.g. NOT_ASSESSABLE when the
%   closed loop splits the phugoid), bareAssess, augAssess, suggestion
%   (vital.ctrl.suggestGains result or []), files.
%   Works from a fresh MATLAB session: it puts VITAL on the path itself.
arguments
    V_ftps (1,1) double = 565.6854
    h_ft (1,1) double = 10013
    opts.CG (1,1) double = 25
    opts.Kq (1,1) double = 0.1
    opts.Ka (1,1) double = 0.2
    opts.Kr (1,1) double = 0.5
    opts.Kari (1,1) double = 0
    opts.Law (1,:) char {mustBeMember(opts.Law, {'sas', 'lqr'})} = 'sas'
    opts.Suggest (1,1) logical = false
    opts.SuggestOptions cell = {}
    opts.ReportDir (1,:) char = ''
    opts.Overwrite (1,1) logical = false
    opts.Quiet (1,1) logical = false
end
addpath(fileparts(mfilename('fullpath')));
ft = 0.3048;
c = struct('h_ft', h_ft, 'V_ftps', V_ftps, 'cg_pct_mac', opts.CG, 'gamma_deg', 0, 'g_ftps2', 32.174);
fac0 = vital.fq.f16Factory();
ac = fac0(c);
res = struct('condition', c, 'envelope', '', 'trim', [], 'law', opts.Law, 'gains', struct(), 'label', '', ...
    'closedLoop', [], 'levels', struct([]), 'bareAssess', [], 'augAssess', [], 'suggestion', [], ...
    'files', struct('json', '', 'md', ''), 'status', '', 'reason', '');
tr = vital.trim.solve(ac.AC, ac.env, ac.trimCond);
res.trim = tr;
res.status = tr.status; res.reason = tr.reason;
if strcmp(opts.Law, 'sas')
    res.gains = struct('Kq', opts.Kq, 'Ka', opts.Ka, 'Kr', opts.Kr, 'Kari', opts.Kari);
    b = @(AC, env, t) vital.ctrl.combine(vital.ctrl.pitchSas(AC, env, t, 'Kq', opts.Kq, 'Ka', opts.Ka), ...
        vital.ctrl.yawDamper(AC, env, t, 'Kr', opts.Kr, 'Kari', opts.Kari));
    res.label = sprintf('AUGMENTED (pitch SAS Kq %g s, Ka %g; yaw damper Kr %g s, Kari %g)', ...
        opts.Kq, opts.Ka, opts.Kr, opts.Kari);
else
    b = @(AC, env, t) vital.ctrl.nescLqr(AC, env, t);
    res.label = 'AUGMENTED (NESC LQR SAS, F16_control.dml sasOn 1, apOn 0)';
end
if strcmp(tr.status, 'OK')
    res.closedLoop = vital.ctrl.closedLoop(ac.AC, ac.env, tr, b(ac.AC, ac.env, tr));
    R = vital.fq.loadRules();
    C = vital.fq.loadConditions(fullfile(vital.paths('rules'), 'mil_f_8785c', 'conditions_f16.json'), ...
        'Axes', struct('h_ft', h_ft, 'V_ftps', V_ftps, 'cg_pct_mac', opts.CG));
    res.bareAssess = vital.fq.assess(R, fac0, C);
    res.augAssess = vital.fq.assess(R, vital.fq.f16Factory('Controller', b), C);
    res.envelope = res.bareAssess.points(1).envelope;
    if strcmp(res.envelope, 'IN'), part = 'inEnvelope'; else, part = 'extrapolated'; end
    gb = res.bareAssess.groups; ga = res.augAssess.groups;
    L = struct('group', {}, 'paragraph', {}, 'category', {}, 'bareLevel', {}, 'augLevel', {}, ...
        'bareMargin', {}, 'augMargin', {}, 'bareText', {}, 'augText', {}, 'bareStatus', {}, 'augStatus', {});
    for k = 1:numel(gb)
        j = find(strcmp({ga.group}, gb(k).group), 1);
        sb = gb(k).(part); sa = ga(j).(part);
        L(end+1) = struct('group', gb(k).group, 'paragraph', gb(k).paragraph, 'category', gb(k).category, ...
            'bareLevel', sb.levelHeadline, 'augLevel', sa.levelHeadline, 'bareMargin', sb.criticalMargin, ...
            'augMargin', sa.criticalMargin, 'bareText', sb.levelText, 'augText', sa.levelText, ...
            'bareStatus', sb.status, 'augStatus', sa.status); %#ok<AGROW>
    end
    res.levels = L;
end
if opts.Suggest
    res.suggestion = vital.ctrl.suggestGains(opts.SuggestOptions{:});
    if isempty(opts.ReportDir), opts.ReportDir = fullfile(vital.paths('reports'), 'ctrl'); end
    res.files = writeSuggestion(res.suggestion, opts.ReportDir, opts.Overwrite);
end
if nargout > 0, r = res; end
if opts.Quiet, return; end

% ---- printout ---------------------------------------------------------------------------
fprintf('NESC F-16, bare airframe vs augmented: V = %.4f ft/s, h = %.0f ft, CG = %.1f %% MAC\n', V_ftps, h_ft, opts.CG);
fprintf('  trim status %s %s\n', tr.status, tr.reason);
if ~strcmp(tr.status, 'OK')
    fprintf('  not analysed: only an OK trim may be used.\n');
else
    fprintf('  trim: alpha %.4f deg, elevator %.4f deg, throttle %.4f\n', rad2deg(tr.alpha), rad2deg(tr.u(1)), tr.u(4));
    fprintf('  controller: %s\n', res.label);
    cl = res.closedLoop;
    fprintf('  closed loop (8 states): %s', cl.status);
    if cl.destabilized, fprintf('  -- DESTABILIZED by the controller (not an improvement)'); end
    fprintf('\n');
    if ~isempty(cl.extraModes)
        fprintf('  equivalent-system flag (MIL-F-8785C 3.1.12): closed-loop modes not classical: %s\n', strjoin(cl.extraModes, ', '));
    end
    fprintf('\n  %-13s | %-24s %8s %7s | %-24s %8s %7s | %7s\n', 'mode', 'BARE AIRFRAME eigenvalue', 'wn', 'zeta', ...
        'AUGMENTED eigenvalue', 'wn', 'zeta', 'dzeta');
    for k = 1:numel(cl.table)
        t = cl.table(k);
        fprintf('  %-13s | %-24s %8.4f %7.4f | %-24s %8.4f %7.4f | %7.4f\n', t.name, eigText(t.bareEigenvalue), t.bareWn, ...
            t.bareZeta, eigText(t.augEigenvalue), t.augWn, t.augZeta, t.dzeta);
    end
    for k = 1:numel(cl.unstable)
        fprintf('  UNSTABLE closed-loop mode: %s %s\n', cl.unstable(k).name, eigText(cl.unstable(k).eigenvalue));
    end
    if strcmp(res.envelope, 'IN')
        fprintf('\n  MIL-F-8785C Levels at this condition (envelope tag IN: inside the NESC validity envelope)\n');
    else
        fprintf('\n  MIL-F-8785C Levels at this condition (envelope tag %s: OUTSIDE the NESC validity envelope, indicative only)\n', res.envelope);
    end
    fprintf('  BARE AIRFRAME = the NESC F-16 without control; %s\n', res.label);
    fprintf('  %-20s %-4s | %-30s | %-30s\n', 'group', 'Cat', 'BARE AIRFRAME Level', 'AUGMENTED Level');
    for k = 1:numel(res.levels)
        e = res.levels(k);
        if strcmp(e.category, 'C'), continue; end
        fprintf('  %-20s %-4s | %-30s | %-30s\n', e.group, e.category, lvl(e.bareText, e.bareMargin, e.bareStatus), lvl(e.augText, e.augMargin, e.augStatus));
    end
    fprintf('  (Category C is NOT_ASSESSABLE for this model.) Every Level is a REG result of the VITAL chain, not a published value.\n');
end
if opts.Suggest
    s = res.suggestion;
    fprintf('\nDESIGN FEEDBACK (vital.ctrl.suggestGains, in-envelope points only)\n');
    fprintf('  status: %s\n  %s\n', s.status, s.reason);
    if strcmp(s.status, 'NOT_ASSESSABLE'), return; end
    fprintf('  proposed gains: %s\n', strjoin(arrayfun(@(i) sprintf('%s %g %s', s.gains.name{i}, s.gains.value(i), ...
        s.gains.unit{i}), 1:numel(s.gains.name), 'UniformOutput', false), ', '));
    fprintf('  %-20s %6s | %-24s | %-34s\n', 'target group', 'target', 'BARE AIRFRAME (Level, m)', 'AUGMENTED, CONFIRMED (Level, m)');
    for k = 1:numel(s.targets)
        t = s.targets(k);
        if t.reached, tag = 'CONFIRMED'; else, tag = 'NOT REACHED'; end
        fprintf('  %-20s %6d | Level %-3s m %-12.4g | Level %-3s m %-9.4g %s\n', t.group, t.level, num2str(t.bareLevel), ...
            t.bareMargin, num2str(t.achievedLevel), t.achievedMargin, tag);
    end
    reg = s.protected([s.protected.regressed]);
    if isempty(reg)
        fprintf('  no other in-envelope group is worse than bare (confirmed).\n');
    else
        fprintf('  WORSE THAN BARE: %s\n', strjoin({reg.group}, ', '));
    end
    if ~isempty(s.equivalentSystemFlags)
        fprintf('  equivalent-system flags (3.1.12) at %d points; see the report\n', numel(s.equivalentSystemFlags));
    end
    fprintf('  report: %s\n', res.files.md);
end
end

function t = eigText(l)
if isnan(l), t = '-'; elseif imag(l) ~= 0, t = sprintf('%.4f +/- %.4fi', real(l), abs(imag(l))); else, t = sprintf('%.4f', real(l)); end
end

function t = lvl(txt, m, st)
% a Level with its margin, or the status when no point could be rated (never a blank Level)
if isempty(txt), t = st; else, t = sprintf('%s (m %.3g)', txt, m); end
end

function files = writeSuggestion(s, dirName, overwrite)
if ~isfolder(dirName), mkdir(dirName); end
name = 'f16_sas_suggestion';
if ~overwrite && (isfile(fullfile(dirName, [name '.json'])) || isfile(fullfile(dirName, [name '.md'])))
    name = sprintf('%s_%s', name, char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmssSSS')));
end
out = rmfield(s, {'bare', 'confirmation'});
out.bareGroups = s.bare.groups;
out.confirmation = rmfield(s.confirmation, 'res');
if isfield(out, 'sensitivity') && ~isempty(out.sensitivity)
    out.sensitivity = rmfield(out.sensitivity, 'criticalFD');
end
files.json = fullfile(dirName, [name '.json']);
fid = fopen(files.json, 'w'); fprintf(fid, '%s', jsonencode(out, 'PrettyPrint', true)); fclose(fid);
files.md = fullfile(dirName, [name '.md']);
fid = fopen(files.md, 'w');
fprintf(fid, '# Design feedback: pitch SAS and yaw damper gains for the NESC F-16\n\n');
fprintf(fid, 'vital.ctrl.suggestGains; every Level is a REG result of the VITAL chain (no published F-16 Level exists).\n');
fprintf(fid, 'Only in-envelope points count (NESC validity envelope, a stated judgment; conditions_f16.json).\n\n');
fprintf(fid, '**Status: %s.** %s\n\n', s.status, s.reason);
if ~strcmp(s.status, 'NOT_ASSESSABLE')
    fprintf(fid, '## Proposed gains (rounded to %g; confirmed by a fresh vital.fq.assess)\n', s.gains.resolution);
    fprintf(fid, '| gain | value | unit | search box |\n|---|---|---|---|\n');
    for i = 1:numel(s.gains.name)
        fprintf(fid, '| %s | %g | %s | [%g, %g] |\n', s.gains.name{i}, s.gains.value(i), s.gains.unit{i}, s.gains.lo(i), s.gains.hi(i));
    end
    fprintf(fid, '\n## Targets (in-envelope headline Levels)\n');
    fprintf(fid, '| group | target | bare Level | bare margin | bare critical | augmented Level (confirmed) | margin | critical | reached |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|---|---|\n');
    for t = s.targets(:).'
        fprintf(fid, '| %s | %d | %s | %.4g | %s at %s | %s | %.4g | %s at %s | %d |\n', t.group, t.level, num2str(t.bareLevel), ...
            t.bareMargin, t.bareCritical.record, condStr(t.bareCritical.cond), num2str(t.achievedLevel), t.achievedMargin, ...
            t.critical.record, condStr(t.critical.cond), t.reached);
    end
    fprintf(fid, '\n## Protected groups (must keep their bare Level)\n| group | bare Level | augmented Level | regressed |\n|---|---|---|---|\n');
    for p = s.protected(:).'
        fprintf(fid, '| %s | %d | %s | %d |\n', p.group, p.bareLevel, num2str(p.achievedLevel), p.regressed);
    end
    fprintf(fid, '\n## Sensitivities (forward differences through the whole chain; d margin / d gain)\n');
    for it = s.sensitivity(:).'
        fprintf(fid, '\nIteration %d at %s\n\n| constraint | margin | req | %s | critical (record at condition) | switches with |\n', ...
            it.iteration, mat2str(it.k, 4), strjoin(strcat('d/d', it.gainNames), ' | '));
        fprintf(fid, '|%s\n', repmat('---|', 1, 5 + numel(it.gainNames)));
        for i = 1:numel(it.constraintNames)
            swn = it.gainNames(it.switched(i, :));
            fprintf(fid, '| %s | %.4g | %.4g | %s | %s at %s | %s |\n', it.constraintNames{i}, it.margins(i), it.req(i), ...
                strjoin(arrayfun(@(v) sprintf('%.4g', v), it.S(i, :), 'UniformOutput', false), ' | '), ...
                it.critical(i).record, condStr(it.critical(i).cond), strjoin(swn, ', '));
        end
    end
    fprintf(fid, '\n## Search history\n| k | merit | accepted | note |\n|---|---|---|---|\n');
    for h = s.history(:).'
        fprintf(fid, '| %s | %.4g | %d | %s |\n', mat2str(h.k, 4), h.merit, h.accepted, h.note);
    end
    fprintf(fid, '\n## Equivalent-system flags (MIL-F-8785C 3.1.12)\n');
    if isempty(s.equivalentSystemFlags)
        fprintf(fid, 'None: at every confirmed point the closed-loop modes are the five classical modes, all OK.\n');
    else
        for f = s.equivalentSystemFlags(:).'
            fprintf(fid, '- %s (%s): %s\n', condStr(f.cond), f.envelope, strjoin(f.notes, '; '));
        end
    end
    fprintf(fid, '\n%s\n', strjoin(s.notes, '\n'));
end
fclose(fid);
end

function t = condStr(c)
if ~isstruct(c) || isempty(fieldnames(c)), t = '-'; return; end
f = fieldnames(c);
f = f(~ismember(f, {'gamma_deg', 'g_ftps2'}));
t = strjoin(cellfun(@(n) sprintf('%s=%g', n, c.(n)), f.', 'UniformOutput', false), ' ');
end
