function [names, units] = metricNames()
%METRICNAMES  Names (and units) of the metrics vital.fq.metrics produces.
%   [names, units] = vital.fq.metricNames()
%   The names are the values allowed in a rule record's 'metric' field
%   (vital.fq.loadRules rejects any other: vital:fq:unknownMetric).
%   Definitions: vital.fq.metrics (MIL-F-8785C 6.2; docs/MIL8785C_EXTRACT.md 4).
T = {'zeta_sp',                      '-'
     'omega_nsp_rad_s',              'rad/s'
     'n_alpha_g_per_rad',            'g/rad'
     'CAP',                          '1/(g s^2)'
     'zeta_p',                       '-'
     'T2_phugoid_s',                 's'
     'T2_speed_divergence_s',        's'
     'speed_divergence_rate_1_s',    '1/s'
     'lon_divergence_rate_1_s',      '1/s'
     'T2_aperiodic_divergence_s',    's'
     'zeta_d',                       '-'
     'omega_nd_rad_s',               'rad/s'
     'zeta_d_omega_nd_rad_s',        'rad/s'
     'phi_beta_d',                   '-'
     'omega_nd2_phi_beta_d',         '(rad/s)^2'
     'tau_R_s',                      's'
     'spiral_T2_s',                  's'
     'coupled_roll_spiral_present',  '0/1'
     'zeta_RS_omega_nRS_rad_s',      'rad/s'};
names = T(:, 1).';
units = T(:, 2).';
end
