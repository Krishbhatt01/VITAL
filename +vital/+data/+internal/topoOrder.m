function order = topoOrder(ids, deps)
%TOPOORDER  Evaluation order of DAVE-ML variables (the algorithm of
%   vital.daveml.read: depth-first over the variables in file order, each after
%   its dependencies). ids: 1xN cellstr; deps: 1xN cell of cellstr.
%   A cycle: vital:data:cycle; an unknown dependency: vital:data:undefinedVariable.
n = numel(ids);
state = zeros(1, n);
order = zeros(1, 0);
for k = 1:n
    [state, order] = visit(k, state, order);
end
    function [state, order] = visit(k, state, order)
        if state(k) == 2, return; end
        if state(k) == 1
            error('vital:data:cycle', 'circular dependency through variable "%s".', ids{k});
        end
        state(k) = 1;
        for d = deps{k}
            j = find(strcmp(ids, d{1}), 1);
            if isempty(j)
                error('vital:data:undefinedVariable', 'variable "%s" uses undefined variable "%s".', ids{k}, d{1});
            end
            [state, order] = visit(j, state, order);
        end
        state(k) = 2;
        order(end+1) = k;
    end
end
