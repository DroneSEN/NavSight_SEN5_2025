function [rmse, ame] = helperGetAccuracy(viPoses,data,keyTimeStamps, gDir)

pred=[];
gt=[];
timeStamps=data.timeStamps;

gTruth = data.gTruth(:, 1:3);

gDirInv = se3(invert(gDir).A);
imuToCam = inv(data.camToIMUTransform);
gTruth = imuToCam.transform(gTruth);
gTruth = gDirInv.transform(gTruth);

for i=1:height(viPoses)
    poseVI=viPoses.AbsolutePose(i).Translation;
    pred=[pred;poseVI];
    viTimeStamp=keyTimeStamps(i);
    [~,idx] = min(abs(timeStamps.imageTimeStamps - viTimeStamp));
    poseGT=gTruth(idx,1:3);
    gt=[gt;poseGT];
end

rmse = sqrt(mean(sum((pred - gt).^2,2)));
ame = mean(sum(abs(pred - gt),2));

disp(["AME for trajectory (m): ",num2str(ame)])
disp(["RMSE for trajectory (m): ",num2str(rmse)])

end