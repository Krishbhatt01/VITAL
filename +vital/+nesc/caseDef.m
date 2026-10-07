function cd = caseDef(id)
%CASEDEF  One NESC check-case as VITAL runs it, built from docs/NESC_CASE_MATRIX.json.
%   cd = vital.nesc.caseDef('1') ... ('16'); '13.1' ... '13.4'
%   M  = vital.nesc.caseDef('matrix')   the decoded matrix itself
%
%   Fields
%     id, title, folder (CSV folder), duration (s), sims (row), band (struct
%     array, exactly as registered: signal, floor, rel_floor, k, unit,
%     exclude_sims (row)), isF16
%     vehicle 'cannonball' | 'brick' | 'f16'; overrides (aero outputs forced by
%             the case, proposed ADR N9)
%     env     rotating-plant environment (vital.plant.derivativesRotating):
%             earth / rotation / gravity parsed from the matrix's earth and
%             gravity text; wind per ADR N10
%     ic      SI: lat, lon (rad), h (m), v_ned (m/s), eul [phi theta psi] (rad),
%             w_bi (rad/s; cases 1-10: the matrix's rate_inertial_body_deg_s);
%             F-16 cases take the case-11 IC for 13.x and are TRIMMED
%             (vital.nesc.f16Trim), so their eul/w_bi are empty here
%     x0      initial rotating state (cases 1-10; [] for the F-16)
%     controller  [] or struct: kind 'control' | 'gnc', mode 'stage' (the static
%             law evaluated at every RK4 stage; 'sampled' = ZOH at rate_hz 50),
%             steps (field,
%             t, delta), sidestep ([] or t, offset_ft), circlePoleSW, baseChi_deg,
%             recovered (alt/KEAS commands recovered from the IC, ADR-014)
%     dt      RK4 step (s); study.dt, study.window: step-size study (ADR N11)
%     guards  vital.sim.run Guards
%   Where the TM leaves a choice open, the proposed ADRs N1-N11 of
%   reports/fragments/nesc/DECISIONS.md apply.
%   Errors: vital:nesc:unknownCase.
persistent M
if isempty(M)
    M = jsondecode(fileread(fullfile(vital.paths('docs'), 'NESC_CASE_MATRIX.json')));
end
if strcmp(id, 'matrix'), cd = M; return; end
j = find(strcmp({M.cases.id}, id), 1);
if isempty(j)
    error('vital:nesc:unknownCase', 'NESC case "%s" is not in NESC_CASE_MATRIX.json (known: %s).', id, strjoin({M.cases.id}, ', '));
end
c = M.cases(j);
u = vital.units.constants(); ft = u.ft;
cd.id = id;
cd.title = c.title;
cd.folder = caseFolder(id);
cd.duration = c.duration_s;
cd.sims = reshape(c.sims, 1, []);
b = c.band;
for i = 1:numel(b)
    b(i).exclude_sims = reshape(double(b(i).exclude_sims), 1, []);
end
cd.band = b;
cd.isF16 = startsWith(c.vehicle, 'F-16');
% ---- Earth, gravity (parsed from the matrix text) --------------------------------
isSphere = startsWith(strtrim(c.earth), 'sphere');
rot = ~contains(c.earth, 'rotation no');
if contains(c.gravity, 'inverse square'), grav = 'central'; else, grav = 'J2'; end
if isSphere, earth = 'sphere'; else, earth = 'wgs84'; end
cd.env = struct('earth', earth, 'rotation', rot, 'gravity', grav, ...
    'wind_n', [0; 0; 0], 'windGradient_n', [0; 0; 0], 'deltaT', 0);
switch id                                        % ADR N10 (matrix wind text)
    case '7'
        cd.env.wind_n = [0; 20; 0] * ft;           % 20 ft/s from the west: toward +East
    case '8'
        cd.env.wind_n = [0; -20; 0] * ft;          % East = 0.003 h_ft - 20 ft/s
        cd.env.windGradient_n = [0; 0.003; 0];     % (ft/s)/ft = 1/s
end
K = vital.geo.constants(earth);
% ---- vehicle, IC -------------------------------------------------------------------
cd.overrides = struct();
cd.controller = [];
cd.guards = struct();
if ~cd.isF16
    cd.vehicle = strtrim(extractBefore([c.vehicle_files{1} '_'], '_'));
    switch id
        case '1', cd.overrides = struct('CD', 0);
        case '2', cd.overrides = struct('CD', 0, 'Cl', 0, 'Cm', 0, 'Cn', 0);
        case '3', cd.overrides = struct('CD', 0);
    end
    alt = c.ic.alt_ft;
    if ischar(alt) || isstring(alt)
        alt = 30000;                               % ADR-008: cases 2/3 start at 30,000 ft
    end
    cd.ic.lat = deg2rad(c.ic.lat_deg); cd.ic.lon = deg2rad(c.ic.lon_deg); cd.ic.h = alt * ft;
    cd.ic.v_ned = c.ic.v_ned_ft_s(:) * ft;
    rpy = deg2rad(c.ic.euler_rpy_deg(:));
    cd.ic.eul = rpy;                               % [roll pitch yaw] = [phi theta psi]
    cd.ic.w_bi = deg2rad(c.ic.rate_inertial_body_deg_s(:));
    cd.x0 = vital.eom.rotatingState(cd.ic.lat, cd.ic.lon, cd.ic.h, cd.ic.v_ned, cd.ic.eul, cd.ic.w_bi, K);
    cd.dt = 0.01;
    cd.study = struct('dt', 0.02, 'window', cd.duration);
else
    cd.vehicle = 'f16';
    ic = c.ic;
    if isfield(ic, 'same_as'), ic = M.cases(strcmp({M.cases.id}, '11')).ic; end
    cd.ic.lat = deg2rad(ic.lat_deg); cd.ic.lon = deg2rad(ic.lon_deg); cd.ic.h = ic.alt_ft_msl * ft;
    cd.ic.v_ned = ic.v_ned_ft_s(:) * ft;
    cd.ic.psi = deg2rad(ic.euler_deg_rpy(3));
    cd.ic.eul = []; cd.ic.w_bi = [];
    cd.x0 = [];
    cd.dt = 0.02;
    ctl = struct('kind', 'control', 'mode', 'stage', 'rate_hz', 50, 'steps', struct('field', {}, 't', {}, 'delta', {}), ...
        'sidestep', [], 'circlePoleSW', NaN, 'baseChi_deg', rad2deg(cd.ic.psi), 'recovered', false);
    switch id
        case {'11', '12'}
            ctl = [];
        case '13.1', ctl.steps = struct('field', 'altCmd', 't', 5, 'delta', 100);
        case '13.2', ctl.steps = struct('field', 'keasCmd', 't', 5, 'delta', -5);
        case '13.3', ctl.steps = struct('field', 'baseChiCmd', 't', 15, 'delta', 15);
        case '13.4', ctl.sidestep = struct('t', 20, 'offset_ft', 2000);
        case '15', ctl.kind = 'gnc'; ctl.circlePoleSW = 1; ctl.recovered = true;
        case '16', ctl.kind = 'gnc'; ctl.circlePoleSW = 0; ctl.recovered = true;
    end
    cd.controller = ctl;
    % ADR N11r: the stage-evaluated autopilot law (N6r) is stiff and switches
    % between saturations, so the autopilot cases need dt = 0.005 s; the
    % trim flyouts keep 0.02 s. Studies: dt/2 over min(30 s, duration).
    if isempty(ctl)
        cd.study = struct('dt', 0.01, 'window', min(30, cd.duration));
    else
        cd.dt = 0.005;
        cd.study = struct('dt', 0.0025, 'window', min(30, cd.duration));
    end
    cd.guards = struct('stopOnOutOfEnvelope', false);   % case 12 runs the clamped tables (ADR-014)
end
end

function f = caseFolder(id)
root = fullfile(vital.paths('data'), 'nesc', 'extracted', 'Atmospheric_checkcases', 'Atmospheric_checkcases');
if contains(id, '.')
    pre = sprintf('Atmos_%sp%s_', extractBefore(id, '.'), extractAfter(id, '.'));
else
    pre = sprintf('Atmos_%02d_', str2double(id));
end
d = dir(fullfile(root, [pre '*']));
d = d([d.isdir]);
if numel(d) ~= 1
    error('vital:io:nescFileNotFound', 'no unique NESC folder %s* under %s', pre, root);
end
f = d.name;
end
