function [mapPointSet,pointToNode] = helperCullRecentMapPoints(mapPointSet, pointToNode, mapPointsIdx, newPointIdx)
outlierIdx    = setdiff(newPointIdx, mapPointsIdx);
if ~isempty(outlierIdx)
    mapPointSet   = removeWorldPoints(mapPointSet, outlierIdx);
    pointToNode(outlierIdx) = [];
end
end