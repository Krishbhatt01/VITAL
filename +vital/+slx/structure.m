function s = structure(model)
%STRUCTURE  Canonical structural description and SHA-256 hash of a Simulink model
%   (docs/PLAN_M9.md section 4). Layout, file dates and other cosmetic data are
%   excluded; everything that changes behaviour is included.
%
%   s = vital.slx.structure('VitalPlant')            a loaded model
%   s = vital.slx.structure('C:\...\VitalPlant.slx') a file (loaded and closed again)
%
%   s.blocks  struct array: name, type (BlockType, or 'MATLAB Function' for a
%             MATLAB Function block), params (canonical text of the key parameters,
%             including the MATLAB Function code and sample time)
%   s.lines   cellstr 'Src/p->Dst/q', one per destination port, sorted
%   s.solver  struct of the solver and logging settings
%   s.text    the canonical text; s.hash its SHA-256 (hex)
%   Errors: vital:slx:modelMissing (file not found).
model = char(model);
opened = false;
if endsWith(model, {'.slx', '.mdl'})
    if ~isfile(model)
        error('vital:slx:modelMissing', 'model file not found: %s', model);
    end
    [~, name] = fileparts(model);
    if bdIsLoaded(name) && ~strcmpi(get_param(name, 'FileName'), model)
        close_system(name, 0);
    end
    if ~bdIsLoaded(name)
        load_system(model);
        opened = true;
    end
else
    name = model;
end
cleanup = onCleanup(@() closeIf(opened, name));

h = find_system(name, 'SearchDepth', 1, 'Type', 'block');
blocks = struct('name', {}, 'type', {}, 'params', {});
rt = sfroot;
for k = 1:numel(h)
    b = h{k};
    nm = get_param(b, 'Name');
    ty = get_param(b, 'BlockType');
    p = {};
    switch ty
        case 'SubSystem'
            if strcmp(get_param(b, 'SFBlockType'), 'MATLAB Function')
                ty = 'MATLAB Function';
                ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', b);
                p = {['SampleTime=' get_param(b, 'SystemSampleTime')], ['Script=' strrep(ch.Script, sprintf('\r'), '')]};
            end
        case 'Integrator'
            p = paramList(b, {'InitialCondition', 'InitialConditionSource', 'ExternalReset', 'LimitOutput', ...
                'ShowStatePort', 'ShowSaturationPort', 'AbsoluteTolerance'});
        case 'DigitalClock'
            p = paramList(b, {'SampleTime'});
        case 'Outport'
            p = paramList(b, {'Port'});
        otherwise
            p = {};
    end
    blocks(end+1) = struct('name', nm, 'type', ty, 'params', strjoin(p, '; ')); %#ok<AGROW>
end
[~, o] = sort({blocks.name});
blocks = blocks(o);

lines = {};
for k = 1:numel(h)
    ph = get_param(h{k}, 'PortHandles');
    for i = 1:numel(ph.Inport)
        ln = get_param(ph.Inport(i), 'Line');
        if ln == -1
            lines{end+1} = sprintf('(unconnected)->%s/%d', get_param(h{k}, 'Name'), i); %#ok<AGROW>
            continue
        end
        sp = get_param(ln, 'SrcPortHandle');
        if sp == -1
            src = '(none)';
        else
            src = sprintf('%s/%d', get_param(get_param(sp, 'Parent'), 'Name'), get_param(sp, 'PortNumber'));
        end
        lines{end+1} = sprintf('%s->%s/%d', src, get_param(h{k}, 'Name'), i); %#ok<AGROW>
    end
end
lines = sort(lines);

sv = {'SolverType', 'Solver', 'FixedStep', 'StartTime', 'SaveTime', 'SaveOutput', 'SaveFormat', ...
    'OutputSaveName', 'TimeSaveName', 'SaveState', 'SignalLogging', 'LimitDataPoints', 'Decimation', ...
    'ReturnWorkspaceOutputs', 'AlgebraicLoopMsg', 'SimulationMode'};
solver = struct();
for k = 1:numel(sv)
    solver.(sv{k}) = get_param(name, sv{k});
end

txt = strings(0);
for k = 1:numel(blocks)
    txt(end+1) = sprintf('BLOCK %s | %s | %s', blocks(k).name, blocks(k).type, blocks(k).params); %#ok<AGROW>
end
for k = 1:numel(lines)
    txt(end+1) = "LINE " + lines{k}; %#ok<AGROW>
end
for k = 1:numel(sv)
    txt(end+1) = sprintf('SOLVER %s=%s', sv{k}, solver.(sv{k})); %#ok<AGROW>
end
s.blocks = blocks;
s.lines = lines;
s.solver = solver;
s.text = char(strjoin(txt, newline));
md = java.security.MessageDigest.getInstance('SHA-256');
d = typecast(md.digest(unicode2native(s.text, 'UTF-8')), 'uint8');
s.hash = lower(reshape(dec2hex(d, 2)', 1, []));
end

function p = paramList(b, names)
p = cell(1, numel(names));
for k = 1:numel(names)
    p{k} = sprintf('%s=%s', names{k}, get_param(b, names{k}));
end
end

function closeIf(opened, name)
if opened && bdIsLoaded(name), close_system(name, 0); end
end
