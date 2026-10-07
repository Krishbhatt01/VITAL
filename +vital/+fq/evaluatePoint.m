function P = evaluatePoint(ac, c)
%EVALUATEPOINT  Trim, linearize, modes and metrics at one condition point.
%   P = vital.fq.evaluatePoint(ac, c)      (the default PointFcn of vital.fq.assess)
%   ac  from an aircraft factory (vital.fq.f16Factory): AC, env, trimCond
%   c   the condition point (not used beyond what the factory put into ac)
%
%   Chain: vital.trim.solve(ac.AC, ac.env, ...) -> vital.linear.linearize(ac.AC,
%   ac.env, trim) (the SAME aircraft and environment, so the trim is an
%   equilibrium of the model linearized; review R1 B1) -> vital.linear.modes (8
%   states, and with height for the phugoid) -> vital.fq.metrics.
%   Only an OK trim is linearized (CONVENTIONS 9). A linear model whose status
%   is not OK is still used when the columns the metrics need are OK
%   (lin.columnStatus 1-8 and 13; linear ADR-028): e.g. at a thrust-table
%   altitude breakpoint only the h column (12) fails, so the 8-state metrics are
%   computed and the phugoid/speed metrics (which need h) get NOT_CONVERGED.
%   P fields:
%     status  'OK', or the status of the first stage that is not OK (INFEASIBLE,
%             NOT_CONVERGED, OUT_OF_DATA_ENVELOPE, ERROR, ...)
%     stage   'done' | 'trim' | 'linearize' | 'point' (an exception)
%     reason  text; for an exception its identifier and message
%     metrics vital.fq.metrics result (struct(), unless OK)
%     info    alpha_deg, de_deg, throttle, V_ftps, mach, keas, trimxu ([x; u]),
%             modes (name/status/eigenvalue), phugoidWithHeight, notes (cellstr:
%             points where the bare-airframe "equivalent system" of 3.1.12 is
%             doubtful: split short period, third oscillatory mode, roll-mode
%             fallback, coupled roll-spiral; review R2 MINOR 5)
%   AUGMENTED AIRCRAFT (M7): when ac has a controllerFcn (vital.fq.f16Factory
%   'Controller'), the controller ctrl = ac.controllerFcn(ac.AC, ac.env, trim) is
%   built at the trim and the CLOSED loop is linearized
%   (vital.linear.linearize(..., 'Controller', ctrl)); modes and metrics are then
%   those of the augmented aircraft. Equivalent system (MIL-F-8785C 3.1.12;
%   proposed ADR, reports/fragments/ctrl/DECISIONS.md): a static controller adds
%   no state, so the closed-loop modes are used directly; info.closedLoop = true
%   and info.equivalentSystem = 'CLASSICAL' when the 8-state closed-loop modes are
%   exactly the five classical modes, all OK, else 'FLAGGED' with a note citing
%   3.1.12. A controller the linearization refuses (e.g. not static:
%   vital:linear:dynamicController) makes the point an ERROR point (never a
%   number). Without a controllerFcn nothing changes and P.info has neither field.
%   An exception anywhere in the chain is recorded (stage 'point', status
%   ERROR) and counted by the engine as an excluded point; it is never
%   turned into a number.
arguments
    ac (1,1) struct
    c (1,1) struct %#ok<INUSA>
end
P = struct('status', 'OK', 'stage', 'done', 'reason', '', 'metrics', struct(), 'info', struct());
P.info.notes = {};
if isfield(ac, 'keas'), P.info.keas = ac.keas; end
try
    tr = vital.trim.solve(ac.AC, ac.env, ac.trimCond);
    if isfield(tr, 'u') && isfield(tr, 'x')
        P.info.alpha_deg = rad2deg(tr.alpha);
        P.info.de_deg = rad2deg(tr.u(1));
        P.info.throttle = tr.u(4);
        P.info.V_ftps = ac.trimCond.V / 0.3048;
        if isfield(tr, 'y') && isfield(tr.y, 'mach'), P.info.mach = tr.y.mach; end
        P.info.trimxu = [tr.x(:); tr.u(:)];
    end
    if ~strcmp(tr.status, 'OK')
        P.status = tr.status; P.stage = 'trim'; P.reason = tr.reason;
        return
    end
    if isfield(ac, 'controllerFcn') && ~isempty(ac.controllerFcn)
        P.info.closedLoop = true;                           % M7: augmented aircraft
        ctl = ac.controllerFcn(ac.AC, ac.env, tr);
        lin = vital.linear.linearize(ac.AC, ac.env, tr, 'Controller', ctl);
    else
        lin = vital.linear.linearize(ac.AC, ac.env, tr);
    end
    if ~strcmp(lin.status, 'OK')
        need = [1:8 13];
        if ~(isfield(lin, 'columnStatus') && all(strcmp(lin.columnStatus(need), 'OK')))
            P.status = lin.status; P.stage = 'linearize'; P.reason = lin.reason;
            return
        end
        P.info.notes{end+1} = sprintf('linearization %s outside the columns used (%s)', lin.status, lin.reason);
    end
    m = vital.linear.modes(lin);
    if strcmp(lin.columnStatus{12}, 'OK')
        mh = vital.linear.modes(lin, 'IncludeHeight', true);
        P.metrics = vital.fq.metrics(lin, m, 'PhugoidModes', mh);
        ph = mh(strcmp({mh.name}, 'phugoid'));
        if ~isempty(ph)
            P.info.phugoidWithHeight = struct('re', real(ph(1).eigenvalue), 'im', imag(ph(1).eigenvalue));
        end
    else
        why = sprintf('the h column of the linear model is %s (e.g. a thrust-table altitude breakpoint): no modes with height', ...
            lin.columnStatus{12});
        P.metrics = vital.fq.metrics(lin, m, 'PhugoidUnavailable', why);
    end
    P.info.modes = struct('name', {m.name}, 'status', {m.status}, ...
        're', num2cell(real([m.eigenvalue])), 'im', num2cell(imag([m.eigenvalue])));
    % 3.1.12 equivalent-system doubts (review R2 MINOR 5)
    for k = 1:numel(m)
        if ~isempty(m(k).reason)
            P.info.notes{end+1} = sprintf('%s (%s): %s', m(k).name, m(k).status, m(k).reason);
        end
    end
    if contains(P.metrics.tau_R_s.reason, 'fallback')
        P.info.notes{end+1} = ['roll mode: ' P.metrics.tau_R_s.reason];
    end
    if isequal(P.metrics.coupled_roll_spiral_present.value, 1)
        P.info.notes{end+1} = 'coupled roll-spiral oscillation';
    end
    if isfield(P.info, 'closedLoop')
        classical = {'short_period', 'phugoid', 'dutch_roll', 'roll', 'spiral'};
        names = {m.name};
        if numel(names) == numel(classical) && all(ismember(classical, names)) && all(strcmp({m.status}, 'OK'))
            P.info.equivalentSystem = 'CLASSICAL';
        else
            P.info.equivalentSystem = 'FLAGGED';
            P.info.notes{end+1} = sprintf(['closed loop, MIL-F-8785C 3.1.12: the closed-loop modes (%s) are not the ' ...
                'five classical modes, all OK; using them as the equivalent system is doubtful at this point'], ...
                strjoin(strcat(names, '/', {m.status}), ', '));
        end
    end
catch err
    P.status = 'ERROR'; P.stage = 'point';
    P.reason = sprintf('%s: %s', err.identifier, err.message);
    P.metrics = struct();
end
end
