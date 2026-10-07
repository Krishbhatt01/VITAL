function tf = resultMentions(result, text)
%RESULTMENTIONS  True if a TestResult's recorded diagnostics mention TEXT.
%   Requires the run to have used matlab.unittest.plugins.DiagnosticsRecordingPlugin.
%   Looks at the full diagnostic report and at the identifier of every
%   exception the test raised, so it finds an error ID whether the test
%   errored directly or a verifyError reported it as the actual identifier.
tf = false;
if ~isfield(result.Details, 'DiagnosticRecord'), return; end
recs = result.Details.DiagnosticRecord;
for k = 1:numel(recs)
    if contains(string(recs(k).Report), text)
        tf = true; return;
    end
    if isprop(recs(k), 'Exception') && ~isempty(recs(k).Exception) && ...
            contains(string(recs(k).Exception.identifier), text)
        tf = true; return;
    end
end
end
