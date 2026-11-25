function mask = edgeObjectMask(E, radius, seed)
% Region diambil dari interior kontur, bukan gabungan piksel tekstur tepi.
% Beberapa skala closing dicoba agar celah kecil tertutup tanpa langsung
% menyatukan seluruh latar. Seed opsional berformat [x y].
if nargin<3, seed=[]; end
[h,w]=size(E); mask=false(h,w); best=-inf;
if ~any(E(:)), return; end
anchor=edgeInteriorMask(E,radius,seed);
for r=unique([0 1 2 radius])
 B=E;
 if r>0, B=imclose(B,strel('disk',r,0)); end
 holes=imfill(B,'holes') & ~B;
 % Gabungkan interior kontur sebelum memisahkan komponen: tepi internal
 % dapat menjadi bagian objek tanpa mengambil semua cabang tepi.
 % Buang ruang tertutup yang hampir menyentuh bingkai (sering latar).
 interior=holes; margin=min(3,min(h,w));
 frame=false(h,w); frame(1:margin,:)=true; frame(end-margin+1:end,:)=true;
 frame(:,1:margin)=true; frame(:,end-margin+1:end)=true;
 touching=imreconstruct(interior & frame,interior,4);
 interior=interior & ~touching;
 merged=imclose(interior,strel('disk',max(2,r),0));
 merged=imfill(merged,'holes');
 CC=bwconncomp(holes,4);
 originalCount=CC.NumObjects;
 whole=bwconncomp(merged,8);
 CC.PixelIdxList=[CC.PixelIdxList whole.PixelIdxList];
 CC.NumObjects=numel(CC.PixelIdxList);
 for k=1:CC.NumObjects
  ids=CC.PixelIdxList{k}; area=numel(ids);
  if area<max(12,.0002*h*w) || area>.6*h*w, continue; end
  candidate=false(h,w); candidate(ids)=true;
  % Kembalikan batas kontur tipis, bukan seluruh pita closing.
  if k>originalCount && any(anchor(:))
   % Penggabungan harus mempertahankan objek awal, bukan berpindah ke latar.
   if nnz(candidate & anchor)<.8*nnz(anchor) || area>6*nnz(anchor), continue; end
  end
  candidate=imdilate(candidate,strel('disk',1,0));
  [yy,xx]=ind2sub([h w],ids);
  if ~isempty(seed)
   x=round(seed(1)); y=round(seed(2));
   if x<1 || x>w || y<1 || y>h || ~candidate(y,x), continue; end
   score=sqrt(area/(h*w))-.01*r; % Utamakan kontur utuh yang memuat titik.
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




