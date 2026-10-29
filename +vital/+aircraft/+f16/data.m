function d = data(opts)
%DATA  The NESC F-16 as a vital.data.AircraftData, read from the NASA files
%   (D1, docs/PLAN_DATA_LAYER.md, ADR-042).
%   f16_data = vital.aircraft.f16.data()
%   f16_data = vital.aircraft.f16.data('CG_PCT_MAC', 30, 'BfrpOffset', d)
%   f16_data = vital.aircraft.f16.data('DataRoot', folder)   read a copy (the files
%              must still match data/MANIFEST.json: vital:data:hashMismatch)
%     CG_PCT_MAC  CG position, % MAC, 0..100 (default 25, the NESC test CG; the file's
%                 own default is 35): the input of F16_inertia.dml
%     BfrpOffset  the geometry datum d (m, body axes) from the MRC, as
%                 vital.aircraft.f16.config
%   Read from data/nesc/extracted/.../F16_S119_source (read-only, SHA-256 checked):
%     aero         F16_aero.dml     AeroDatabase: 50 variables, 18 tables, 16 check cases;
%                  reference S, b, cbar = sref, bspan, cbar; moments about the MRC
%                  (35 % MAC); body-axis coefficients cx cy cz cl cm cn
%     propulsion   F16_prop.dml     PropulsionData: T_IDLE, T_MIL, T_MAX tables, 9 check
%                  cases; thrust FEX along body x, zero moments about the MRC
%     mass         F16_inertia.dml  MassData at CG_PCT_MAC
%     controlLaws  F16_control.dml ('control'), F16_gnc.dml ('gnc')
%   Axes (body-parallel, CONVENTIONS 2): bfrp (root, the datum), mrc at -BfrpOffset,
%   cg at [DXCG; DYCG; DZCG] ft from the MRC (F16_inertia.dml) - BfrpOffset, engine at
%   the MRC. Controls de, da, dr, throttle with the limits of config (each with its
%   source line). The runtime binding names the existing functions
%   (vital.aircraft.f16.aeroCoefficients, engineThrust, loads), so
%   vital.AircraftModel.fromData(f16_data) is bitwise vital.aircraft.f16.model of
%   0.9.1-CORE (tests/M9/data/tDataModel.m).
arguments
    opts.CG_PCT_MAC (1,1) double = 25
    opts.BfrpOffset (3,1) double = [0; 0; 0]
    opts.DataRoot (1,:) char = ''
end
vital.validate.finite(opts.CG_PCT_MAC, 'CG_PCT_MAC');
vital.validate.finite(opts.BfrpOffset, 'BfrpOffset');
if opts.CG_PCT_MAC < 0 || opts.CG_PCT_MAC > 100
    error('vital:badInput', 'CG_PCT_MAC = %g must lie in [0, 100] %% MAC.', opts.CG_PCT_MAC);
end
folder = 'nesc/extracted/Atmospheric_models/F16_package/F16_package/F16_S119_source/';
files = strcat(folder, {'F16_aero.dml', 'F16_prop.dml', 'F16_inertia.dml', 'F16_control.dml', 'F16_gnc.dml'});
shas = cell(size(files));
for k = 1:numel(files)
    [~, shas{k}] = vital.data.sourceFile(files{k}, 'DataRoot', opts.DataRoot);   % hash checked on EVERY call
end
key = sprintf('f16|%s|%.17g|%.17g|%.17g|%.17g|%s', opts.DataRoot, opts.CG_PCT_MAC, opts.BfrpOffset, strjoin(shas, '|'));
d = vital.data.internal.memo(key, @() build(opts, folder));
end

function d = build(opts, folder)
rd = @(file, role) vital.data.DaveModel.partsFromDaveML([folder file], role, 'DataRoot', opts.DataRoot);

pa = rd('F16_aero.dml', 'aero');
v = @(id) pa.variables(strcmp({pa.variables.varID}, id));
ref.S = asParameter(v('sref'), 'S');
ref.b = asParameter(v('bspan'), 'b');
ref.cbar = asParameter(v('cbar'), 'cbar');
cmap = struct('role', {'CX', 'CY', 'CZ', 'Cl', 'Cm', 'Cn'}, 'varID', {'cx', 'cy', 'cz', 'cl', 'cm', 'cn'}, 'axes', 'body');
aero = vital.data.AeroDatabase(pa, ref, 'mrc', cmap);

pp = rd('F16_prop.dml', 'propulsion');
omap = struct('role', {'FX', 'FY', 'FZ', 'L', 'M', 'N', 'powerLevel'}, ...
    'varID', {'FEX', 'FEY', 'FEZ', 'TEL', 'TEM', 'TEN', 'PWR'});
prop = vital.data.PropulsionData(pp, 'engine', omap);

mass = vital.data.MassData(rd('F16_inertia.dml', 'mass'), struct('CG_PCT_MAC', opts.CG_PCT_MAC));
laws = [vital.data.ControlData(rd('F16_control.dml', 'control')), vital.data.ControlData(rd('F16_gnc.dml', 'gnc'))];

