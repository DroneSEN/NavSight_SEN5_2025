%helperTrackRefKeyFrame Estimate the camera pose by tracking the last key frame
%   [currPose, mapPointIdx, featureIdx] = helperTrackRefKeyFrame(mapPoints, 
%   views, currFeatures, currPoints, refKeyFrameId, intrinsics) estimates
%   the camera pose of the current frame by matching features with the
%   reference key frame.
%
%   This is an example helper function that is subject to change or removal 
%   in future releases.
%
%   Inputs
%   ------
%   mapPoints         - A worldpointset objects storing map points
%   views             - View attributes of key frames
%   currFeatures      - Features in the current frame 
%   currPoints        - Feature points in the current frame                 
%   refKeyFrameId     - ViewId of the reference key frame 
%   intrinsics        - Camera intrinsics 
%   
%   Outputs
%   -------
%   currPose          - Estimated camera pose of the current frame
%   mapPointIdx       - Indices of map points observed in the current frame
%   featureIdx        - Indices of features corresponding to mapPointIdx

%   Copyright 2021-2022 The MathWorks, Inc.

function [currPose, mapPointIdx, featureIdx] = helperTrackRefKeyFrame(...
    mapPoints, views, currFeatures, currPoints, refKeyFrameId, intrinsics)

% Match features from the previous key frame with known world locations
[index3d, index2d]    = findWorldPointsInView(mapPoints, refKeyFrameId);
refKeyFrameFeatures  = views.Features{refKeyFrameId}(index2d,:);

indexPairs  = matchFeatures(currFeatures, binaryFeatures(refKeyFrameFeatures),...
    'Unique', true, 'MaxRatio', 0.9, 'MatchThreshold', 40);

% Estimate the camera pose
matchedImagePoints = currPoints.Location(indexPairs(:,1),:);
matchedWorldPoints = mapPoints.WorldPoints(index3d(indexPairs(:,2)), :);

matchedImagePoints = cast(matchedImagePoints, 'like', matchedWorldPoints);
warning('off','vision:ransac:maxTrialsReached');
[currPose, inlier, status] = estworldpose(...
    matchedImagePoints, matchedWorldPoints, intrinsics, ...
    'Confidence', 90, 'MaxReprojectionError', 10, 'MaxNumTrials', 1e4);

if status
    currPose=[];
    mapPointIdx=[];
    featureIdx=[];
    return
end

% Refine camera pose only
currPose = bundleAdjustmentMotion(matchedWorldPoints(inlier,:), ...
    matchedImagePoints(inlier,:), currPose, intrinsics, ...
    'PointsUndistorted', true, 'AbsoluteTolerance', 1e-7,...
    'RelativeTolerance', 1e-15, 'MaxIteration', 20);

% Search for more matches with the map points in the previous key frame
xyzPoints = mapPoints.WorldPoints(index3d,:);

[projectedPoints, isInImage] = world2img(xyzPoints, pose2extr(currPose), intrinsics);
projectedPoints = projectedPoints(isInImage, :);

searchRadius = 6;

indexPairs   = matchFeaturesInRadius(binaryFeatures(refKeyFrameFeatures(isInImage,:)), ...
    binaryFeatures(currFeatures.Features), currPoints, projectedPoints, searchRadius, ...
    'MatchThreshold', 40, 'MaxRatio', 0.9, 'Unique', true);

if size(indexPairs, 1) < 20
    currPose=[];
    mapPointIdx=[];
    featureIdx=[];
    return
end

% Obtain the index of matched map points and features
tempIdx      = find(isInImage); % Convert to linear index
mapPointIdx  = index3d(tempIdx(indexPairs(:,1)));
featureIdx   = indexPairs(:,2);

% Refine the camera pose again
matchedWorldPoints = mapPoints.WorldPoints(mapPointIdx, :);
matchedImagePoints = currPoints.Location(featureIdx, :);

currPose = bundleAdjustmentMotion(matchedWorldPoints, matchedImagePoints, ...
    currPose, intrinsics, 'PointsUndistorted', true, 'AbsoluteTolerance', 1e-7,...
    'RelativeTolerance', 1e-15, 'MaxIteration', 20);
end