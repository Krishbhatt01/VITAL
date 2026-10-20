classdef Study
%STUDY  The M8 uncertainty study (run_f16_uq) as an object (0.8.1-OOP, ADR-037).
%   s = vital.uq.Study('Label', 'x', 'NumLHS', 32, ...)   options of run_f16_uq
%   r = s.run()        run_f16_uq(<the options given, in the order given>)
%   s.Options          struct of the options given (unset options keep the
%                      run_f16_uq defaults, which live only in run_f16_uq)
%   s.EntryPoint       function handle called by run (default @run_f16_uq;
%                      replaceable for tests and dry runs)
%   Errors: vital:badInput (an option run_f16_uq does not have, odd name-value list).
    properties
        EntryPoint function_handle = @run_f16_uq
    end
    properties (SetAccess = private)
        Options struct = struct()
    end
    properties (Access = private)
        Args cell = {}
    end
    properties (Constant, Hidden)
        Known = {'Label', 'ReportDir', 'Overwrite', 'Quiet', 'Groups', 'WidthScales', 'Conditions', ...
            'NumLHS', 'NumStarts', 'MaxEvals', 'NumCandidates', 'N', 'MaxRounds', 'LonOnly', 'Surrogate', ...
            'Method', 'CSR', 'Spec', 'Rules', 'AlphaMax', 'Resolution', 'EqualPct', 'DEPopulation', ...
            'DEGenerations', 'GridPoints', 'Staged', 'Stage1', 'Stage2Band', 'Lattice', 'LatticeMaxLevel', ...
            'LatticeMaxPoints', 'LatDropCmq', 'Bracket', 'LatticeCorners', 'LatticeTotalPoints', 'Piecewise'}
    end
    methods
        function obj = Study(varargin)
            if mod(numel(varargin), 2) ~= 0
                error('vital:badInput', 'Study options must be name-value pairs.');
            end
            for k = 1:2:numel(varargin)
                n = varargin{k};
                if ~(ischar(n) || isstring(n)) || ~any(strcmp(char(n), vital.uq.Study.Known))
                    error('vital:badInput', 'run_f16_uq has no option ''%s''.', string(n));
                end
                obj.Options.(char(n)) = varargin{k + 1};
            end
            obj.Args = varargin;
        end
        function r = run(obj)
            r = obj.EntryPoint(obj.Args{:});
        end
    end
end
