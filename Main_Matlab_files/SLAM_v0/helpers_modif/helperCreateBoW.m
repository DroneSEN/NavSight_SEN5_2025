imds = imageDatastore("./imgs/",'IncludeSubfolders',true,'LabelSource',...
    'foldernames');
extractor = @helperORBFeatureExtractorFunction;
% bag = bagOfFeatures(imds,'CustomExtractor',extractor,TreeProperties=[6,15],StrongestFeatures=1);
bag = bagOfFeatures(imds,'CustomExtractor',extractor,TreeProperties=[3,10],StrongestFeatures=1);


function [features, featureMetrics]= helperORBFeatureExtractorFunction(I)
% helperORBFeatureExtractorFunction Implements the ORB feature extraction 
% used in bagOfFeatures.
%
%   This is an example helper function that is subject to change or removal 
%   in future releases.

%   Copyright 2021 The MathWorks, Inc.

points = detectORBFeatures(I, 'ScaleFactor', 1.2, 'NumLevels', 8);

% Select a subset of features, uniformly distributed throughout the image
% points = selectUniform(points, numPoints, size(I));

% Extract features
features = extractFeatures(I, points, Method='ORB');

% Compute the Feature Metric. Use the variance of features as the metric
featureMetrics = points.Metric; 
% featureMetrics = var(single(features.Features),[],2);
end