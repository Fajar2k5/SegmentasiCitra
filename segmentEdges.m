function [E, mask, segmented] = segmentEdges(I, method, threshold, sigma, radius, seed)
% Operator manual; threshold relatif terhadap respons maksimum [0,1].
arguments
 I
 method char = 'Sobel'
 threshold (1,1) double {mustBeNonnegative,mustBeLessThanOrEqual(threshold,1)} = .15
 sigma (1,1) double {mustBePositive} = 1.4
 radius (1,1) double {mustBeInteger,mustBeNonnegative} = 4
 seed double = []
end
G = im2double(I); if size(G,3)==3, G=rgb2gray(G); end
% Gaussian manual menekan tekstur sebelum operator turunan.
if ~any(strcmpi(method,{'LoG','Canny'}))
 n=ceil(3*sigma); [x,y]=meshgrid(-n:n); K=exp(-(x.^2+y.^2)/(2*sigma^2));
 G=imfilter(G,K/sum(K(:)),'replicate','conv');
end
switch lower(method)
 case 'canny'
  E=edge(G,'Canny',threshold,sigma);
 otherwise
  switch lower(method)
   case 'sobel', K=[-1 0 1;-2 0 2;-1 0 1]; R=hypot(filter(K),filter(K'));
   case 'prewitt', K=[-1 0 1;-1 0 1;-1 0 1]; R=hypot(filter(K),filter(K'));
   case 'roberts', R=hypot(filter([1 0;0 -1]),filter([0 1;-1 0]));
   case 'laplace', R=abs(filter([0 1 0;1 -4 1;0 1 0]));
   case 'log'
    n=ceil(3*sigma); [x,y]=meshgrid(-n:n); q=x.^2+y.^2;
    K=(q-2*sigma^2).*exp(-q/(2*sigma^2))/sigma^6;
    K=K-mean(K(:)); % Hilangkan komponen DC agar citra konstan tidak bertepi.
    R=abs(filter(K));
   otherwise, error('Operator tidak dikenal: %s',method);
  end
  E=R>threshold*max(R(:)) & R>1e-12;
end
mask=edgeObjectMask(E,radius,seed);
segmented=I; segmented(repmat(~mask,1,1,size(I,3)))=0;
 function R=filter(K)
  % Padding replikasi mencegah bingkai palsu akibat zero padding.
  R=imfilter(G,K,'replicate','conv');
 end
end




