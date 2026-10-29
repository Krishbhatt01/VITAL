classdef Source
%SOURCE  Where a number comes from (value class; D1, ADR-042).
%   s = vital.data.Source(file, line, sha256, varID, element, note)
%     file     path of the source file RELATIVE to the data root ('/' separators),
%              e.g. 'nesc/extracted/Atmospheric_models/.../F16_aero.dml'
%     line     1-based line on which the element's start tag begins
%     sha256   lower-case hex SHA-256 of the whole file (data/MANIFEST.json)
%     varID    the DAVE-ML varID (or bpID, function output, ...) the number belongs
%              to; '' when the element has none
%     element  'variableDef' | 'breakpointDef' | 'function' | 'staticShot' |
%              'DAVEfunc' (the whole file) | 'fileHeader' | 'derived' | ... (free text)
%     note     how the number follows from the element when it is not the literal
%              value (e.g. 'range of the ALPHA1 breakpoints'); '' otherwise
%   tf = s.isValid()   file non-empty, line a positive integer, sha256 64 hex digits
%   s.toStruct(), vital.data.Source.fromStruct(st), char(s), disp(s)

    properties (SetAccess = private)
        file (1,:) char = ''
        line (1,1) double = NaN
        sha256 (1,:) char = ''
        varID (1,:) char = ''
        element (1,:) char = ''
        note (1,:) char = ''
    end

    methods
        function obj = Source(file, line, sha256, varID, element, note)
            arguments
                file (1,:) char
                line (1,1) double
                sha256 (1,:) char
                varID (1,:) char = ''
                element (1,:) char = ''
                note (1,:) char = ''
            end
            obj.file = strrep(file, '\', '/');
            obj.line = line;
            obj.sha256 = sha256;
            obj.varID = varID;
            obj.element = element;
            obj.note = note;
        end

        function tf = isValid(obj)
            tf = isscalar(obj) && ~isempty(obj.file) && isfinite(obj.line) && obj.line >= 1 && ...
                obj.line == round(obj.line) && ~isempty(regexp(obj.sha256, '^[0-9a-f]{64}$', 'once'));
        end

        function s = toStruct(obj)
            s = struct('file', obj.file, 'line', obj.line, 'sha256', obj.sha256, 'varID', obj.varID, ...
                'element', obj.element, 'note', obj.note);
        end

        function c = char(obj)
            [~, f, e] = fileparts(obj.file);
            c = sprintf('%s%s:%d', f, e, obj.line);
            if ~isempty(obj.varID), c = sprintf('%s [%s]', c, obj.varID); end
            if ~isempty(obj.note), c = sprintf('%s (%s)', c, obj.note); end
            if numel(obj.sha256) >= 8, c = sprintf('%s, sha256 %s...', c, obj.sha256(1:8)); end
        end

        function disp(obj)
            if isempty(obj)
                fprintf('  (no source)\n');
            else
                for k = 1:numel(obj), fprintf('  %s\n', char(obj(k))); end
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            %FROMSTRUCT  [] (or a struct without a file) gives an EMPTY source.
            if isa(s, 'vital.data.Source'), obj = s; return; end
            if isempty(s) || (isstruct(s) && (~isfield(s, 'file') || isempty(s.file)))
                obj = vital.data.Source.empty;
                return
            end
            g = @(f, d) vital.data.internal.field(s, f, d);
            obj = vital.data.Source(char(s.file), vital.data.internal.num(g('line', NaN)), char(g('sha256', '')), ...
                char(g('varID', '')), char(g('element', '')), char(g('note', '')));
        end
    end
end
