function T = run_f16_trim(V_ftps, h_ft, varargin)
%RUN_F16_TRIM  Trim the NESC F-16 and print the result (the entry point for users).
%
%   run_f16_trim                          NESC README condition: 565.6854 ft/s, 10,013 ft
%   run_f16_trim(700, 15000)              any airspeed (ft/s, true) and altitude (ft)
%   run_f16_trim(700, 15000, 'CG', 30)    other CG (% MAC), 'g_ftps2', 'gamma_deg' as in
%                                         vital.aircraft.f16.trimLevel
%   T = run_f16_trim([450 600 750 900], 10013)   speed sweep, returned as a table
%
%   Works from any MATLAB session: it puts VITAL on the path itself.
%   Status meanings (docs/CONVENTIONS.md section 9): OK = a valid trim;
%   INFEASIBLE = not trimmable (e.g. stall-limited or a control at its limit);
%   NOT_CONVERGED; OUT_OF_DATA_ENVELOPE = converged outside the NASA data.
addpath(fileparts(mfilename('fullpath')));
if nargin < 1, V_ftps = 565.6854; end
if nargin < 2, h_ft = 10013; end
rows = [];
for V = V_ftps(:).'
    r = vital.aircraft.f16.trimLevel(V, h_ft, varargin{:});
    if isscalar(V_ftps) && nargout == 0
        vital.aircraft.f16.trimLevel(V, h_ft, varargin{:});
    end
    rows = [rows; {V, h_ft, r.status, r.theta_deg, r.alpha_deg, r.elevator_deg, r.throttle_pct, r.mach, r.thrust_lbf}]; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'V_ftps', 'h_ft', 'status', 'theta_deg', 'alpha_deg', ...
    'elevator_deg', 'throttle_pct', 'mach', 'thrust_lbf'});
if ~isscalar(V_ftps) && nargout == 0
    disp(T);
end
if nargout == 0, clear T; end
end
