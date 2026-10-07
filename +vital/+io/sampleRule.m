function rec = sampleRule()
%SAMPLERULE  A schema-valid EXAMPLE rule record, for schema tests only.
%   The numbers are placeholders and are labelled as such. They are NOT
%   MIL-F-8785C values. Real records live in rules\mil_f_8785c\ and are
%   transcribed from the document with paragraph citations.
rec.id = 'EXAMPLE-SHORT-PERIOD-DAMPING';
rec.title = 'Example: short-period damping ratio bounds (schema test only)';
rec.ruleset = struct('name', 'EXAMPLE', 'revision', 'n/a', 'basis', 'schema test');
rec.class = 'Q-SPEC';
rec.source = struct('document', 'EXAMPLE (not a real requirement)', 'paragraph', '0.0', ...
    'page', '0', 'transcribed_by', 'schema test', 'verified', false);
rec.applicability = struct('aircraft_class', {{'IV'}}, 'flight_phase_category', {{'A','C'}});
rec.metric = 'short_period_damping_ratio';
rec.criterion.type = 'levels';
rec.criterion.levels = [ ...
    struct('level', 1, 'category', 'A', 'min', 0.35, 'max', 1.30), ...
    struct('level', 2, 'category', 'A', 'min', 0.25, 'max', 2.00)];
rec.scale = 0.1;
rec.conditions = struct('axes', {{'xcg','altitude','mach'}}, 'search', 'grid+refine');
rec.status_policy = struct('INFEASIBLE', 'not_assessable', 'NOT_CONVERGED', 'retry_then_not_assessable', ...
    'OUT_OF_DATA_ENVELOPE', 'indicative');
end
