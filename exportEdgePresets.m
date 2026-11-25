function exportEdgePresets()
% Reproduksi preset terpilih tanpa mengubah hasil baseline di results_classical.
root=fileparts(mfilename('fullpath')); out=fullfile(root,'results_tuning','selected');
if ~isfolder(out), mkdir(out); end
T=readtable(fullfile(root,'edge_presets.csv'),setvartype(detectImportOptions(fullfile(root,'edge_presets.csv'),'TextType','string'),'Image','string'));
for k=1:height(T)
 I=imread(fullfile(root,'bsds500_test_8',T.Image(k)+'.jpg'));
 [E,M,S]=segmentEdges(I,char(T.Method(k)),T.Threshold(k),T.Sigma(k),T.Radius(k));
 assert(any(M(:)),'Preset menghasilkan mask kosong.');
 imwrite([I repmat(uint8(E)*255,1,1,3) S],fullfile(out,T.Image(k)+'.png'));
 imwrite(M,fullfile(out,T.Image(k)+'_mask.png'));
 p=edgePreset(T.Image(k)); assert(p.Threshold==T.Threshold(k));
end
app=SegmentasiCitraApp('Visible','off'); cleanup=onCleanup(@()delete(app));
buttons=findall(app.EdgeTab,'Type','uibutton');
for k=1:numel(buttons)
 if strcmp(buttons(k).Text,'Preset citra'), buttons(k).ButtonPushedFcn(buttons(k),[]); end
end
fprintf('PASS: 8 preset, mask nonkosong, lookup, konstruksi GUI dan callback preset.\n');
end

