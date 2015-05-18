%{
%% Test
negCat = {2:5,[1,3:5],[1,2,4,5],[1:3,5],1:4,7:12,[6,8:12],...
  [6,7,9:12],[6:8,10:12],[6:9,11,12],[6:10,12],6:11};
[rf,out]=MakeSimpleRF(9,0:5:175,[6,6]);
for i = 1:12
  n = 1;
  result(i).list = {};
  for j = 1:length(ethz(i).files)
    out = RunEthzImage(ethz, i, i, j, rf, bpnet(i).net);
    list = MaxRect(out, ethz(i).sampleSize/4);
    list(:,1:2) = (list(:,1:2) - 1) * 6 + 1;
    oldSize = size(ethz(i).files(j).image);
    newSize = ethz(i).files(j).imageSize;
    for k = 1:size(list,1)
      rect = [list(k,1),list(k,2),list(k,1)+ethz(i).sampleSize(1),...
        list(k,2)+ethz(i).sampleSize(2)];
      rect([1,3]) = rect([1,3])/newSize(1)*oldSize(2);
      rect([2,4]) = rect([2,4])/newSize(2)*oldSize(1);
      list(k,4) = RectOverlap(rect, ethz(i).files(j).groundtruth);
      fprintf('Cat %d, file %d, rect %d, value = %f, overlap = %f\n', i, j, k, list(k,3), list(k,4));
    end
    result(i).list{n} = list;
    save('result','result');
    n = n + 1;
  end
  for k = negCat{i}
    for j = 1:length(ethz(k).files)
      out = RunEthzImage(ethz, i, k, j, rf, bpnet(i).net);
      list = MaxRect(out, ethz(i).sampleSize);
      for n = 1:size(list,1)
        fprintf('Cat %d, neg, value = %f\n', i, list(n,3));
      end
      result(i).list{n} = list;
      save('result.mat','result');
      n = n + 1;
    end
  end
end
%}
%% BP training
negCat = {2:5,[1,3:5],[1,2,4,5],[1:3,5],1:4,7:12,[6,8:12],...
  [6,7,9:12],[6:8,10:12],[6:9,11,12],[6:10,12],6:11};
[rf,out]=MakeSimpleRF(9,0:5:175,[6,6]);
pos = 0.99;
neg = 0.01;
for i = 1:12
  fprintf('Train cat %d: ', i);
  net = bpnet(i).net;
  idx = randi(size(ethz(i).posSample,2),1,10);
  in = ethz(i).posSample(:,idx);
  out = ones(1,10) * pos;
  for j = randi(length(ethz(i).files),1,10)
    f = ethz(i).files(j);
    img = imresize(f.image, [f.imageSize(2), f.imageSize(1)]);
    [temp,ori,ridge] = SimpleCell(img, rf);
    posRect = f.posSampleRect;
    posRect(:,[1,3]) = posRect(:,[1,3]) + randi(10) - 5;
    posRect(:,[2,4]) = posRect(:,[2,4]) + randi(10) - 5;
    c =SomComplexCell(ethz(i).complex, ridge, ori, ethz(i).sampleSize, posRect, 0.8, 2);
    [v,m] = SomV4Cell(ethz(i).v4som, f.v4data, ethz(i).sampleSize, posRect, 1);
    in = cat(2, in, [c;v]);
    out = cat(2, out, pos*ones(1,size(c,2)));
  end
  for j = negCat{i}
    k = randi(length(ethz(j).files));
    f = ethz(j).files(k);
    [temp,data] = RunEthzImage(ethz, i, j, k, rf, bpnet(i).net);
    in = cat(2, in, data);
    out = cat(2, out, neg*ones(1,size(data,2)));
  end
  [net,out] = BPnetTrain(net, in ,out, 0.0007);
  bpnet(i).net = net;
