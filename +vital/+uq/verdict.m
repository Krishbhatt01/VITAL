function v = verdict(bw, mc, opts)
%VERDICT  Robustness verdict of one group (M8).
%   v = vital.uq.verdict(csr, mc)          the HEADLINE verdict (amendment R4-2)
%   v = vital.uq.verdict(bw, mc)           the box verdict at one width (the
%                                          original M8 contract)
%   v = vital.uq.verdict(..., 'Reserve', 0, 'Required', 0.95)
%
%   R4-2 (docs/PLAN_M5_M8.md "Amendment R4"; first argument a vital.uq.csr
%   result of the JUDGED shape: fields status, alphaStar, alphaHi, cpvConfirmed):
%     'ROBUST'          (csr.status 'OK' with alphaStar >= 1, or csr.status
%                       'ROBUST_TO_CAP'), AND mc.cpLower >= Required
%     'NOT_ROBUST'      a confirmed CPV inside the judged box (cpvConfirmed and
%                       alphaHi <= 1, i.e. alpha*(judged) < 1 with a confirmed
%                       CPV; the bracket need not be resolved), OR
%                       mc.cpLower < Required
%     'NOT_ASSESSABLE'  anything else
%   v.csrStatus, v.alphaStar, v.alphaHi are added.
%
%   BOX VERDICT (first argument a bound-worst result, fields status, value):
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
%   Errors: vital:badInput (missing fields: a csr result needs status,
%   alphaStar, alphaHi, cpvConfirmed; a bound-worst result status, value).
arguments
    bw (1,1) struct
    mc (1,1) struct
    opts.Reserve (1,1) double = 0
    opts.Required (1,1) double = 0.95
end
if isfield(bw, 'alphaStar') && isfield(mc, 'cpLower')
    v = csrVerdict(bw, mc, opts);
    return
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

function v = csrVerdict(cs, mc, opts)
% amendment R4-2: the headline verdict from the judged-shape CSR and the Monte Carlo
if ~all(isfield(cs, {'status', 'alphaStar', 'alphaHi', 'cpvConfirmed'}))
    error('vital:badInput', 'a CSR verdict needs csr.status, alphaStar, alphaHi and cpvConfirmed.');
end
v = struct('verdict', '', 'reason', '', 'reserve', opts.Reserve, 'required', opts.Required, ...
    'cpLower', mc.cpLower, 'csrStatus', cs.status, 'alphaStar', cs.alphaStar, 'alphaHi', cs.alphaHi);
counter = logical(cs.cpvConfirmed) && cs.alphaHi <= 1;
lowP = ~(mc.cpLower >= opts.Required);
robustCsr = (strcmp(cs.status, 'OK') && cs.alphaStar >= 1) || strcmp(cs.status, 'ROBUST_TO_CAP');
if counter || lowP
    v.verdict = 'NOT_ROBUST';
    why = {};
    if counter
        why{end+1} = sprintf(['alpha*(judged) < 1: a confirmed CPV at scaled norm %.4g <= 1 lies inside the judged ' ...
            'box (CSR %s, alpha* %.4g)'], cs.alphaHi, cs.status, cs.alphaStar);
    end
    if lowP
        why{end+1} = sprintf('Clopper-Pearson lower bound %.4f < %.2f', mc.cpLower, opts.Required);
    end
    v.reason = strjoin(why, '; ');
elseif robustCsr
    v.verdict = 'ROBUST';
    if strcmp(cs.status, 'ROBUST_TO_CAP')
        t = sprintf('no failure up to the cap alpha = %g (ROBUST_TO_CAP)', cs.alphaStar);
    else
        t = sprintf('CSR alpha*(judged) = %.4g >= 1 (OK)', cs.alphaStar);
    end
    v.reason = sprintf('%s and Clopper-Pearson lower bound %.4f >= %.2f', t, mc.cpLower, opts.Required);
else
    v.verdict = 'NOT_ASSESSABLE';
    v.reason = sprintf(['CSR status %s (alpha* %.4g, bracket upper end %.4g, CPV confirmed %d): neither alpha*(judged) ' ...
        '>= 1 nor a confirmed CPV inside the judged box; Clopper-Pearson lower bound %.4f'], cs.status, cs.alphaStar, ...
        cs.alphaHi, logical(cs.cpvConfirmed), mc.cpLower);
end
end
