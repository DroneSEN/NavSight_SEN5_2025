function [posesUpdated,xyzUpdated_1,xyzUpdated_2] = helperTransformToIMU(poses,xyz_1,xyz_2,gDir,poseScale)

    posesUpdated = poses;
    % Input gravity rotation transforms the gravity vector from local 
    % navigation reference frame to initial camera pose reference frame.
    % The inverse of this transforms the poses from camera reference frame 
    % to local navigation reference frame.
    Ai = gDir.A';
    for k = 1:length(poses.AbsolutePose)
        T = Ai*poses.AbsolutePose(k).A;
        T(1:3,4) = poseScale*T(1:3,4);
        posesUpdated.AbsolutePose(k) = rigidtform3d(T); 
    end
    xyzUpdated_1 = poseScale*gDir.transformPointsInverse(xyz_1);
    xyzUpdated_2 = poseScale*gDir.transformPointsInverse(xyz_2);

end