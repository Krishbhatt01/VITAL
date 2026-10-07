function v = piecewise(conds, vals, other)
%PIECEWISE  Runtime form of MathML <piecewise>: the value of the first true
%   condition, else the <otherwise> value. With no true condition and no
%   otherwise branch the result is undefined in MathML, so this raises
%   vital:daveml:piecewiseNoBranch rather than inventing a value.
k = find(conds, 1);
if ~isempty(k)
    v = vals(k);
elseif nargin == 3
    v = other;
else
    error('vital:daveml:piecewiseNoBranch', 'no <piece> condition is true and there is no <otherwise>.');
end
end
