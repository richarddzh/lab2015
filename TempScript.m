%% Run detection.
for i=[4,5]
  runCat = i;
  result = [];
  for j=1:length(ethzv4(i).files)
    [r,jj]=FindV4ModelInImage(ethzv4(runCat).cluster,ethzv4(runCat).model,ethzv4(i).files(j));
    if i~=runCat && ~isempty(jj)
      jj(:,7) = 0;
    end
    if ~isempty(jj)
      jj = [repmat(i,size(jj,1),1),repmat(j,size(jj,1),1),jj];
    end
    result=[result;jj];
    fprintf('ok: %d, %d\n', i, j);
  end
  ethzv4(i).result = result;
end
allpos = [44,55,91,66,33];
[~,idx] = sort(result(:,8)/max(result(:,8))-result(:,7));
r = result(idx,:);
for i = 1:size(r,1)
  r(i,1) = sum(r(1:i,9)<=0.1)/255;
  r(i,2) = sum(r(1:i,9)>0.1)/allpos(runCat);
end
[~,idx] = unique(r(:,1));
idx2 = 1;
for i = 2:length(idx)
  idx2 = [idx2, idx(i)-1, idx(i)];
end
idx2 = [idx2, size(r,1)];
r = r(idx2,1:2);
close all
plot(r(:,1),r(:,2));
%
%% Find where can set empty label.
%{
for i = [1,2,4,5]
  n = length(ethzv4(i).model.label);
  ignoreAfter = zeros(n,n);
  for j = 1:length(ethzv4(i).sample.label)
    k = ethzv4(i).sample.label{j};
    k(1) = 0;
    k = [k,n+1];
    for p = 2:length(k)
      for q = (k(p-1)+1):(k(p)-1)
        ignoreAfter(q,k(p-1)+1) = 1;
      end
    end
  end
  ethzv4(i).model.ignoreAfter = ignoreAfter;
end
%}
%% Check label and cluster consistent.
%{
for i=[1,2,4,5]
 for j=1:length(ethzv4(i).sample.index)
  k=ethzv4(i).sample.index{j};
  for m=2:length(k)
   cl=ethzv4(i).sample.cluster{j}(m);
   la=ethzv4(i).sample.label{j}(m);
   if ~ismember(cl, ethzv4(i).model.label{la})
    fprintf('! warning: %d,%d,%d\n', i,j,m);
   end
  end
 end
end
%}
