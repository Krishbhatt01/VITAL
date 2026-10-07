function r = run_f16_loads(V_ftps, h_ft, varargin)
%RUN_F16_LOADS  Show the F-16 force and moment breakdown (the entry point for users).
%
%   run_f16_loads                          at the NESC README trim: 565.6854 ft/s, 10,013 ft
%   run_f16_loads(700, 15000)              trim at any airspeed (ft/s, true) and altitude (ft)
%   run_f16_loads(700, 15000, 'CG', 30)    other CG (% MAC); also 'g_ftps2', 'gamma_deg'
%   run_f16_loads(565.6854, 10013, 'alpha_deg', 8, 'elevator_deg', 0, 'throttle_pct', 50)
%                                          a state YOU choose (not a trim): shows the
%                                          unbalanced loads and the accelerations
%   r = run_f16_loads(...)                 returns the numbers (see vital.aircraft.f16.loadsReport)
%
%   Works from any MATLAB session: it puts VITAL on the path itself.
addpath(fileparts(mfilename('fullpath')));
if nargin < 1, V_ftps = 565.6854; end
if nargin < 2, h_ft = 10013; end
if nargout == 0
    vital.aircraft.f16.loadsReport(V_ftps, h_ft, varargin{:});
else
    r = vital.aircraft.f16.loadsReport(V_ftps, h_ft, varargin{:});
end
end
