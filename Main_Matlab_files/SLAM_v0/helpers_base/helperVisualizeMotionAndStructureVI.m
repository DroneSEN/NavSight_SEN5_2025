classdef helperVisualizeMotionAndStructureVI < handle
%helperVisualizeMatchedFeatures show map points and camera trajectory
%
%   This is an example helper class that is subject to change or removal 
%   in future releases.

%   Copyright 2019-2022 The MathWorks, Inc.

    properties
        XLim = [-15 15]

        YLim = [-20 10]

        ZLim = [-5 20]
        
        Axes
    end
    
    properties (Access = private)
        MapPointsPlot
 
        EstimatedTrajectory
        
        OptimizedTrajectory

        CameraPlot
    end

    methods (Access = public)
        function obj = helperVisualizeMotionAndStructureVI(vSetKeyFrames, mapPoints, varargin)

            if nargin > 3
                obj.XLim = varargin{1};
                obj.YLim = varargin{2};
                obj.ZLim = varargin{3};
            end
        
            [xyzPoints, currPose, trajectory]  = retrievePlottedData(obj, vSetKeyFrames, mapPoints);
             
            obj.MapPointsPlot = pcplayer(obj.XLim, obj.YLim, obj.ZLim, ...
                'VerticalAxis', 'z', 'VerticalAxisDir', 'up');
            
            obj.Axes  = obj.MapPointsPlot.Axes;
            obj.MapPointsPlot.view(xyzPoints); 
            obj.Axes.Children.DisplayName = 'Map points';
            
            hold(obj.Axes, 'on');
            
            % Set figure position on the screen
            movegui(obj.Axes.Parent, [1000 200]);
            
            % Plot camera trajectory
            obj.EstimatedTrajectory = plot3(obj.Axes, trajectory(:,1), trajectory(:,2), ...
                trajectory(:,3), 'r', 'LineWidth', 2 , 'DisplayName', 'Estimated trajectory');
            
            % Plot the current cameras
            obj.CameraPlot = plotCamera(currPose, 'Parent', obj.Axes, 'Size', 0.05);

            view(obj.Axes, [0, -90]);
        end
        
        function updatePlot(obj, vSetKeyFrames, mapPoints)
            
            [xyzPoints, currPose, trajectory]  = retrievePlottedData(obj, vSetKeyFrames, mapPoints);
            
            % Update the point cloud
            obj.MapPointsPlot.view(xyzPoints);
            
            % Update the camera trajectory
            set(obj.EstimatedTrajectory, 'XData', trajectory(:,1), 'YData', ...
                trajectory(:,2), 'ZData', trajectory(:,3));
            
            % Update the current camera pose since the first camera is fixed
            obj.CameraPlot.AbsolutePose = currPose.AbsolutePose;
            obj.CameraPlot.Label        = num2str(currPose.ViewId);

            view(obj.Axes, [0, -90]);
            
            drawnow limitrate
        end
        
        function plotOptimizedTrajectory(obj, poses)
            
            % Delete the camera plot
            delete(obj.CameraPlot);
            
            % Plot the optimized trajectory
            trans = vertcat(poses.AbsolutePose.Translation);
            obj.OptimizedTrajectory = plot3(obj.Axes, trans(:, 1), trans(:, 2), trans(:, 3), 'm', ...
                'LineWidth', 2, 'DisplayName', 'Optimized trajectory');
        end
        
        function plotActualTrajectory(obj, data, keyFrameToFrame, gDir)

            GT = data.gTruth(keyFrameToFrame, 1:3);

            gDirInv = se3(invert(gDir).A);
            imuToCam = inv(data.camToIMUTransform);
            GT = imuToCam.transform(GT);
            GT = gDirInv.transform(GT);

            % Plot the ground truth
            plot3(obj.Axes, GT(:,1), GT(:,2), GT(:,3), ...
                'g','LineWidth',2, 'DisplayName', 'Actual trajectory');
            
            drawnow limitrate
        end
        
        function showPlotLegend(obj)
            % Add a legend to the axes
            hLegend = legend(obj.Axes, 'Location',  'northeast', ...
                'TextColor', [1 1 1], 'FontWeight', 'bold');
        end
    end
    
    methods (Access = private)
        function [xyzPoints, currPose, trajectory]  = retrievePlottedData(obj, vSetKeyFrames, mapPoints)
            camPoses    = poses(vSetKeyFrames);
            currPose    = camPoses(end,:); % Contains both ViewId and Pose

            % Ensure the rotation matrix is a rigid transformation
            R = double(currPose.AbsolutePose.R);
            t = double(currPose.AbsolutePose.Translation);
            [U, ~, V] = svd(R);
            currPose.AbsolutePose.A = eye(4);
            currPose.AbsolutePose.A(1:3, 4) = t;
            currPose.AbsolutePose.A(1:3, 1:3) = U * V';

            trajectory  = vertcat(camPoses.AbsolutePose.Translation);
            xyzPoints   = mapPoints.WorldPoints;

            % idx=randsample(size(xyzPoints,1),int32(size(xyzPoints,1)*0.1));
            % xyzPoints = xyzPoints(idx,:);
            
            % Only plot the points within the limit
            inPlotRange = xyzPoints(:, 1) > obj.XLim(1) & ...
                xyzPoints(:, 1) < obj.XLim(2) & xyzPoints(:, 2) > obj.YLim(1) & ...
                xyzPoints(:, 2) < obj.YLim(2) & xyzPoints(:, 3) > obj.ZLim(1) & ...
                xyzPoints(:, 3) < obj.ZLim(2);
            xyzPoints   = xyzPoints(inPlotRange, :);
        end
        
       
    end
end

