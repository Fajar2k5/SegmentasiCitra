function output = runClassicalTests(kind)
% Batch B dan C memakai parameter pilihan per citra.
arguments
 kind char {mustBeMember(kind,{'all','edge','split'})} = 'all'
end
root=fileparts(mfilename('fullpath'));
output=fullfile(root,'results_classical',['batch_' kind]);
if ~isfolder(output), mkdir(output); end
files=dir(fullfile(root,'bsds500_test_8','*.jpg')); assert(numel(files)==8);
rows={};
for k=1:numel(files)
 I=imread(fullfile(files(k).folder,files(k).name)); [~,base]=fileparts(files(k).name);
 if ~strcmp(kind,'split')
  p=edgePreset(files(k).name);
  assert(~isempty(p),'Preset tidak ditemukan untuk %s.',files(k).name);
  method=char(p.Method); timer=tic;
  [E,M,S]=segmentEdges(I,method,p.Threshold,p.Sigma,p.Radius);
  seconds=toc(timer);
  assert(isequal(size(E),size(I,[1 2])) && islogical(E));
  imwrite([I repmat(uint8(E)*255,1,1,3) S],fullfile(output,[base '_' method '.png']));
  imwrite(M,fullfile(output,[base '_' method '_mask.png']));
  rows(end+1,:)={base,method,p.Threshold,p.Sigma,p.Radius,NaN,nnz(M),seconds};
 end
 if ~strcmp(kind,'edge')
  % Rusa membutuhkan threshold lebih kecil agar detail tidak terlalu tergabung.
  t=.08;
  if strcmp(base,'104010'), t=.04; end
   timer=tic; [L,S,info]=splitMerge(I,t,8); seconds=toc(timer);
   assert(all(L(:)>0) && isequal(size(S),size(I)));
   imwrite([im2double(I) S im2double(label2rgb(L))],fullfile(output,sprintf('%s_split_%.2f.png',base,t)));
   rows(end+1,:)={base,'SplitMerge',t,NaN,NaN,8,info.regions,seconds};
 end
end
writetable(cell2table(rows,'VariableNames', ...
 {'Image','Method','Threshold','Sigma','Radius','MinSize','AreaOrRegions','Seconds'}), ...
 fullfile(output,'summary.csv'));
fprintf('LULUS: batch %s, 8 citra, %d hasil.\n',kind,size(rows,1));
end
