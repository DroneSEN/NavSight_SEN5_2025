function potentialLoopCandidates = helperFindPotentialLC(vSetKeyFrames)      
        
        allPoses = poses(vSetKeyFrames).AbsolutePose;
        currPose = allPoses(end);

        dist=[];
        outWindow=10;

        for i=1:length(allPoses)-outWindow
            e=abs(allPoses(i).Translation - currPose.Translation);
            dist=[dist;e];
        end

        dist=mean(dist,2);
        potentialLoopCandidates=find(dist<0.1);

  end