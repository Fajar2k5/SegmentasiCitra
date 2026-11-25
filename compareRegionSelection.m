function compareRegionSelection()
out='results_region_comparison'; if ~isfolder(out), mkdir(out); end
files=dir('bsds500_test_8/*.jpg');
for k=1:8
 I=imread(fullfile(files(k).folder,files(k).name)); p=edgePreset(files(k).name);
 [E,M,S]=segmentEdges(I,char(p.Method),p.Threshold,p.Sigma,p.Radius);
 old=edgeInteriorMask(E,p.Radius,[]); before=I; before(repmat(~old,1,1,3))=0;
 [~,base]=fileparts(files(k).name);
 imwrite([I before S],fullfile(out,[base '.png']));
 fprintf('%s before=%d after=%d\n',base,nnz(old),nnz(M));
end
% Kontur dengan sekat internal harus dipilih sebagai satu objek.
E=false(100); E(20,20:80)=1; E(80,20:80)=1; E(20:80,20)=1; E(20:80,80)=1; E(20:80,50)=1;
M=edgeObjectMask(E,2,[]); assert(M(50,30)&&M(50,70));
M=edgeObjectMask(E,2,[30 50]); assert(M(50,30)&&M(50,70));
assert(~any(edgeObjectMask(false(100),2,[]),'all'));
fprintf('PASS: kontur bersekat, seed, citra tanpa tepi.\n');
end

