%%% Simple video annotation tool
%%% Orson Lin, Richard Fedora, Murat Ambarkutuk
%%% 04/30/2016
%%% Virginia Tech
%% Initialization
clear all; close all; clc;
%% Variables and parameters
params.isAnnotated = true;
params.isTrained = true;
params.datasetLocation = '../data/DARPA_VIVID/eg_test01/egtest01/';
params.fileName = '';
params.modelLocation = '';
params.modelFileName = 'egtest01_model.mat';
params.annotationLocation = '';
params.annotationFileName = 'egtest01_annotation.mat';
params.filePrefix = 'frame';
params.isVideo = false;
params.annotationToolLocation = '../annotator';
params.trainingSkip = 50;
%% Create Path
addpath(genpath(params.annotationToolLocation));

%% Training Routine
% Check if the annotation is completed for the dataset
if params.isAnnotated == true;
    % Check if training is completed
    if params.isTrained == true
        load([params.modelLocation, params.modelFileName], 'mdl');
    else
        load([params.annotationLocation, params.annotationFileName], 'annotation');
        featureSpace.features = [];
        featureSpace.id = [];
        nFrames = numel(annotation.frame);
        for i=1:nFrames
            objectsMarked = numel(annotation.frame(i).targetIndividual);
            for j=1:objectsMarked
                featureSize = numel(annotation.frame(i).targetIndividual(j).features);
                missing = 1540 - featureSize;
                features = padarray(annotation.frame(i).targetIndividual(j).features, [0 missing], 'post');
                featureSpace.features = [featureSpace.features; features];
                annotation.frame(i).targetIndividual(j).id;
                featureSpace.id = [featureSpace.id; annotation.frame(i).targetIndividual(j).id];
            end
        end

        mdl = fitcknn(featureSpace.features, featureSpace.id,'NumNeighbors',2,...
            'NSMethod','exhaustive','Distance','minkowski',...
            'Standardize',1);
        save([params.modelLocation, params.modelFileName], 'mdl');
    end
% Start annotation routine to create the training model    
elseif params.isAnnotated == false
    if params.isVideo==true
        vidObj = VideoReader([params.dataSetLocation, params.fileName]);
        frameNum = 1;
        while hasFrame(vidObj)
            info = sprintf('Frame Number = %d', num2str(frameNum));
            disp(info);
            % Obtain the frame
            frame = readFrame(vidObj);
            % Extract HoG features for the frame
            % Create a new empty frame with the same size of the input frame
            annotation.frame(frameNum) = annotator(frame);
            save(params.modelLocation, 'annotation');
            frameNum = frameNum + 1;        
        end
    else
        imageNames = dir(fullfile(params.datasetLocation,'*.jpg'));
        imageNames = {imageNames.name}';
        % Delete ".", ".." and the video file from the list
        frameNumber = numel(imageNames);
        k = 1;
        for frameNum=1:params.trainingSkip:frameNumber
            % Obtain the frame
            frame = imread([params.datasetLocation,imageNames{frameNum}]);
            % Extract features for the frame given the bounding boxes
            % provided by the user
            % Concatinate the response
            annotation.frame(k) = annotator(frame);
            save([params.modelLocation, params.annoationFileName], 'annotation'); 
            k = k + 1;
        end
    end
    %%
    params.isAnnotated == true;
    featureSpace.features = [];
    featureSpace.id = [];
    nFrames = numel(annotation.frame);
    for i=1:nFrames
        objectsMarked = numel(annotation.frame(i).targetIndividual);
        for j=1:objectsMarked
            featureSize = numel(annotation.frame(i).targetIndividual(j).features);
            missing = 1540 - featureSize;
            features = padarray(annotation.frame(i).targetIndividual(j).features, [0 missing], 'post');
            featureSpace.features = [featureSpace.features; features];
            annotation.frame(i).targetIndividual(j).id;
            featureSpace.id = [featureSpace.id; annotation.frame(i).targetIndividual(j).id];
        end
    end
    %%

    mdl = fitcknn(featureSpace.features, featureSpace.id,'NumNeighbors', 60,...
        'NSMethod','exhaustive','Distance','minkowski',...
        'Standardize',1);
    save([params.modelLocation, params.modelFileName], 'mdl');
    params.isTrained = true;
end
%% Main Routine
%% Motion Compensation (Orson Lin)
%folder containing data (a sequence of jpg images)
dirname = '../data/egtest';
%dirname = '../data/simpse2';
%find the images, initialize some variables
imageNames = dir(fullfile(params.datasetLocation,'*.jpg'));
imageNames = {imageNames.name}';
nframes = numel(imageNames);
% nframes=30;
startFrame = 1;

margin.X=20;
margin.Y=30;
current_frame=[];
previous_frame=[];

%set parameters for grid devider 
gs.x=16;
gs.y=16;
thresh=4;
percent=98;
grid_sifting_time=4;

