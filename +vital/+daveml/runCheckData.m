function rep = runCheckData(model, fh, opts)
%RUNCHECKDATA  Replay a DAVE-ML file's <checkData> static shots.
%   rep = vital.daveml.runCheckData(model, fh) evaluates the compiled model
%   fh at each shot's inputs and compares every checkOutput (pass when
%   |actual - expected| < tol, the rule NASA's verify scripts use:
%   F16_aero_verify.m:686) and every internalValue.
%   'Strict', true raises vital:daveml:checkDataMismatch on any failure (FC-205).
arguments
    model (1,1) struct
    fh (1,1) function_handle
    opts.Strict (1,1) logical = false
end
rep = struct('name', {}, 'pass', {}, 'outputs', {}, 'internal', {});
bad = strings(0);
for c = model.checks(:)'
    in = struct();
    for s = c.inputs(:)'
        in.(s.varID) = s.value;
    end
    out = fh(in);
    outs = struct('varID', {}, 'actual', {}, 'expected', {}, 'tol', {}, 'pass', {});
    for s = c.outputs(:)'
        a = out.(s.varID);
        ok = abs(a - s.value) < s.tol;
        outs(end+1) = struct('varID', s.varID, 'actual', a, 'expected', s.value, 'tol', s.tol, 'pass', ok); %#ok<AGROW>
        if ~ok, bad(end+1) = sprintf('%s/%s: %.10g vs %.10g (tol %g)', c.name, s.varID, a, s.value, s.tol); end %#ok<AGROW>
    end
    ints = struct('varID', {}, 'actual', {}, 'expected', {});
    for s = c.internal(:)'
        ints(end+1) = struct('varID', s.varID, 'actual', out.(s.varID), 'expected', s.value); %#ok<AGROW>
    end
    rep(end+1) = struct('name', c.name, 'pass', all([outs.pass]), 'outputs', outs, 'internal', ints); %#ok<AGROW>
end
if opts.Strict && ~isempty(bad)
    error('vital:daveml:checkDataMismatch', 'checkData failed:\n%s', strjoin(bad, newline));
end
end
