function T = modeTable(m)
%MODETABLE  Flight modes as a MATLAB table (for printing and reports).
%   T = vital.linear.modeTable(m)     m from vital.linear.modes
%   Columns: mode, eigenvalue (text, "re +/- im i" for a pair), wn_rad_s, zeta,
%   period_s, tHalf_s, tDouble_s, tau_s, dominant (states covering 80 % of the
%   participation), status. NaN means "not defined for this mode" (e.g. wn of a
%   real root or of a NOT_OSCILLATORY short period), never a missing number.
arguments
    m struct
end
n = numel(m);
ev = strings(n, 1); dom = strings(n, 1);
for k = 1:n
    l = m(k).eigenvalue;
    if m(k).oscillatory
        ev(k) = sprintf('%.4f +/- %.4fi', real(l), abs(imag(l)));
    else
        ev(k) = sprintf('%.4f', real(l));
    end
    dom(k) = strjoin(m(k).dominant, ' ');
end
T = table(string({m.name}).', ev, [m.wn].', [m.zeta].', [m.period].', [m.tHalf].', [m.tDouble].', ...
    [m.tau].', dom, string({m.status}).', 'VariableNames', ...
    {'mode', 'eigenvalue', 'wn_rad_s', 'zeta', 'period_s', 'tHalf_s', 'tDouble_s', 'tau_s', 'dominant', 'status'});
end
