function ref = reference(id)
%REFERENCE  The NESC reference time histories of one case, truncated to its duration.
%   ref = vital.nesc.reference('13.3')
%   One element per simulation listed for the case in NESC_CASE_MATRIX.json:
%     sim      simulation number
%     t        time (s, column), only samples with 0 <= t <= duration (+1e-6)
%              (sim 5 13.x files run to 60 / 239.9 s with float32 time stamps;
%              sim 2 cases 11/12 to 200 s: NESC_EXTRACT_F16.md risk 15)
%     columns  published column names (vital.io.readNescCsv keeps them; the
%              duplicated sim 5 feVelocity_ft_s_Z becomes feVelocity_ft_s_Z_1,
%              the first copy keeps its name)
%     data     the truncated table, English units as published
%   Column sets differ by simulation; vital.nesc.compare skips a simulation
%   that does not record a signal. Results are cached per MATLAB session.
persistent cache
if isempty(cache), cache = struct(); end
key = ['c' strrep(id, '.', '_')];
if isfield(cache, key), ref = cache.(key); return; end
cd = vital.nesc.caseDef(id);
ref = struct('sim', {}, 't', {}, 'columns', {}, 'data', {});
for s = cd.sims
    T = vital.io.readNescCsv(cd.folder, s);
    keep = T.time >= 0 & T.time <= cd.duration + 1e-6;
    T = T(keep, :);
    ref(end+1) = struct('sim', s, 't', T.time, 'columns', {T.Properties.VariableNames}, 'data', T); %#ok<AGROW>
end
cache.(key) = ref;
end
