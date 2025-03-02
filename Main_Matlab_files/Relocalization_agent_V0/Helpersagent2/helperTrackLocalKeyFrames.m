function [newRefKeyFrameId, localKeyFrameIds, currPose, mapPointIdx, featureIdx] = ...
    helperTrackLocalKeyFrames(mapPoints, vSetKeyFrames, mapPointIdx, ...
    featureIdx, currPose, currFeatures, currPoints, intrinsics, scaleFactor, numLevels, refKeyFrameId)
%helperTrackLocalKeyFrames Refine camera pose by tracking the local map
%
%   This is an example helper function that is subject to change or removal 
%   in future releases.
%
%   Inputs
%   ------
%   mapPoints         - A worldpointset object storing map points
%   vSetKeyFrames     - An imageviewset storing key frames
%   mapPointIdx       - Indices of map points observed in the current frame
%   featureIdx        - Indices of features in the current frame 
%                       corresponding to map points denoted by mapPointsIndices                      
%   currPose          - Current camera pose
%   currFeatures      - ORB Features in the current frame 
%   currPoints        - Feature points in the current frame
%   intrinsics        - Camera intrinsics 
%   scaleFactor       - Scale factor of features
%   numLevels         - number of levels in feature extraction
%   
%   Outputs
%   -------
%   newRefKeyFrameId     - ViewId of the reference key frame
%   localKeyFrameIds  - ViewIds of the local key frames 
%   currPose          - Refined camera pose of the current frame
%   mapPointIdx       - Indices of map points observed in the current frame
%   featureIdx        - Indices of features in the current frame corresponding
%                       to mapPointIdx   

%   Copyright 2021-2022 The MathWorks, Inc.

persistent allFeatures

