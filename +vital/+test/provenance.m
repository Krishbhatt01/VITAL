function out = provenance(action, varargin)
%PROVENANCE  In-memory log of every VitalTestCase check, flushed to JSON.
%
%   vital.test.provenance('clear')           empty the log
%   vital.test.provenance('add', rec)        append one record (struct)
%   recs = vital.test.provenance('get')      return all records (struct array)
%   vital.test.provenance('write', file)     write all records as JSON
%
%   Each record has the fields listed in FIELDS. run_vital_tests clears the
%   log before a gate run and writes <Mk>_<phase>_provenance.json after it,
%   so every number checked at a gate is traceable to its source tag and
%   citation.

persistent log
FIELDS = {'test','quantity','actual','expected','tol','mode','unit', ...
          'source','citation','pass','slack'};
if isempty(log)
    log = emptyLog(FIELDS);
end
out = [];
switch action
    case 'clear'
        log = emptyLog(FIELDS);
    case 'add'
        rec = varargin{1};
        missing = setdiff(FIELDS, fieldnames(rec));
        if ~isempty(missing)
            error('vital:test:badRecord', 'provenance record lacks: %s', strjoin(missing, ', '));
        end
        rec = orderfields(rmfield(rec, setdiff(fieldnames(rec), FIELDS)), FIELDS);
        log(end+1) = rec;
    case 'get'
        out = log;
    case 'set'
        % Replace the log; used to restore an outer run's records after a
        % nested run (the runner's own self-tests run the runner).
        recs = varargin{1};
        log = emptyLog(FIELDS);
        for k = 1:numel(recs), log(end+1) = orderfields(recs(k), FIELDS); end
    case 'write'
        file = varargin{1};
        recs = log;
        for k = 1:numel(recs)                 % JSON cannot hold NaN/Inf
            for f = {'actual','expected','tol','slack'}
                v = recs(k).(f{1});
                if isnumeric(v) && any(~isfinite(v(:)))
                    recs(k).(f{1}) = string(mat2str(v));
                end
            end
        end
        fid = fopen(file, 'w');
        if fid < 0, error('vital:test:cannotWrite', 'cannot write %s', file); end
        c = onCleanup(@() fclose(fid));
        if isempty(recs)
            fprintf(fid, '[]');
        else
            fprintf(fid, '%s', jsonencode(recs(:), 'PrettyPrint', true));
        end
    otherwise
        error('vital:test:badAction', 'unknown provenance action "%s"', action);
end
end

function log = emptyLog(fields)
args = [fields; repmat({{}}, 1, numel(fields))];
log = struct(args{:});
end
