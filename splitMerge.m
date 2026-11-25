function [L, S, info] = splitMerge(I, threshold, minSize)
% Split rekursif dan merge tetangga 4-connected berdasarkan simpangan baku.
arguments
 I
 threshold (1,1) double {mustBeNonnegative,mustBeLessThanOrEqual(threshold,1)} = .08
 minSize (1,1) double {mustBeInteger,mustBePositive} = 8
end
G=im2double(I); if size(G,3)==3, G=rgb2gray(G); end
[h,w]=size(G); L=zeros(h,w); count=0;
split(1,h,1,w);
initial=count; parent=1:count;
n=accumarray(L(:),1); sums=accumarray(L(:),G(:)); squares=accumarray(L(:),G(:).^2);
% Semua pasangan bertetangga, termasuk batas daun quadtree berbeda ukuran.
a=L(:,1:end-1); b=L(:,2:end); c=L(1:end-1,:); d=L(2:end,:);
pairs=unique(sort([a(:) b(:);c(:) d(:)],2),'rows');
pairs(pairs(:,1)==pairs(:,2),:)=[];
changed=true;
while changed
 changed=false;
 for k=1:size(pairs,1)
  a=root(pairs(k,1)); b=root(pairs(k,2)); if a==b, continue; end
  N=n(a)+n(b); T=sums(a)+sums(b); Q=squares(a)+squares(b);
  % Statistik gabungan berbobot luas, bukan rata-rata standar deviasi daun.
  if max(0,Q/N-(T/N)^2)<=threshold^2+1e-12
   parent(b)=a; n(a)=N; sums(a)=T; squares(a)=Q; changed=true;
  end
 end
end
map=zeros(count,1); for k=1:count, map(k)=root(k); end
[~,~,ids]=unique(map); L=reshape(ids(L),h,w);
S=zeros(size(I)); D=im2double(I);
for channel=1:size(I,3)
 plane=D(:,:,channel); means=accumarray(L(:),plane(:),[],@mean);
 S(:,:,channel)=reshape(means(L),h,w);
end
info=struct('leaves',initial,'regions',max(L(:)),'threshold',threshold,'minSize',minSize);
 function split(r1,r2,c1,c2)
  block=G(r1:r2,c1:c2);
  if std(block(:),1)<=threshold+1e-12 || min(size(block))<=minSize
   count=count+1; L(r1:r2,c1:c2)=count; return
  end
  rm=floor((r1+r2)/2); cm=floor((c1+c2)/2);
  split(r1,rm,c1,cm); split(r1,rm,cm+1,c2);
  split(rm+1,r2,c1,cm); split(rm+1,r2,cm+1,c2);
 end
 function a=root(a)
  while parent(a)~=a
   parent(a)=parent(parent(a)); a=parent(a);
  end
 end
end

