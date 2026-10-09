function v = verdict(bw, mc, opts)
%VERDICT  Robustness verdict of one group at one width (M8).
%   v = vital.uq.verdict(bw, mc)
%   v = vital.uq.verdict(bw, mc, 'Reserve', 0, 'Required', 0.95)
%
%   bw  vital.uq.boundWorst result (status, value)
%   mc  vital.uq.monteCarlo result (cpLower: one-sided Clopper-Pearson lower
%       bound of the success probability)
%   v.verdict
%     'ROBUST'          bw.status 'OK' with bw.value >= Reserve, AND
%                       mc.cpLower >= Required
%     'NOT_ROBUST'      a violation was found (bw.status 'VIOLATED', or a
%                       bound-worst value below Reserve), OR mc.cpLower < Required
%     'NOT_ASSESSABLE'  anything else (e.g. bound-worst NOT_ASSESSABLE with an
%                       adequate Monte Carlo lower bound)
%   v.reason says which condition decided; v.reserve, v.required, v.cpLower,
%   v.boundWorst, v.boundWorstStatus.
%   Errors: vital:badInput (missing fields).
arguments
    bw (1,1) struct
    mc (1,1) struct
    opts.Reserve (1,1) double = 0
    opts.Required (1,1) double = 0.95
end
if ~all(isfield(bw, {'status', 'value'})) || ~isfield(mc, 'cpLower')
    error('vital:badInput', 'verdict needs bw.status, bw.value and mc.cpLower.');
end
v = struct('verdict', '', 'reason', '', 'reserve', opts.Reserve, 'required', opts.Required, ...
    'cpLower', mc.cpLower, 'boundWorst', bw.value, 'boundWorstStatus', bw.status);
violated = strcmp(bw.status, 'VIOLATED') || (~isnan(bw.value) && bw.value < opts.Reserve);
lowP = ~(mc.cpLower >= opts.Required);
if violated || lowP
    v.verdict = 'NOT_ROBUST';
    why = {};
    if violated
        why{end+1} = sprintf('bound-worst margin %.4g < reserve %g (%s): a counterexample inside the box', ...
            bw.value, opts.Reserve, bw.status);
    end
    if lowP
        why{end+1} = sprintf('Clopper-Pearson lower bound %.4f < %.2f', mc.cpLower, opts.Required);
    end
    v.reason = strjoin(why, '; ');
elseif strcmp(bw.status, 'OK') && bw.value >= opts.Reserve
    v.verdict = 'ROBUST';
    v.reason = sprintf('bound-worst margin %.4g >= reserve %g (search OK) and Clopper-Pearson lower bound %.4f >= %.2f', ...
        bw.value, opts.Reserve, mc.cpLower, opts.Required);
else
    v.verdict = 'NOT_ASSESSABLE';
    v.reason = sprintf('bound-worst status %s (no counterexample) with Clopper-Pearson lower bound %.4f >= %.2f', ...
        bw.status, mc.cpLower, opts.Required);
end
end