if isempty(allFeatures)
    allFeatures  = getFeatures(mapPoints, vSetKeyFrames.Views, (1:mapPoints.Count)');
end

[~, localPointsIndices, localKeyFrameIds] = ...
    updateRefKeyFrameAndLocalPoints(mapPoints, vSetKeyFrames, mapPointIdx);

% Project the map into the frame and search for more map point correspondences
newMapPointIdx = setdiff(localPointsIndices, mapPointIdx, 'stable');
localFeatures = allFeatures(newMapPointIdx, :);

[projectedPoints, inlierIndex, predictedScales] = removeOutlierMapPoints(mapPoints, ...
    currPose, intrinsics, newMapPointIdx, scaleFactor, numLevels);

newMapPointIdx = newMapPointIdx(inlierIndex);
localFeatures  = localFeatures(inlierIndex,:);

unmatchedfeatureIdx = setdiff(cast((1:size( currFeatures.Features, 1)).', 'uint32'), ...
    featureIdx,'stable');
unmatchedFeatures   = currFeatures.Features(unmatchedfeatureIdx, :);
unmatchedValidPoints= currPoints(unmatchedfeatureIdx);

% Search radius depends on scale and view direction
searchRadius    = 4*ones(size(localFeatures, 1), 1);
searchRadius    = searchRadius.*predictedScales;

indexPairs = matchFeaturesInRadius(binaryFeatures(localFeatures),...
    binaryFeatures(unmatchedFeatures), unmatchedValidPoints, projectedPoints, ...
    searchRadius, 'MatchThreshold', 40, 'MaxRatio', 0.9, 'Unique', true);

if ~isempty(indexPairs)
    % If match were found
    % Filter by scales
    isGoodScale = currPoints.Scale(indexPairs(:, 2)) >= ...
        max(1, predictedScales(indexPairs(:, 1))/scaleFactor) & ...
        currPoints.Scale(indexPairs(:, 2)) <= predictedScales(indexPairs(:, 1));
    indexPairs  = indexPairs(isGoodScale, :);
    
    % Refine camera pose with more 3D-to-2D correspondences
    mapPointIdx   = [newMapPointIdx(indexPairs(:,1)); mapPointIdx];
    featureIdx     = [unmatchedfeatureIdx(indexPairs(:,2)); featureIdx];
    matchedMapPoints   = mapPoints.WorldPoints(mapPointIdx,:);
    matchedImagePoints = currPoints.Location(featureIdx,:);
    
    % Refine camera pose only
    currPose = bundleAdjustmentMotion(matchedMapPoints, matchedImagePoints, ...
        currPose, intrinsics, 'PointsUndistorted', true, ...
        'AbsoluteTolerance', 1e-7, 'RelativeTolerance', 1e-16,'MaxIteration', 20);

    % Update the reference key frame
    newRefKeyFrameId = updateRefKeyFrameAndLocalPoints(mapPoints, vSetKeyFrames, mapPointIdx);

else

    % If no match have been found, the reference keyframe does not change
    newRefKeyFrameId = refKeyFrameId;
    
end


end

function [refKeyFrameId, localPointsIndices, localKeyFrameIds] = ...
    updateRefKeyFrameAndLocalPoints(mapPoints, vSetKeyFrames, pointIndices)

% Get key frames K1 that observe map points in the current key frame
viewIds = findViewsOfWorldPoint(mapPoints, pointIndices);
K1IDs = vertcat(viewIds{:});

% The reference key frame has the most covisible map points
refKeyFrameId = mode(K1IDs);

if nargout > 1
    % Retrieve key frames K2 that are connected to K1
    K1IDs = unique(K1IDs);
    localKeyFrameIds = K1IDs;

    for i = 1:numel(K1IDs)
        views = connectedViews(vSetKeyFrames, K1IDs(i));
        K2IDs = setdiff(views.ViewId, localKeyFrameIds);
        localKeyFrameIds = [localKeyFrameIds; K2IDs]; %#ok<AGROW>
    end

    pointIdx = findWorldPointsInView(mapPoints, localKeyFrameIds);
    localPointsIndices = sort(vertcat(pointIdx{:}));
end
end

function features = getFeatures(mapPoints, views, mapPointIdx)

% Efficiently retrieve features and image points corresponding to map points
% denoted by mapPointIdx
allIndices = zeros(1, numel(mapPointIdx));

% ViewId and offset pair
count = []; % (ViewId, NumFeatures)
viewsFeatures = views.Features;
majorViewIds  = mapPoints.RepresentativeViewId;
majorFeatureindices = mapPoints.RepresentativeFeatureIndex;

for i = 1:numel(mapPointIdx)
    index3d  = mapPointIdx(i);
    
    viewId   = double(majorViewIds(index3d));
    
    if isempty(count)
        count = [viewId, size(viewsFeatures{viewId},1)];
    elseif ~any(count(:,1) == viewId)
        count = [count; viewId, size(viewsFeatures{viewId},1)];
    end
    
    idx = find(count(:,1)==viewId);
    
    if idx > 1
        offset = sum(count(1:idx-1,2));
    else
        offset = 0;
    end
    allIndices(i) = majorFeatureindices(index3d) + offset;
end

uIds = count(:,1);

% Concatenating features and indexing once is faster than accessing via a for loop
allFeatures = vertcat(viewsFeatures{uIds});
features    = allFeatures(allIndices, :);
end

function [projectedPoints, inliers, predictedScales] = removeOutlierMapPoints(...
    mapPoints, pose, intrinsics, localPointsIndices, scaleFactor, ...
    numLevels)

% 1) Points within the image bounds
xyzPoints = mapPoints.WorldPoints(localPointsIndices, :);
[projectedPoints, isInImage] = world2img(xyzPoints, pose2extr(pose), intrinsics);

% 2) Parallax less than 60 degrees
cameraToPoints   = xyzPoints - pose.Translation;
viewDirection    = mapPoints.ViewingDirection(localPointsIndices, :);
validByView      = sum(viewDirection.*cameraToPoints, 2) > ...
    cosd(60)*(vecnorm(cameraToPoints, 2, 2));

% 3) Distance from map point to camera center is in the range of scale
% invariant depth
minDist          = mapPoints.DistanceLimits(localPointsIndices, 1);
maxDist          = mapPoints.DistanceLimits(localPointsIndices, 2);
dist             = vecnorm(xyzPoints - pose.Translation, 2, 2);

validByDistance  = dist > minDist & dist < maxDist;

inliers          = isInImage & validByView & validByDistance;

% Predicted scales
level= ceil(log(maxDist ./ dist)./log(scaleFactor));
level(level<0)   = 0;
level(level>=numLevels-1) = numLevels-1;
predictedScales  = scaleFactor.^level;

% View angles
predictedScales  = predictedScales(inliers);
projectedPoints = projectedPoints(inliers, :);
end
