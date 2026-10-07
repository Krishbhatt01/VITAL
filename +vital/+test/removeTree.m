function removeTree(folder)
%REMOVETREE  Delete a temporary folder tree if it exists (used for sabotage copies).
if isfolder(folder)
    rmdir(folder, 's');
end
end
