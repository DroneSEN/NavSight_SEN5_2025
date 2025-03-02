function [gDir,scale,isIMUInit] = helperAlignIMUCamera(camPoses,data,imuParams,keyFrameToFrame,currKeyFrameId)

    slSize=20;
    cellIdx=1;

    % Extract the IMU data between key frames.
    for kfIdx=(currKeyFrameId-slSize):(currKeyFrameId-1)
      imuInitMes = helperExtractIMUMeasurements(data, keyFrameToFrame(kfIdx), keyFrameToFrame(kfIdx+1));
      gyroCell{cellIdx} = imuInitMes.gyro; 
      accelCell{cellIdx} = imuInitMes.accel;
      cellIdx=cellIdx+1;
    end

    % Extract the camera poses.
    camPoses = camPoses.AbsolutePose((currKeyFrameId-slSize):(currKeyFrameId));

    [gDir,scale,info] = estimateGravityRotationAndPoseScale(camPoses,gyroCell,accelCell, ...
                SensorTransform=data.camToIMUTransform,IMUParameters=imuParams);
    isIMUInit = info.IsSolutionUsable; % Did the optimization converge?

end