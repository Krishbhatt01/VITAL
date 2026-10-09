function [b, gains] = augmentedBuilder()
%AUGMENTEDBUILDER  The augmented F-16 of M8: the bare NESC F-16 with the M7 pitch
%   SAS and yaw damper at the CONFIRMED suggested gains.
%   [b, gains] = vital.uq.augmentedBuilder()
%   b      builder ctrl = b(AC, env, tr) for vital.fq.f16Factory('Controller', b):
%          vital.ctrl.combine(vital.ctrl.pitchSas(..., 'Kq', 0.02, 'Ka', 0.14),
%                             vital.ctrl.yawDamper(..., 'Kr', 0.82))
%   gains  struct(Kq, Ka, Kr, source)
%   Source: reports/ctrl/f16_sas_suggestion.md (status TARGET_REACHED, confirmed
%   by re-assessment; ADR ctrl-5). tests/M8/tF16Uq.m checks these values against
%   reports/ctrl/f16_sas_suggestion.json.
gains = struct('Kq', 0.02, 'Ka', 0.14, 'Kr', 0.82, ...
    'source', 'reports/ctrl/f16_sas_suggestion.md (vital.ctrl.suggestGains, TARGET_REACHED, confirmed)');
b = @(AC, env, tr) vital.ctrl.combine(vital.ctrl.pitchSas(AC, env, tr, 'Kq', 0.02, 'Ka', 0.14), ...
    vital.ctrl.yawDamper(AC, env, tr, 'Kr', 0.82));
end
