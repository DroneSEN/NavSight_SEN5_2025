%HelperVisualLocalizationSystem Implements the visual localization algorithm
%
%   This is an example helper class that is subject to change or removal
%   in future releases.

%   Copyright 2021-2022 The MathWorks, Inc.
classdef HelperVisualLocalizationSystem < matlab.System

    % Public, non-tunable properties
    properties(Nontunable)
        %FocalLength Camera focal length
        FocalLength  = [1109 1109]

        %PrincipalPoint Camera focal center
        PrincipalPoint = [640 360]

        %ImageSize Image size
        ImageSize = [720 1280]

        %ScaleFactor Scale factor for image decomposition
        ScaleFactor = 1.2

        %NumLevels Number of decomposition levels
        NumLevels  = 8

        %NumPoints Number of feature points
        NumPoints  = 1500

        %XLim X-axis limits
        XLim       = [-15 40]

        %YLim Y-axis limits
        YLim       = [-10 5]

        %Zlim Z-axis limits
        ZLim       = [-20 90]

        %SampleTime Sample time
        SampleTime = 0.2
        %MapDataFileName Map data file name
        MapDataFileName = ''

        
    end

    % Pre-computed constants
    properties(Access = private)
        Intrinsics

        % Internal states
        RefKeyFrameId
        LocalKeyFrameIds
        LastPose
        RelocalizationRequired = true

        % Data management
        MapPointSet
        KeyFrameSet

        % Flags
        RelocFailed % Indicate that the relocalization has failed

        % Visualization
        PointCloudPlayer
        MapPlotAxes
        CameraPlot
        LocalMapPlot
        CameraTrajectoryPlot
        GroundTruthPlot
        WorldPoints
        InitialWorldCameraPose
        InitialEstimatedPose

        TrackingLost
    end

    methods
        % Constructor
        function obj = HelperVisualLocalizationSystem(varargin)
            % Support name-value pair arguments when constructing object
            setProperties(obj,nargin,varargin{:})
        end
    end

    methods(Access = protected)
        %% Common functions
        function setupImpl(obj)
            % Load pre-built map
            storedData            = load(obj.MapDataFileName);
            obj.MapPointSet       = storedData.mapPointSet;
            obj.KeyFrameSet       = storedData.vSetKeyFrames;
            % obj.MapPointSet       = evalin('base','mapPointSet') ;
            % obj.KeyFrameSet       = evalin('base', 'vSetKeyFrames');

            obj.RelocFailed = 0;
            obj.LastPose = rigidtform3d;

            obj.WorldPoints = obj.MapPointSet.WorldPoints;

            % Set random seed for reproducibility
            rng(0);

            % Camera intrinsic parameters
            obj.Intrinsics = cameraIntrinsics(obj.FocalLength, obj.PrincipalPoint, obj.ImageSize);
        end

        function [Pose,Rotation, RelocFailed] = stepImpl(obj, image)  %, location, orientation)
            % Skip invalid images
            if all(~image)
                return
            end

            [currFeatures, currPoints] = detectAndExtractFeatures(obj, image);

            % Check if global relocalization is required
            if obj.RelocalizationRequired
                [currPose, obj.RefKeyFrameId, mapPointIdx, ~, ~, relocStatus] = ...
                    helperGlobalInitialization(obj.MapPointSet, obj.KeyFrameSet, ...
                    currFeatures, currPoints, obj.Intrinsics);

                if relocStatus == 0 % Success
                    obj.RelocalizationRequired = false;
                    obj.InitialEstimatedPose   = currPose;
                    obj.LocalKeyFrameIds       = obj.RefKeyFrameId;

                    % Successfuly relocated
                    obj.RelocFailed = 0;
                elseif relocStatus == -1 % Failure
                    % Relocalization failed, the current position is
                    % set to the last known position

                    obj.RelocalizationRequired = true;
                    obj.InitialEstimatedPose = rigidtform3d;
                    obj.LocalKeyFrameIds = [];

                    % Set the tracking lost flag
                    disp('Relocalization failed');
                    obj.RelocFailed = 1;
                end 
            else
                % Track the reference key frame
                [currPose, mapPointsIdx, featureIdx] = helperTrackRefKeyFrame(obj.MapPointSet, ...
                    obj.KeyFrameSet.Views, currFeatures, currPoints, obj.RefKeyFrameId, ...
                    obj.Intrinsics);

                % If the tracking is lost, a relocalization is required.
                % The relocalization is based on the last known position of
                % the drone
                obj.TrackingLost = isempty(currPose);
                obj.RelocalizationRequired = isempty(currPose);

                if obj.RelocalizationRequired
                    % Make a global relocalization
                    [currPose, obj.RefKeyFrameId, mapPointIdx, ~, ~, relocStatus] = ...
                        helperGlobalInitialization(obj.MapPointSet, obj.KeyFrameSet, ...
                        currFeatures, currPoints, obj.Intrinsics, obj.LastPose, obj.LocalKeyFrameIds);

                    if relocStatus == 0
                        % Relocalization is successful (the current
                        % position has been updated)
                        obj.RelocalizationRequired = false;
                        obj.RelocFailed = 0;
                    else
                        % The relocalisation has failed, the current
                        % position is set to the last know position
                        disp('Relocalization failed');
                        obj.RelocFailed = 1;
                        currPose = obj.LastPose;
                    end
                else
                    % Track local key frames (Visual Odometry)
                    [obj.RefKeyFrameId, obj.LocalKeyFrameIds, currPose, mapPointIdx] = ...
                        helperTrackLocalKeyFrames(obj.MapPointSet, obj.KeyFrameSet, mapPointsIdx, ...
                        featureIdx, currPose, currFeatures, currPoints, obj.Intrinsics, obj.ScaleFactor, obj.NumLevels);
                end
            end

            % % Calculate the actual displacement based on the ground truth
            % R = rotmat(quaternion(orientation, 'euler', 'XYZ', 'point'), 'point');
            % poseActual = rigidtform3d(R, location);
            % if isempty(obj.InitialWorldCameraPose)
            %     obj.InitialWorldCameraPose = poseActual;
            %     obj.InitialEstimatedPose = currPose;
            %     relTranslation = zeros(1, 3);
            % else
            %     relTranslation = location - obj.InitialWorldCameraPose.Translation;
            % end
            updateVisulization(obj, currPose, mapPointIdx); %relTranslation

            % Store the previous position
            obj.LastPose = currPose;

            Pose = currPose.Translation;
            Rotation  = currPose.Rotation;
            RelocFailed = obj.RelocFailed;
        end

        function resetImpl(obj)
            % Initialize / reset discrete-state properties
            obj.RefKeyFrameId          = [];
            obj.LocalKeyFrameIds       = [];
            obj.RelocalizationRequired = true;

            if ~isempty(obj.MapPlotAxes)
                close(obj.MapPlotAxes.Parent);
            else
                obj.MapPlotAxes = gca(figure);
            end

            color = obj.WorldPoints(:, 2);
            color = -min(2, max(-10, color));

            % Plot the map
            obj.PointCloudPlayer = pcplayer(obj.XLim, obj.YLim, obj.ZLim, ...
                'VerticalAxis' , 'z', 'VerticalAxisDir', 'up', 'Parent', obj.MapPlotAxes);
            set(obj.MapPlotAxes.Parent, 'Position', [100, 100, 900, 500]);
            hold(obj.MapPlotAxes, 'on');
            obj.PointCloudPlayer.view(obj.WorldPoints, color);

            % Set up camera view
            camproj(obj.MapPlotAxes, 'perspective');
            camva(obj.MapPlotAxes, 1);
            camup(obj.MapPlotAxes, [0.45 -0.8 -0.35])
            campos(obj.MapPlotAxes, [-3e3 -2.5e3 2.5e3]);
            camtarget(obj.MapPlotAxes, [39 22 -5]);
        end
        

        %% Simulink functions

        function [Pose,Rotation, RelocFailed] = getOutputSizeImpl(obj)
            % Return size for each output port
            Pose = [1 3];
            Rotation = [3 3];
            RelocFailed = [1 1];
        end
        function [Pose,Rotation,RelocFailed] = getOutputDataTypeImpl(obj)
            % Return data type for each output port
            Pose = 'double';
            Rotation = 'double';
            RelocFailed = 'double';
        end
        function [Pose,Rotation,RelocFailed] = isOutputComplexImpl(obj)
            % Return true for each output port with complex data
            Pose = false;
            Rotation = false;
            RelocFailed = false;
        end
        function [Pose,Rotation,RelocFailed] = isOutputFixedSizeImpl(obj)
            % Return true for each output port with fixed size
            Pose = true;
            Rotation = true;
            RelocFailed = true;
        end
        function [Pose,Rotation,RelocFailed] = getOutputNamesImpl(obj)
            % Return output port names for System block
            Pose = 'Agent Pose';
            Rotation = 'Agent Rotation';
            RelocFailed = 'Relocalization failure';
        end
        function flag = isInputSizeMutableImpl(~,~)
            flag = false;
        end

        function icon = getIconImpl(~)
            % Define icon for System block
            icon = ["Helper", "Visual", "Localization"];
        end
        
        function [name1] = getInputNamesImpl(~) % ,name2,name3]
            % Return input port names for System block
            name1 = 'Image';
        %     name2 = 'Location';
        %     name3 = 'Orientation';
        end

        function sts = getSampleTimeImpl(obj)
            if obj.SampleTime == -1
                sts = createSampleTime(obj,'Type','Inherited');
            else
                sts = createSampleTime(obj,'Type','Discrete',...
                    'SampleTime',obj.SampleTime);
            end
        end

        %% Utility functions
        function [features, validPoints] = detectAndExtractFeatures(obj, Irgb)
            %detectAndExtractFeatures detect and extract features

            % Detect ORB features
            Igray  = im2gray(Irgb);

            points = detectORBFeatures(Igray, 'ScaleFactor', obj.ScaleFactor, 'NumLevels', obj.NumLevels);

            % Select a subset of features, uniformly distributed throughout the image
            points = selectUniform(points, obj.NumPoints, size(Igray, 1:2));

            % Extract features
            [features, validPoints] = extractFeatures(Igray, points);
        end

        function updateVisulization(obj, currPose, mapPointIdx) %relTranslation

            % Plot the camera pose of the current frame
            if isempty(obj.CameraPlot)
                obj.CameraPlot = plotCamera('AbsolutePose', currPose, 'Parent', obj.MapPlotAxes, 'Size', 1);
            else
                obj.CameraPlot.AbsolutePose = currPose;
            end

            % Plot local map points observed in the current frame
            if isempty(obj.LocalMapPlot)
                obj.LocalMapPlot = scatter3(obj.MapPlotAxes, obj.WorldPoints(mapPointIdx, 1), ...
                    obj.WorldPoints(mapPointIdx, 2), obj.WorldPoints(mapPointIdx, 3), 8, 'w', 'o', 'filled');
            else
                set(obj.LocalMapPlot, 'XData', obj.WorldPoints(mapPointIdx, 1), 'YData', ...
                    obj.WorldPoints(mapPointIdx, 2), 'ZData', obj.WorldPoints(mapPointIdx, 3));
            end

            % % Plot camera trajectory
            % estimatedLocation = currPose.Translation;
            % if isempty(obj.CameraTrajectoryPlot)
            %     if any(estimatedLocation)
            %         obj.CameraTrajectoryPlot= plot3(obj.MapPlotAxes, ...
            %             estimatedLocation(1), estimatedLocation(2), estimatedLocation(3), ...
            %             'r.', 'LineWidth', 2, 'DisplayName', 'Estimated Trajectory');
            %     end
            % else
            %     set(obj.CameraTrajectoryPlot, ...
            %         'XData', [obj.CameraTrajectoryPlot.XData, estimatedLocation(1)], ...
            %         'YData', [obj.CameraTrajectoryPlot.YData, estimatedLocation(2)], ...
            %         'ZData', [obj.CameraTrajectoryPlot.ZData, estimatedLocation(3)]);
            % end
            % 
            % % Plot the ground truth in the camera coordinate system
            % R = [0 0 -1; 1 0 0; 0 -1 0];
            % gTruthLocation = obj.InitialEstimatedPose.Translation + relTranslation * R;
            % if isempty(obj.GroundTruthPlot)
            %     obj.GroundTruthPlot = plot3(obj.MapPlotAxes, ...
            %         gTruthLocation(1), gTruthLocation(2), gTruthLocation(3), ...
            %         'g.', 'LineWidth', 2, 'DisplayName', 'Ground truth');
            % else
            %     set(obj.GroundTruthPlot, ...
            %         'XData', [obj.GroundTruthPlot.XData, gTruthLocation(1)], ...
            %         'YData', [obj.GroundTruthPlot.YData, gTruthLocation(2)],...
            %         'ZData', [obj.GroundTruthPlot.ZData, gTruthLocation(3)]);
            % end
            % legend([obj.CameraTrajectoryPlot, obj.GroundTruthPlot], 'location', 'northwest','color','w', 'FontWeight', 'bold');
            % drawnow;
        end
    end

    methods(Static, Access = protected)
        %% Simulink customization functions
        function header = getHeaderImpl
            % Define header panel for System block dialog
            header = matlab.system.display.Header(mfilename("class"));
        end

        function group = getPropertyGroupsImpl
            % Define property section(s) for System block dialog

            % Section for pre-built map data
            mapSection = matlab.system.display.Section(...
                'Title','Pre-built Map ',...
                'PropertyList',{'MapDataFileName'});

            % Section for visualization
            vizSection = matlab.system.display.Section(...
                'Title','Visualization',...
                'PropertyList',{'XLim','YLim','ZLim'});

            % Section for the camera parameters
            cameraSection = matlab.system.display.Section(...
                'Title','Camera Intrinsic Parameters',...
                'PropertyList',{'FocalLength','PrincipalPoint','ImageSize'});

            % Section for sample time
            sampleTimeSection = matlab.system.display.Section(...
                'Title','',...
                'PropertyList',{'SampleTime'});

            group = [mapSection, cameraSection, vizSection, sampleTimeSection];
        end

        function simMode = getSimulateUsingImpl
            simMode = 'Interpreted execution';
        end

        function flag = showSimulateUsingImpl
            % Return false if simulation mode hidden in System block dialog
            flag = false;
        end
    end
end

