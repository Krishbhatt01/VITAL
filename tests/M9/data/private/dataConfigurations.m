function cfgs = dataConfigurations()
%DATACONFIGURATIONS  The 11 configurations of the 0.9.1-CORE equivalence gate
%   (tests/M9/core/tCoreModel.m, copied so the 1,100-state set is the same one):
%   default, each of the 8 AeroScale multipliers alone, all 8 together, and CG 30 %
%   with BfrpOffset [0.5 -0.1 0.2] m and Cm_q 0.5. Call after rng(91001).
names = {'Cm_q', 'Cl_p', 'Cnt_table', 'Cm_table', 'Cl_table', 'Cn_r', 'Cm_basic', 'Cm_de'};
cfgs = {{}};
for i = 1:numel(names)
    cfgs{end+1} = {'AeroScale', struct(names{i}, 0.3 + 1.7 * rand)}; %#ok<AGROW>
end
s = struct();
for i = 1:numel(names), s.(names{i}) = 0.3 + 1.7 * rand; end
cfgs{end+1} = {'AeroScale', s};
cfgs{end+1} = {'CG_PCT_MAC', 30, 'BfrpOffset', [0.5; -0.1; 0.2], 'AeroScale', struct('Cm_q', 0.5)};
end