end
save('bpnet', 'bpnet');
%}
%{
%% BPnet sample
for i = 1:12
  ethz(i).posSample = [];
  for j = 1:length(ethz(i).v4sample)
    [c,m] = SomComplexCell(ethz(i).complex, ethz(i).sampleRidge(:,:,j), ...
      ethz(i).sampleOri(:,:,j), ethz(i).sampleSize, [0,0,ethz(i).sampleSize], ...
      0.8, 2);
    [v,m] = SomV4Cell(ethz(i).v4som, ethz(i).v4sample{j}, ...
      ethz(i).sampleSize, [0,0,ethz(i).sampleSize], 1);
    ethz(i).posSample = cat(2, ethz(i).posSample, [c;v]);
  end
  ethz(i).bpnet = {rand(32,129)-0.5,rand(1,33)-0.5};
end
%}
%{
%% Som Training
for i = 1:length(ethz)
  %[complex,v4som] = SomModel('init', ethz(i).sampleSize);
  %ethz(i).complex = complex;
  %ethz(i).v4som = v4som;
  ethz(i).complex = SomModel('learn-complex', ethz(i).complex, ethz(i).sampleRidge, ethz(i).sampleOri);
  ethz(i).v4som = SomModel('learn-v4', ethz(i).v4som, ethz(i).v4sample);
end
%}
%{
%% Resize images and samples
[rf,out]=MakeSimpleRF(9,0:5:175,[6,6]);
for i = 1:length(ethz)
  n = 0;
  ethz(i).sample = {};
  ethz(i).sampleRidge = [];
  ethz(i).sampleOri = [];
  ethz(i).v4sample = {};
  for j = 1:length(ethz(i).files)
    fprintf('%s: %s\n', ethz(i).name, ethz(i).files(j).name);
    img = ethz(i).files(j).image;
    h = size(img,1);
    w = size(img,2);
    gt = ethz(i).files(j).groundtruth;
    rx = (ethz(i).sampleSize(1)-20) * ((gt(:,3)-gt(:,1)).^(-1));
    ry = (ethz(i).sampleSize(2)-20) * ((gt(:,4)-gt(:,2)).^(-1));
    gt = round(gt .* [rx,ry,rx,ry] + repmat([-10,-10,10,10],size(gt,1),1));
    imr = round([ry * h, rx * w]);
    gt(gt<1) = 1;
    for k = 1:size(gt,1)
      gt(k,3) = gt(k,1) + ethz(i).sampleSize(1) - 1;
      gt(k,4) = gt(k,2) + ethz(i).sampleSize(2) - 1;
      padx = 0;
      pady = 0;
      if gt(k,3) > imr(k,2)
        padx = gt(k,3) - imr(k,2);
        gt(k,3) = imr(k,2);
      end
      if gt(k,4) > imr(k,1)
        pady = gt(k,4) - imr(k,1);
        gt(k,4) = imr(k,1);
      end
      img2 = imresize(img,imr(k,:));
      [out,ori,ridge]=SimpleCell(img2,rf);
      [map,graph,v4out]=FindV4(ridge,ori,0.8,14,10,4);
      v4sample = v4out(v4out(:,4)<=gt(k,3)&v4out(:,4)>=gt(k,1)&v4out(:,5)<=gt(k,4)&v4out(:,5)>=gt(k,2),[4:7,3]);
      v4sample(:,3:4) = v4sample(:,3:4)/pi*180;
      v4sample(:,1) = v4sample(:,1) - gt(k,1);
      v4sample(:,2) = v4sample(:,2) - gt(k,2);
      xidx = gt(k,1):gt(k,3);
      yidx = gt(k,2):gt(k,4);
      n = n + 1;
      if padx > 0 || pady > 0
        fprintf('%d:%s:%s: size: %d,%d; pad: %d,%d\n', n, ethz(i).name, ethz(i).files(j).name, gt(k,3)-gt(k,1)+1,gt(k,4)-gt(k,2)+1, padx, pady);
      end
      ethz(i).sample{n} = padarray(img2(yidx,xidx,:),[pady,padx],0,'post'); 
      ethz(i).sampleRidge = cat(3, ethz(i).sampleRidge, padarray(ridge(yidx,xidx),[pady,padx],0,'post'));
      ethz(i).sampleOri = cat(3, ethz(i).sampleOri, padarray(ori(yidx,xidx),[pady,padx],0,'post'));
      ethz(i).v4sample{n} = v4sample;
    end
    imr = round(mean(imr,1));
    ethz(i).files(j).imageSize = [imr(2),imr(1)];
    if size(gt,1) > 1
      img2 = imresize(img, imr);
      [out,ori,ridge]=SimpleCell(img2,rf);
      [map,graph,v4out]=FindV4(ridge,ori,0.8,14,10,4);
    end
    ethz(i).files(j).v4data = v4out;
    ethz(i).files(j).v4linemap = map;
    ethz(i).files(j).posSampleRect = gt;
  end
end
%}
%{
%% Read dataset files to MAT
%cats = {'apple','bottle','giraffe','hat','mug','starfish','swan'};
%fdr = '~/Downloads/dataset/extended_ethz_shapes/';
cats = {'Applelogos','Bottles','Giraffes','Mugs','Swans'};
fdr = '~/Downloads/ETHZShapeClasses-V1.2/';
for i = 1:length(cats)
  ethz2(i).name = cats{i};
  files = dir([fdr,cats{i},'/*.jpg']);
  ethz2(i).ratio = 0;
  for j = 1:length(files)
    name = files(j).name;
    img = imread([fdr,cats{i},'/',name]);
    name = name(1:length(name)-4);
    ethz2(i).files(j).name = name;
    ethz2(i).files(j).image = img;
    temp = dir([fdr,cats{i},'/',name,'_*.groundtruth']);
    fp = fopen([fdr,cats{i},'/',temp(1).name]);
    gt = fscanf(fp, '%f', [4,Inf]);
    fclose(fp);
    ethz2(i).files(j).groundtruth = gt';
    ethz2(i).ratio = ethz2(i).ratio + mean((gt(3,:)-gt(1,:))./(gt(4,:)-gt(2,:)));
  end
  ethz2(i).ratio = ethz2(i).ratio / length(files);
end
%}