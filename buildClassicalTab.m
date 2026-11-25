function buildClassicalTab(tab, kind, rootDir)
% Panel B/C ditempatkan langsung di GUI utama.
g=uigridlayout(tab,[3 1]); g.RowHeight={90,'1x',30};
c=uigridlayout(g,[2 8]); c.Layout.Row=1;
files=dir(fullfile(rootDir,'bsds500_test_8','*.jpg'));
pick=uidropdown(c,'Items',{files.name});
uibutton(c,'Text','Buka citra','ButtonPushedFcn',@browse);
method=uidropdown(c,'Items',{'Laplace','LoG','Sobel','Prewitt','Roberts','Canny'},'Value','Sobel');
uilabel(c,'Text','Threshold [0,1]');
t=uieditfield(c,'numeric','Limits',[0 1],'Value',.15);
uilabel(c,'Text','Sigma smoothing');
sigma=uieditfield(c,'numeric','Limits',[.1 20],'Value',1.4);
uibutton(c,'Text','Proses','ButtonPushedFcn',@run);
uilabel(c,'Text','Radius closing');
r=uieditfield(c,'numeric','Limits',[0 30],'RoundFractionalValues','on','Value',4);
uilabel(c,'Text','Ukuran minimum');
m=uieditfield(c,'numeric','Limits',[1 128],'RoundFractionalValues','on','Value',8);
uibutton(c,'Text','Uji 8 citra','ButtonPushedFcn',@batch);
if strcmp(kind,'split')
 t.Value=.08; method.Enable='off'; sigma.Enable='off'; r.Enable='off';
else
 m.Enable='off';
end
v=uigridlayout(g,[1 3]); v.Layout.Row=2;
ax1=uiaxes(v); ax2=uiaxes(v); ax3=uiaxes(v);
status=uilabel(g,'Text','Pilih citra dan tekan Proses.'); status.Layout.Row=3;
seed=[]; lastImage=[];
choose=uibutton(c,'Text','Klik objek','ButtonPushedFcn',@chooseObject);
presetButton=uibutton(c,'Text','Preset citra','ButtonPushedFcn',@applyPreset);
if strcmp(kind,'split'), choose.Enable='off'; presetButton.Enable='off'; end
custom=''; pick.ValueChangedFcn=@(~,~) reset();
 function reset(), custom=''; seed=[]; lastImage=[]; cla(ax1); cla(ax2); cla(ax3); end
 function browse(~,~)
  [f,p]=uigetfile({'*.jpg;*.png;*.bmp;*.tif','Citra'});
  if isequal(f,0), return; end
  seed=[]; custom=fullfile(p,f); status.Text=custom;
 end
 function run(~,~)
  try
   path=custom; if isempty(path), path=fullfile(rootDir,'bsds500_test_8',pick.Value); end
   I=imread(path); lastImage=I; imshow(I,'Parent',ax1); title(ax1,'Citra asli');
   if strcmp(kind,'edge')
    [E,M,S]=segmentEdges(I,method.Value,t.Value,sigma.Value,r.Value,seed);
    imshow(E,'Parent',ax2); title(ax2,method.Value);
    imshow(S,'Parent',ax3); title(ax3,'Objek hasil segmentasi');
    status.Text=sprintf('Luas: %d piksel. Klik objek untuk memilih region; mask kosong berarti kontur belum tertutup.',nnz(M));
   else
    [L,S,info]=splitMerge(I,t.Value,m.Value);
    imshow(label2rgb(L),'Parent',ax2); title(ax2,'Label region');
    imshow(S,'Parent',ax3); title(ax3,'Split and merge');
    status.Text=sprintf('%d daun split menjadi %d region.',info.leaves,info.regions);
   end
  catch ME, uialert(ancestor(tab,'figure'),ME.message,'Proses gagal'); end
 end
 function applyPreset(~,~)
  name=pick.Value; if ~isempty(custom), name=custom; end
  p=edgePreset(name);
  if isempty(p), status.Text='Belum ada preset untuk citra ini.'; return; end
  method.Value=char(p.Method); t.Value=p.Threshold; sigma.Value=p.Sigma; r.Value=p.Radius; seed=[];
  run([],[]); status.Text=char(p.Note);
 end
 function chooseObject(~,~)
  if isempty(lastImage), run([],[]); end
  if isempty(lastImage), return; end
  status.Text='Klik di dalam objek pada citra asli.';
  p=drawpoint(ax1); if isempty(p) || ~isvalid(p), return; end
  seed=p.Position; delete(p); run([],[]);
 end
 function batch(~,~)
  status.Text='Pengujian berjalan...'; drawnow;
  try
   output=runClassicalTests(kind); status.Text=['Hasil disimpan: ' output];
  catch ME, status.Text=ME.message; end
 end
end



