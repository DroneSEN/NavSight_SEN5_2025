function [currPose, refKeyFrameId, mapPointIdx, featureIdx, ...
    localKeyFrameIds, status] = ...
    helperGlobalInitialization(mapPoints, vSetKeyFrames, ...
    currFeatures, currPoints, intrinsics, prevPose, localKeyFrameIds)
%helperGlobalInitialization Estimate camera pose by tracking the whole map
%
%   This is an example helper function that is subject to change or removal 
%   in future releases.
%
%   Inputs
%   ------
%   mapPoints         - A worldpointset object storing map points
%   vSetKeyFrames     - An imageviewset storing key frames
%   mapPointsIndices  - Indices of map points observed in the current frame                     
%   currFeatures      - ORB Features in the current frame 
%   currPoints        - Feature points in the current frame
%   intrinsics        - Camera intrinsics 
%   prevPose          - Camera pose of the previous frame
%   localKeyFrameIds  - ViewIds of local key frames
%   
%   Outputs
%   ------- 
%   currPose          - Refined camera pose of the current frame
%   refKeyFrameId     - ViewId of the reference key frame
%   mapPointIdx       - Indices of map points observed in the current frame
%   featureIdx        - Indices of features in the current frame corresponding
%                       to mapPointIdx
%   localKeyFrameIds  - ViewIds of local key frames
%   status            - Status of the relocalization process:
%                       (0 = Success, -1 Fail)

%   Copyright 2021-2022 The MathWorks, Inc.

isLastPoseKnown = nargin == 7;

% Features of all the 3-D points in the map
persistent allFeatures allPoints 

if isempty(allFeatures)
    localMapPointIdx = (1:mapPoints.Count)';
    [allFeatures, allPoints]  = getFeatures(mapPoints, vSetKeyFrames.Views, localMapPointIdx);
end

% By default, set the status flag to success
status = 0;

% If the last key frame pose is known, relocalizing by tracking map points
% observed by local key frames. Otherwise, track all the map points. 
if ~isLastPoseKnown
    localFeatures = allFeatures;
    indexPairs = matchFeatures(currFeatures, binaryFeatures(localFeatures), ...
        'Unique', true, 'MaxRatio', 0.9, 'MatchThreshold', 40);

    if ~isempty(indexPairs)

         % Orientation consistency check
        orientation1 = currPoints.Orientation(indexPairs(:,1));
        orientation2 = allPoints.Orientation(indexPairs(:,2));
        [N, ~, bin] = histcounts(abs(orientation1 - orientation2), 0:pi/30:2*pi);
        [~, ia] = maxk(N, 3); % Select the top 3 bins
        isConsistent = ismember(bin, ia);
    
        indexPairs = indexPairs(isConsistent, :);
    
        % Estimate the camera pose
        localMapPointIdx = indexPairs(:,2);
        
        matchedImagePoints = currPoints.Location(indexPairs(:,1),:);
        matchedWorldPoints = mapPoints.WorldPoints(localMapPointIdx, :);
    
        matchedImagePoints = cast(matchedImagePoints, 'like', matchedWorldPoints);
        [currPose, inlier] = estworldpose(...
            matchedImagePoints, matchedWorldPoints, intrinsics, ...
            'Confidence', 90, 'MaxReprojectionError', 10, 'MaxNumTrials', 1e5);
    
        % Refine camera pose only
        currPose = bundleAdjustmentMotion(matchedWorldPoints(inlier,:), ...
            matchedImagePoints(inlier,:), currPose, intrinsics, ...
            'PointsUndistorted', true, 'AbsoluteTolerance', 1e-7,...
            'RelativeTolerance', 1e-15, 'MaxIteration', 20);
    else
        % If the last position is not known and no match found in all the
        % map points, return an invalid position, triggering an error
        currPose = NaN;
        localMapPointIdx = [];
    end
else
    % If the last position is known
    localMapPointIdx = findWorldPointsInView(mapPoints, localKeyFrameIds);
    localMapPointIdx = unique(vertcat(localMapPointIdx{:}));
    localFeatures  = allFeatures(localMapPointIdx, :);
    currPose = prevPose;
end

if ~isa(currPose, 'rigidtform3d')
    % Return empty values
    currPose = rigidtform3d;
    refKeyFrameId = [];
    mapPointIdx = [];
    featureIdx = [];
    localKeyFrameIds = [];
    status = -1;
    return;
end

% Search for more matches with the map points 
xyzPoints = mapPoints.WorldPoints(localMapPointIdx, :);

[projectedPoints, isInImage] = world2img(xyzPoints, pose2extr(currPose), intrinsics);
projectedPoints = projectedPoints(isInImage, :);

searchRadius = 6;

indexPairs   = matchFeaturesInRadius(binaryFeatures(localFeatures(isInImage,:)), ...
    binaryFeatures(currFeatures.Features), currPoints, projectedPoints, searchRadius, ...
    'MatchThreshold', 40, 'MaxRatio', 0.9, 'Unique', true);

if ~isempty(indexPairs)
    
    % Obtain the index of matched map points and features
    tempIdx            = find(isInImage); % Convert to linear index
    mapPointIdx        = localMapPointIdx(tempIdx(indexPairs(:,1)));
    featureIdx         = indexPairs(:,2);
    
    % Refine the camera pose again
    matchedWorldPoints = mapPoints.WorldPoints(mapPointIdx, :);
    matchedImagePoints = currPoints.Location(featureIdx, :);
    
    currPose = bundleAdjustmentMotion(matchedWorldPoints, matchedImagePoints, ...
        currPose, intrinsics, 'PointsUndistorted', true, 'AbsoluteTolerance', 1e-7,...
        'RelativeTolerance', 1e-15);

    [refKeyFrameId, localKeyFrameIds] = ...
    updateRefKeyFrameAndLocalPoints(mapPoints, mapPointIdx);

else
    mapPointIdx = [];
    refKeyFrameId = 0;
    localKeyFrameIds = [];
    featureIdx = [];
    status = -1;
end

% Return
end

function [refKeyFrameId, localKeyFrameIds] = ...
    updateRefKeyFrameAndLocalPoints(mapPoints, pointIndices)

% Get key frames K1 that observe map points in the current key frame
viewIds = findViewsOfWorldPoint(mapPoints, pointIndices);
K1IDs = vertcat(viewIds{:});

% The reference key frame has the most covisible map points 
refKeyFrameId = mode(K1IDs);
localKeyFrameIds = unique(K1IDs);
end

function [features, validPoints] = getFeatures(mapPoints, views, mapPointIdx)

% Efficiently retrieve features and image points corresponding to map points
% denoted by mapPointIdx
allIndices = zeros(1, numel(mapPointIdx));

% ViewId and offset pair
count = []; % (ViewId, NumFeatures)
viewsFeatures = views.Features;
viewPoints    = views.Points;
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
allPoints   = vertcat(viewPoints{uIds});
validPoints = allPoints(allIndices);
end
