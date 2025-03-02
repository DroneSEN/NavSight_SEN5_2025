%ImprovedHelperVisualLocalizationSystem Implements the visual localization algorithm
%
%   This is an example helper class that is subject to change or removal
%   in future releases.

%   Copyright 2021-2022 The MathWorks, Inc.
classdef ImprovedHelperVisualLocalizationSystem < matlab.System

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
        XLim       = [-40 40]

        %YLim Y-axis limits
        YLim       = [-10 60]

        %Zlim Z-axis limits
        ZLim       = [-2 40]

        %SampleTime Sample time
        SampleTime = 0.1

        % Répertoire des scénarios
        ScenariosDirectory = "C:\Users\vince\Documents\SEN5\CollaborativeSLAM\Scenarios";

        % Nom du scénario à charger
        ScenarioName = "6";        
    end

    % Pre-computed constants
    properties(Access = private)
        Intrinsics

        % Internal states
        RefKeyFrameId
        LocalKeyFrameIds
        LastPose
        LastPoseKnown = false;
        RelocalizationRequired = true

        % Data management
        MapPointSet
        KeyFrameSet

        % Flags
        GlobalRelocFail % Indicate that the relocalization has failed
        TrackingEnabled % Indicate that the tracking is enabled
        TrackingFail % Indicate that the tracking has failed (Potentiellement redondant)

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

        % Map file
        MapDataFileName
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
            %MapDataFileName Map data file name
            obj.MapDataFileName = fullfile(obj.ScenariosDirectory, obj.ScenarioName, "map", "generated_map.mat");

            storedData            = load(obj.MapDataFileName);
            obj.MapPointSet       = storedData.mapPointSet;
            obj.KeyFrameSet       = storedData.vSetKeyFrames;
            % obj.MapPointSet       = evalin('base','mapPointSet') ;
            % obj.KeyFrameSet       = evalin('base', 'vSetKeyFrames');

            obj.GlobalRelocFail = 0;
            obj.LastPose = rigidtform3d;

            obj.WorldPoints = obj.MapPointSet.WorldPoints;

            obj.TrackingEnabled = 0;
            obj.TrackingFail = 0;

            % Set random seed for reproducibility
            rng(0);

            % Camera intrinsic parameters
            obj.Intrinsics = cameraIntrinsics(obj.FocalLength, obj.PrincipalPoint, obj.ImageSize);
        end

        function [Pose,Rotation, LocalRelocFail, GlobalRelocFail] = stepImpl(obj, image)  %, location, orientation)
            if all(~image)
                % Assign default values before returning
                Pose = zeros(1, 3);
                Rotation = eye(3);
                LocalRelocFail = 1;  % Indicating failure
                GlobalRelocFail = 1; % Indicating failure
                return
            end
            [currFeatures, currPoints] = detectAndExtractFeatures(obj, image);


            % ========================= TRACKING ==========================
            % If the tracking is enabled
            if obj.TrackingEnabled
                % Track the reference key frame
                [currPose, mapPointsIdx, featureIdx] = helperTrackRefKeyFrame(obj.MapPointSet, ...
                    obj.KeyFrameSet.Views, currFeatures, currPoints, obj.RefKeyFrameId, ...
                    obj.Intrinsics);

                if isempty(currPose)
                    % If the tracking failed, set the flag and disable
                    % tracking
                    obj.TrackingFail = 1;

                    % Disable the tracking
                    obj.TrackingEnabled = 0;
                else
                    % If the reference keyframe tracking is successful, we
                    % use local keyframes to improve the tracking
                    [obj.RefKeyFrameId, obj.LocalKeyFrameIds, currPose, mapPointIdx] = ...
                        helperTrackLocalKeyFrames(obj.MapPointSet, ...
                        obj.KeyFrameSet, mapPointsIdx, ...
                        featureIdx, currPose, currFeatures, ...
                        currPoints, obj.Intrinsics, ...
                        obj.ScaleFactor, obj.NumLevels, ...
                        obj.RefKeyFrameId );
                    
                    if isempty(currPose)
                        % If the tracking failed, set the flag and disable
                        % tracking
                        obj.TrackingFail = 1;
    
                        % Disable the tracking
                        obj.TrackingEnabled = 0;
                    end
                end
            end

            % =================== Local Relocalization ====================
            % If the tracking failed and the last position in known,
            % perform a local relocalization
            localRelocalizationFail = 0;
            if ~obj.TrackingEnabled && obj.LastPoseKnown

                % Make a local relocalization
                [currPose, obj.RefKeyFrameId, mapPointIdx, ~, ~, relocStatus] = ...
                    helperGlobalInitialization(obj.MapPointSet, obj.KeyFrameSet, ...
                    currFeatures, currPoints, obj.Intrinsics, obj.LastPose, obj.LocalKeyFrameIds);

                if relocStatus == 0
                    % Relocalization is successful (the current
                    % position has been updated)
                    localRelocalizationFail = 0;

                    % The tracking is enabled
                    obj.TrackingEnabled = 1;
                    obj.LastPoseKnown = true;
                else
                    % The relocalisation has failed, the current
                    % position is set to the last know position
                    disp('Local relocalization failed');
                    localRelocalizationFail = 1;
                    currPose = obj.LastPose;
                end
            end

            % =================== Global Relocalization ===================
            % Perform a global relocalization if:
            % - the tracking failed and the last position is unknown (for
            %   initialization for instance)
            % - the local relocalization failed
            if (~obj.TrackingEnabled && ~obj.LastPoseKnown) || localRelocalizationFail

                [currPose, obj.RefKeyFrameId, mapPointIdx, ~, ~, relocStatus] = ...
                helperGlobalInitialization(obj.MapPointSet, obj.KeyFrameSet, ...
                    currFeatures, currPoints, obj.Intrinsics);

                if relocStatus == 0 % Successfuly relocated
                    obj.LocalKeyFrameIds       = obj.RefKeyFrameId;
                    obj.GlobalRelocFail = 0;

                    % The tracking is enabled
                    obj.TrackingEnabled = 1;
                    obj.LastPoseKnown = true;
                elseif relocStatus == -1 % Failure
                    % Relocalization failed, the current position is
                    % set to the origin
                    currPose = rigidtform3d;
                    obj.LocalKeyFrameIds = [];

                    % Set the tracking lost flag
                    disp('Global relocalization failed');
                    obj.GlobalRelocFail = 1;
                    obj.LastPoseKnown = false;
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
            % updateVisulization(obj, currPose, mapPointIdx); %relTranslation

            % Store the previous position
            obj.LastPose = currPose;

            Pose = currPose.Translation;
            Rotation  = currPose.Rotation;
            LocalRelocFail = localRelocalizationFail;
            GlobalRelocFail = obj.GlobalRelocFail;
        end

        function resetImpl(obj)
            % Initialize / reset discrete-state properties
            obj.RefKeyFrameId          = [];
            obj.LocalKeyFrameIds       = [];
            obj.RelocalizationRequired = true;
            % 
            % if ~isempty(obj.MapPlotAxes)
            %     close(obj.MapPlotAxes.Parent);
            % else
            %     obj.MapPlotAxes = gca(figure);
            % end
            % 
            % color = obj.WorldPoints(:, 2);
            % color = -min(2, max(-10, color));
            % 
            % % Plot the map
            % obj.PointCloudPlayer = pcplayer(obj.XLim, obj.YLim, obj.ZLim, ...
            %     'VerticalAxis' , 'z', 'VerticalAxisDir', 'up', 'Parent', obj.MapPlotAxes);
            % set(obj.MapPlotAxes.Parent, 'Position', [100, 100, 900, 500]);
            % hold(obj.MapPlotAxes, 'on');
            % obj.PointCloudPlayer.view(obj.WorldPoints, color);
            % 
            % % Set up camera view
            % camproj(obj.MapPlotAxes, 'perspective');
            % camva(obj.MapPlotAxes, 1);
            % % camup(obj.MapPlotAxes, [0.45 -0.8 -0.35])
            % % campos(obj.MapPlotAxes, [-3e3 -2.5e3 2.5e3]);
            % % camtarget(obj.MapPlotAxes, [39 22 -5]);
        end
        

        %% Simulink functions

        function [Pose,Rotation, LocalRelocFail, GlobalRelocFail] = getOutputSizeImpl(obj)
            % Return size for each output port
            Pose = [1 3];
            Rotation = [3 3];
            LocalRelocFail = [1 1];
            GlobalRelocFail = [1 1];
        end
        function [Pose,Rotation, LocalRelocFail, GlobalRelocFail] = getOutputDataTypeImpl(obj)
            % Return data type for each output port
            Pose = 'double';
            Rotation = 'double';
            LocalRelocFail = 'double';
            GlobalRelocFail = 'double';
        end
        function [Pose,Rotation,LocalRelocFail, GlobalRelocFail] = isOutputComplexImpl(obj)
            % Return true for each output port with complex data
            Pose = false;
            Rotation = false;
            LocalRelocFail = false;
            GlobalRelocFail = false;
        end
        function [Pose,Rotation,LocalRelocFail, GlobalRelocFail] = isOutputFixedSizeImpl(obj)
            % Return true for each output port with fixed size
            Pose = true;
            Rotation = true;
            LocalRelocFail = true;
            GlobalRelocFail = true;
        end
        function [Pose,Rotation,LocalRelocFail, GlobalRelocFail] = getOutputNamesImpl(obj)
            % Return output port names for System block
            Pose = 'Agent Pose';
            Rotation = 'Agent Rotation';
            LocalRelocFail = 'Local relocalization fail';
            GlobalRelocFail = 'Global relocalization fail';
        end
        function flag = isInputSizeMutableImpl(~,~)
            flag = false;
        end

        function icon = getIconImpl(~)
            % Define icon for System block
            icon = ["Improved", "Helper", "Visual", "Localization"];
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

            % Plot camera trajectory
            estimatedLocation = currPose.Translation;
            if isempty(obj.CameraTrajectoryPlot)
                if any(estimatedLocation)
                    obj.CameraTrajectoryPlot= plot3(obj.MapPlotAxes, ...
                        estimatedLocation(1), estimatedLocation(2), estimatedLocation(3), ...
                        'r.', 'LineWidth', 2, 'DisplayName', 'Estimated Trajectory');
                end
            else
                set(obj.CameraTrajectoryPlot, ...
                    'XData', [obj.CameraTrajectoryPlot.XData, estimatedLocation(1)], ...
                    'YData', [obj.CameraTrajectoryPlot.YData, estimatedLocation(2)], ...
                    'ZData', [obj.CameraTrajectoryPlot.ZData, estimatedLocation(3)]);
            end

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

