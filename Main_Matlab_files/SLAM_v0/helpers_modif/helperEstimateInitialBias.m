function initBias = helperEstimateInitialBias(data,start,finish,imuParams)

    F = factorGraph();
    
    velId = generateNodeID(F,150);
    biasId = generateNodeID(F,150);
    poseId = generateNodeID(F,150);
    
    pose = [0 0 0 0 0 0 0];
    vel = [0 0 0];
    
    for i=start:finish-1
        imuMes = helperExtractIMUMeasurements(data, i, i+1);
    
        imuId = [poseId(i),velId(i),biasId(i), ...
                 poseId(i+1)  ,velId(i+1)  ,biasId(i+1)];
        fIMU = factorIMU(imuId,imuMes.gyro,imuMes.accel,imuParams,SensorTransform=data.camToIMUTransform);
        addFactor(F,fIMU);
    
        nodeState(F,poseId(i),pose);
        nodeState(F,velId(i),vel);
    
        fixNode(F,poseId(i));
        fixNode(F,velId(i));
    
        nodeState(F,poseId(i+1),pose);
        nodeState(F,velId(i+1),vel);
    
        fixNode(F,poseId(i+1));
        fixNode(F,velId(i+1));
    end
    
    optimize(F);
    
    poseValues=nodeState(F,nodeIDs(F,NodeType="POSE_SE3"));
    velValues=nodeState(F,nodeIDs(F,NodeType="VEL3"));
    biasValues=nodeState(F,nodeIDs(F,NodeType="IMU_BIAS"));
    
    initBias = biasValues(end,:);
end