% ---- axes ------------------------------------------------------------------------
src = @(s, note) vital.data.Source(s.file, s.line, s.sha256, s.varID, s.element, note);
off = sprintf('BfrpOffset = %s m', mat2str(opts.BfrpOffset.'));
r_cg_wrt_mrc = mass.cgSI();
dx = mass.variable('DXCG').source;
ax = struct('name', {}, 'parent', {}, 'origin', {}, 'dcm', {});
ax(1) = axisDef('bfrp', '', zeros(3, 1), src(aero.source, ['root: the geometry datum = the NESC MRC (35 % MAC) + ' off]));
ax(2) = axisDef('mrc', 'bfrp', -opts.BfrpOffset, src(ref.S.source, ['moment reference centre at 35 % MAC (F16_aero.dml); ' ...
    'origin = -BfrpOffset; ' off]));
ax(3) = axisDef('cg', 'bfrp', r_cg_wrt_mrc - opts.BfrpOffset, src(dx, sprintf(['[DXCG DYCG DZCG] ft from the MRC at ' ...
    'CG_PCT_MAC = %g, x 0.3048, - BfrpOffset; %s'], opts.CG_PCT_MAC, off)));
ax(4) = axisDef('engine', 'bfrp', -opts.BfrpOffset, src(prop.variable('FEX').source, ['thrust FEX along body x, ' ...
    'FEY = FEZ = 0 and zero moments about the MRC: the engine axis is the MRC; ' off]));

% ---- controls and limits (the numbers of vital.aircraft.f16.config) -----------------
alpha = aero.breakpoint('ALPHA1'); de = aero.breakpoint('DE1'); beta2 = aero.breakpoint('BETA2');
pwr = prop.variable('PWR');
ail = laws(1).variable('ail'); rdr = laws(1).variable('rdr');
lim.alpha_deg = vital.data.Parameter('alpha_deg', [alpha.values(1) alpha.values(end)], 'deg', ...
    src(alpha.source, 'range of the ALPHA1 alpha breakpoints of the aero tables'), 'Description', 'angle of attack range of the data');
lim.de_deg = vital.data.Parameter('de_deg', [de.values(1) de.values(end)], 'deg', ...
    src(de.source, 'range of the DE1 elevator breakpoints (el min/max)'), 'Description', 'elevator deflection range');
lim.throttle = vital.data.Parameter('throttle', [0 1], 'nd', ...
    src(pwr.source, 'power lever angle PWR 0..100 % (its description); throttle = PWR / 100'), 'Description', 'throttle');
lim.beta_deg = vital.data.Parameter('beta_deg', [beta2.values(1) beta2.values(end)], 'deg', ...
    src(beta2.source, 'range of the BETA2 sideslip breakpoints (control-power tables)'), 'Description', 'sideslip range of the data');
lim.da_deg = vital.data.Parameter('da_deg', [-21.5 21.5], 'deg', ...
    src(ail.source, 'NESC control law ail = -21.5 totLatStk with |totLatStk| <= 1 (F16_control.dml:1117-1185)'), ...
    'Description', 'aileron deflection range');
lim.dr_deg = vital.data.Parameter('dr_deg', [-30 30], 'deg', ...
    src(rdr.source, ['NESC control law rdr = -30 totPedal with |totPedal| <= 1; the aileron-rudder interconnect ' ...
    '(+0.008 ail) is part of the law, not of the surface range']), 'Description', 'rudder deflection range');
controls = struct('name', {'de', 'da', 'dr', 'throttle'}, ...
    'role', {'elevator, trailing edge down positive (Cm_de < 0, CONVENTIONS 7)', ...
    'aileron, right trailing edge down positive (Cl_da < 0)', 'rudder, trailing edge left positive (Cn_dr < 0)', ...
    'throttle 0 idle .. 1 maximum (PWR = 100 throttle)'}, ...
    'varID', {'el', 'ail', 'rdr', 'PWR'}, 'limit', {'de_deg', 'da_deg', 'dr_deg', 'throttle'});

% ---- provenance and runtime binding ----------------------------------------------
ms = {aero, prop, mass, laws(1), laws(2)};
prov = struct('file', cellfun(@(m) m.source.file, ms, 'UniformOutput', false), ...
    'sha256', cellfun(@(m) m.source.sha256, ms, 'UniformOutput', false), ...
    'role', cellfun(@(m) m.role, ms, 'UniformOutput', false), 'name', cellfun(@(m) m.name, ms, 'UniformOutput', false));
rt.loadsFcn = 'vital.aircraft.f16.loads';
rt.components = struct('name', {'aero', 'engine'}, 'kind', {'aero', 'propulsor'}, 'axis', {'mrc', 'engine'}, ...
    'fcn', {'vital.aircraft.f16.aeroCoefficients', 'vital.aircraft.f16.engineThrust'}, ...
    'channels', {{'de', 'da', 'dr'}, {'throttle'}}, 'args', {'config', ''});
rt.aeroScaleNames = {'Cm_q', 'Cl_p', 'Cnt_table', 'Cm_table', 'Cl_table', 'Cn_r', 'Cm_basic', 'Cm_de'};
rt.configMeta = {'cgPctMac'};
rt.cgAxis = 'cg';
rt.root = 'bfrp';

p.name = 'F-16 (NASA NESC DAVE-ML, Stevens & Lewis / Garza & Morelli)';
p.description = ['NASA NESC F-16 check-case model (NASA/TM-2015-218675), read from the five DAVE-ML files ' ...
    'F16_aero, F16_prop, F16_inertia, F16_control and F16_gnc.dml.'];
p.options = struct('CG_PCT_MAC', opts.CG_PCT_MAC, 'BfrpOffset', opts.BfrpOffset);
p.axisDefs = ax;
p.aero = aero;
p.propulsion = prop;
p.mass = mass;
p.controlLaws = laws;
p.controls = controls;
p.limits = lim;
p.provenance = prov;
p.runtime = rt;
p.meta = struct('cgPctMac', opts.CG_PCT_MAC);
d = vital.data.AircraftData(p);
end

function p = asParameter(v, name)
p = vital.data.Parameter(name, v.value, v.units, v.source, 'Description', v.name);
end

function a = axisDef(name, parent, origin, source)
a = struct('name', name, 'parent', parent, ...
    'origin', vital.data.Parameter([name ' origin'], origin, 'm', source, 'Description', ['origin of axis ' name]), ...
    'dcm', eye(3));
end
