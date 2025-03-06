function imuMesurements = helperExtractIMUMeasurements(data, startFrameIdx, currFrameIdx)
timeStamps = data.timeStamps;

startTimeStamp = timeStamps.imageTimeStamps(startFrameIdx);
currTimeStamp  = timeStamps.imageTimeStamps(currFrameIdx);

[~,startIMUIdx] = min(abs(timeStamps.imuTimeStamps - startTimeStamp));
[~,currIMUIdx]  = min(abs(timeStamps.imuTimeStamps - currTimeStamp));

imuMesurements.accel = data.accelReadings(startIMUIdx:(currIMUIdx-1),:);
imuMesurements.gyro  = data.gyroReadings(startIMUIdx:(currIMUIdx-1),:);

end