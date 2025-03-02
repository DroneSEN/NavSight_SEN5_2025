function alignementPlot = helperDrawScaledandRotatedTraj(data,camPoses,scale,startFrameIdx,keyFrameToFrame)

    % Capture init pose from GT
    initT  = data.gTruth(startFrameIdx,1:3); % gTruth (1,2,3) <=> (x,y,z)
    
    % Adaptation pour le dataset en attendant les modifications
    initR  = quat2rotm(data.gTruth(startFrameIdx,4:7)); % gTruth (4..7)  <=> (quaternions)

    initTF = rigidtform3d(initR,initT);
               
    invInit=invert(initTF);
    invInit_T=invInit.Translation;
    invInit_R=invInit.R;
    
    p1 = data.camToIMUTransform.transform(vertcat(camPoses.AbsolutePose.Translation));
    p2 = scale*p1;

    g1 = data.gTruth(keyFrameToFrame,1:3);
    % g11 = invInit_R*g1'+ invInit_T';
    % g1 = g11';

    alignementPlot = pcplayer([-2,5], [-2,5], [-5,5], 'VerticalAxis', 'y', 'VerticalAxisDir', 'down');
    Axes  = alignementPlot.Axes;
    legend(Axes, 'Location',  'northeast', 'TextColor', [1 1 1], 'FontWeight', 'bold');
    hold(Axes, 'on');
    title(Axes,"Camera-IMU Alignment")
    plot3(Axes, p1(:,1), p1(:,2), p1(:,3), 'b', 'LineWidth', 2 , 'DisplayName', 'Estimated trajectory');
    plot3(Axes, p2(:,1), p2(:,2), p2(:,3), 'g', 'LineWidth', 2 , 'DisplayName', 'Estimated scaled trajectory');
    plot3(Axes, g1(:,1), g1(:,2), g1(:,3), 'r', 'LineWidth', 2 , 'DisplayName', 'Ground Truth');
    hold(Axes,"off")
    drawnow

end