for i=startFrame:nframes
    img = imread([params.datasetLocation,imageNames{i}]);
    if (ndims(img) == 3)
        img = rgb2gray(img);
    end  
    img = double(img) / 255;
    %% inialization
    current_frame=img;
    if i==1
        [h, w]=size(img);
        dst= [1 1; 1 h; w h; w 1]';
        yt1=margin.Y+1;
        yt2=h-margin.Y;
        xt1=margin.X+1;
        xt2=w-margin.Y;
        templateBox = [xt1 xt1 xt2 xt2 xt1; yt1 yt2 yt2 yt1 yt1];
    end
    
    if ~isempty(previous_frame)
        %Show image pair
        figure(1)
        subplot(1,2,2)
        imshow(current_frame);
        title('current frame');
        subplot(1,2,1)
        imshow(previous_frame);
        title('previous frame');
        killed_his=[];
        %% build a mask defining the extent of the template
        template = previous_frame;
        mask     = NaN(size(template));
        mask2    = NaN(size(template));
        mask_in_loop   = NaN(size(template));
        mo_mask   = NaN(size(template));
        %  selected area is decided by margin
        mask(yt1:yt2, xt1:xt2) = 1;        
        %% divider comes into play. This part has some redundancy with tracking initialization
        %  selected area is decided by margin
        select_A= previous_frame(yt1:yt2, xt1:xt2); 
        
        [Gx,Gy]=gradient(select_A);
        select_A_grad=sqrt(Gx.^2+Gy.^2);
        % Sift out the grid that contain "gradient" information
        [sub_mask, ind,uti]= divider(select_A_grad,gs,thresh);
        mask2(yt1:yt2, xt1:xt2)= sub_mask; 
        % mask visualization 
        figure(67);
        subplot(1,2,1)
        imshow(mask.*current_frame);
        subplot(1,2,2)
        imshow(mask2.*current_frame); 
        p=[0,0,0,0,0,0];
        %% KLT
        mask_converted2  = mask_converter(mask2);
        for i2=1:grid_sifting_time
            % Get the inital guess from KLT. If sensor data is available,
            % this part can be a lot faster.
            tic;
            [affineLKContext, row, col, value]=InitAffineLKTracker(previous_frame, mask2);
            p=KLT_tracking(current_frame,value,row,col,affineLKContext,p,0,15);
            ftime = toc;
            %% calculate the covariance of each grid
            M = [ 1+p(1) p(3) p(5); p(2) 1+p(4) p(6); 0 0 1];
            % Warp the image with current estimated Affine parameters 
            warped_current = warp_a_v(current_frame, p, dst);
            error_square=(current_frame(yt1:yt2, xt1:xt2)-warped_current(yt1:yt2, xt1:xt2)).^2;
            % A lot of calculations in the following fucntion are already done in "divider". Can be
            % optimized
            [mask_updated,ind_updated,killed]=divider2(error_square,gs,percent,ind,killed_his);
            killed_his=[killed_his;killed];
            mask_in_loop(yt1:yt2, xt1:xt2)= mask_updated;
            %% mask visualization
            figure(90);
             imshow(mask_in_loop.*current_frame);
            %imshow(mask_in_loop);
            title('Current Mask');
            mask_converted1  = mask_converter(mask_in_loop);
            mask_converted2=mask_converted1+mask_converted2;
            figure(85);
            imagesc(mask_converted2);
            title('Mask update history');
            %% mask update
            mask2=mask_in_loop;
            ind=ind_updated;
            %% Visualization of grid refinement 
            currentBox = M * [templateBox; ones(1,5)];
            currentBox = currentBox(1:2,:);
            overlap=warped_current*.5+previous_frame*.5;
            hold off;
            figure(99);
            imagesc(overlap);
            hold on;
            plot(currentBox(1,:), currentBox(2,:), 'g', 'linewidth', 2);
            drawnow;
        end
        %Show the grids that might contain object 
        [mask_constructed] = mask_constructor(killed_his,uti,gs);
        mo_mask(yt1:yt2, xt1:xt2)=mask_constructed;
        
        figure(91);
        imshow(mo_mask.*current_frame);
        
        figure(92);
        imshow(mo_mask)
        mo_mask(isnan(mo_mask))=0;
        st = regionprops(logical(mo_mask), 'BoundingBox' );
        hold on 
        for k = 1 : length(st)
            thisBB = st(k).BoundingBox;
            rectangle('Position', [thisBB(1),thisBB(2),thisBB(3),thisBB(4)],...
                'EdgeColor','r','LineWidth',2 )
        end
        
%%      Murat Ambarkutuk
% Detection and Classification Routine (Murat Ambarkutuk)
% TODO: Anaylze the grids for possible objects
% TODO: Background differencing for the static objects (using homography)
% TODO: 
        for k = 1 : length(st)
            thisBB = int16(st(k).BoundingBox)
            rectangle('Position', [thisBB(1),thisBB(2),thisBB(3),thisBB(4)],...
                'EdgeColor','r','LineWidth',2 );
            roi = current_frame(thisBB(2):thisBB(2)+thisBB(4), thisBB(1):thisBB(1)+thisBB(3), :);
            target(k).RGB = imresize(roi, [50, 50]);
            % Feature representation
            [target(k).features, target(k).hogVisualization] = extractHOGFeatures(target(k).RGB);
            disp('hog');
            size(target(k).features) 
            surfpoints = detectSURFFeatures(target(k).RGB);
            surfpoints = surfpoints.selectStrongest(10);
            [f1, ~] = extractFeatures(target(k).RGB, surfpoints);
            target(k).features = [target(k).features, f1(:)'];
            missing = 1540 - numel(target(k).features);
            target(k).features = padarray(target(k).features, [0 missing], 'post');
            disp('padded');
            size(target(k).features)
            [l, s] = detect_and_classify(mdl, target(k).features)
            figure(666); imshow(roi);
        end

       
%%      Richard Fedora
        
        %%  main Visualization
        currentBox = M * [templateBox; ones(1,5)];
        currentBox = currentBox(1:2,:);
        overlap=warped_current*.5+previous_frame*.5;
        hold off;
        figure(99);
        imagesc(overlap);  
        hold on;
        plot(currentBox(1,:), currentBox(2,:), 'g', 'linewidth', 2);
        drawnow;
    end
    fprintf('ping_passed\n');
    previous_frame=current_frame; 
 
end