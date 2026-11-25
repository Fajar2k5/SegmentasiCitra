function mask = edgeInteriorMask(E, radius, seed)
% Region diambil dari interior kontur, bukan gabungan piksel tekstur tepi.
% Beberapa skala closing dicoba agar celah kecil tertutup tanpa langsung
% menyatukan seluruh latar. Seed opsional berformat [x y].
if nargin<3, seed=[]; end
[h,w]=size(E); mask=false(h,w); best=-inf;
if ~any(E(:)), return; end
for r=unique([0 1 2 radius])
 B=E;
 if r>0, B=imclose(B,strel('disk',r,0)); end
 holes=imfill(B,'holes') & ~B;
 CC=bwconncomp(holes,4);
 for k=1:CC.NumObjects
  ids=CC.PixelIdxList{k}; area=numel(ids);
  if area<max(12,.0002*h*w) || area>.85*h*w, continue; end
  candidate=false(h,w); candidate(ids)=true;
  % Kembalikan batas kontur tipis, bukan seluruh pita closing.
  candidate=imdilate(candidate,strel('disk',1,0));
  [yy,xx]=ind2sub([h w],ids);
  if ~isempty(seed)
   x=round(seed(1)); y=round(seed(2));
   if x<1 || x>w || y<1 || y>h || ~candidate(y,x), continue; end
   score=-area; % Region terkecil yang memuat titik menghindari latar luas.
  else
   centerPenalty=((mean(xx)-w/2)/w)^2+((mean(yy)-h/2)/h)^2;
   score=sqrt(area/(h*w))-.5*centerPenalty-.01*r;
  end
  if score>best, best=score; mask=candidate; end
 end
end
% Mask kosong adalah sinyal bahwa kontur belum tertutup; jangan mengganti
% hasil dengan gumpalan tepi yang tampak seperti objek padahal hanya tekstur.
mask=imfill(mask,'holes');
end


