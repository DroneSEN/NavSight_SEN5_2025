function [isDetected, loopKeyFrameId] = helperCheckLoopClosureVI(encodedImages, idx)

distances = mean(abs(encodedImages(idx,:) - encodedImages(end,:)),2);

isDetected=false;
loopKeyFrameId=[];

for i=1:length(distances)
    if distances(i)<0.005
        isDetected=true;
        loopKeyFrameId=[loopKeyFrameId, idx(i)];
    end
end


end