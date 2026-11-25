function tuneEdgeParameters()
% Exhaustive grid, tanpa ground truth: pilihan akhir harus ditinjau visual.
out='results_tuning'; if ~isfolder(out), mkdir(out); end
files=dir('bsds500_test_8/*.jpg'); methods={'Sobel','Prewitt','Roberts','Laplace','LoG','Canny'};
for k=1:numel(files)
 I=imread(fullfile(files(k).folder,files(k).name)); [~,base]=fileparts(files(k).name);
 tiles={}; rows={}; idx=0;
 for j=1:6
  for t=[.07 .15 .3]
   for s=[1 2.5 4]
    for r=[2 6]
     idx=idx+1; [~,M,S]=segmentEdges(I,methods{j},t,s,r);
     tile=imresize(S,[120 180]);
     % Titik ID tetap tersedia lewat nama file dan tabel, label dibuat dengan figure.
     tiles{idx}=tile; rows(idx,:)={idx,methods{j},t,s,r,nnz(M)};
    end
   end
  end
 end
 for page=1:3
  f=figure('Visible','off','Position',[0 0 1500 1100]);
  tiledlayout(6,6,'Padding','compact','TileSpacing','compact');
  for n=1:36
   id=(page-1)*36+n; nexttile; imshow(tiles{id}); title(sprintf('%d %s t%.2f s%.1f r%d',rows{id,1:5}),'FontSize',9);
  end
  exportgraphics(f,fullfile(out,sprintf('%s_grid%d.jpg',base,page)),'Resolution',100); close(f);
 end
 writetable(cell2table(rows,'VariableNames',{'ID','Method','Threshold','Sigma','Radius','Area'}),fullfile(out,[base '_grid.csv']));
 fprintf('DONE %s\n',base);
end
end
