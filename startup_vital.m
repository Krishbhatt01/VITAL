function root = startup_vital()
%STARTUP_VITAL  Put VITAL on the MATLAB path and report the version.
%
%   root = startup_vital() adds the VITAL root folder (which holds the
%   +vital package and the run_* entry points) to the path and returns the
%   absolute root folder. Test folders are NOT added: tests are discovered
%   by run_vital_tests through matlab.unittest, so nothing under tests\ can
%   shadow framework code.
%
%   See docs\CONVENTIONS.md for units, frames and sign conventions.

root = fileparts(mfilename('fullpath'));
addpath(root);
fprintf('VITAL %s  (root: %s, MATLAB %s)\n', vital.version(), root, version('-release'));
end
