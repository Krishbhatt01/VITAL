function [lo, certified, why] = lowerEnd(cs)
%LOWEREND  The certified lower end of a CSR result (M8 amendment R5, R5-2: "the
%   verdict comes from the judged box R(1)").
%   [lo, certified, why] = vital.uq.lowerEnd(csr)
%   csr   a vital.uq.csr or vital.uq.lattice CSR result
%   R5 form (fields lowerCertified, alphaLo): lo = csr.alphaLo, certified =
%     csr.lowerCertified (R(alphaLo) certified clean over the final candidate
%     conditions: every lattice cell meeting it certified, or a box search of it
%     clean, with no moving limit left and no failing or non-OK fresh
%     confirmation inside it), why = csr.lowerReason.
%   Legacy R4 form (no lowerCertified): certified = status 'OK' or
%     'ROBUST_TO_CAP' (alpha* resolved), lo = alphaStar; otherwise lo = NaN,
%     certified false. The R4 verdict is the special case of this reading.
%   Errors: vital:badInput (lowerCertified without alphaLo; no status).
arguments
    cs (1,1) struct
end
if ~isfield(cs, 'status')
    error('vital:badInput', 'lowerEnd needs a CSR result with status.');
end
if isfield(cs, 'lowerCertified')
    if ~isfield(cs, 'alphaLo')
        error('vital:badInput', 'a CSR result with lowerCertified must have alphaLo.');
    end
    lo = double(cs.alphaLo);
    certified = logical(cs.lowerCertified) && ~isnan(lo);
    why = '';
    if isfield(cs, 'lowerReason'), why = cs.lowerReason; end
    if isempty(why)
        if certified, why = sprintf('R(%.4g) certified', lo); else, why = 'R(alphaLo) not certified'; end
    end
    return
end
if ~isfield(cs, 'alphaStar')
    error('vital:badInput', 'a legacy CSR result needs alphaStar.');
end
certified = any(strcmp(cs.status, {'OK', 'ROBUST_TO_CAP'})) && ~isnan(cs.alphaStar);
if certified
    lo = double(cs.alphaStar);
    why = sprintf('legacy R4 result: status %s, alpha* %.4g', cs.status, lo);
else
    lo = NaN;
    why = sprintf('legacy R4 result: status %s (no certified lower end)', cs.status);
end
end
