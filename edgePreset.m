function p = edgePreset(filename)
% Preset dipilih secara visual dari grid; bukan estimasi akurasi ground truth.
root=fileparts(mfilename('fullpath'));
t=readtable(fullfile(root,'edge_presets.csv'),setvartype(detectImportOptions(fullfile(root,'edge_presets.csv'),'TextType','string'),'Image','string'));
[~,name]=fileparts(filename); row=find(t.Image==string(name),1);
if isempty(row), p=[]; else, p=t(row,:); end
end

