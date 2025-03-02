classdef HelperVisualizationSystem < matlab.System
    % Public, non-tunable properties
    properties(Nontunable)
        %XLim X-axis limits
        XLim = [-40 40]

        %YLim Y-axis limits
        YLim = [-10 60]

        %Zlim Z-axis limits
        ZLim = [-2 40]

        %SampleTime Sample time
        SampleTime = 0.1

        % Répertoire des scénarios
        ScenariosDirectory = "C:\Users\vince\Documents\SEN5\CollaborativeSLAM\Scenarios";

        % Nom du scénario à charger
        ScenarioName = "6"
        
        % Nombre de poses à tracer
        NumberOfPoses = 2
    end

    properties(Access = private)
        Intrinsics
        RefKeyFrameId
        LocalKeyFrameIds
        LastPose
        LastPoseKnown = false
        RelocalizationRequired = true
        MapPointSet
        KeyFrameSet
        GlobalRelocFail
        TrackingEnabled
        TrackingFail
        PointCloudPlayer
        MapPlotAxes
        CameraPlots = {}  % Tableau pour stocker plusieurs plots de caméras
        LocalMapPlot
        CameraTrajectoryPlots = {} % Tableau pour stocker plusieurs trajectoires
        GroundTruthPlots = {} % Tableau pour stocker plusieurs ground truths
        WorldPoints
        InitialWorldCameraPose
        InitialEstimatedPose
        MapDataFileName
        tform
        Colors = {'r', 'b', 'y', 'm', 'c', 'w', [1 0.5 0], [0.5 0 0.5], [0 0.5 0.5]} % Couleurs pour les trajectoires estimées
    end

    methods
        function obj = HelperVisualizationSystem(varargin)
            setProperties(obj,nargin,varargin{:})
        end
    end

    methods(Access = protected)
        function validatePropertiesImpl(obj)
            % Valider que le nombre de poses est positif
            if obj.NumberOfPoses < 1
                error('NumberOfPoses doit être supérieur ou égal à 1');
            end
            % Valider qu'il y a assez de couleurs définies
            if obj.NumberOfPoses > length(obj.Colors)
                error('Pas assez de couleurs définies pour le nombre de poses spécifié');
            end
        end

        function setupImpl(obj)
            % Load pre-built map
            obj.MapDataFileName = fullfile(obj.ScenariosDirectory, obj.ScenarioName, "map", "generated_map.mat");
            
            storedData = load(obj.MapDataFileName);
            obj.MapPointSet = storedData.mapPointSet;
            
            obj.WorldPoints = obj.MapPointSet.WorldPoints;
            
            rng(0);
            obj.tform = eye(4);

            % Initialiser les cellules pour les poses et ground truths
            obj.CameraPlots = cell(1, obj.NumberOfPoses);
            obj.CameraTrajectoryPlots = cell(1, obj.NumberOfPoses);
            obj.GroundTruthPlots = cell(1, obj.NumberOfPoses);
        end

        function stepImpl(obj, TformsConcatenated, GtruthsConcatenated)
            % Calculer la taille de la caméra
            axisRange = max([diff(obj.XLim), diff(obj.YLim), diff(obj.ZLim)]);
            cameraSize = axisRange * 0.005;
            
            try
                % Plot du nuage de points s'il n'existe pas encore
                if isempty(obj.LocalMapPlot)
                    obj.LocalMapPlot = scatter3(obj.MapPlotAxes, ...
                        obj.WorldPoints(:,2), obj.WorldPoints(:,1), obj.WorldPoints(:,3), ... % Changement d'axes  x <-> y
                        2, 'c', 'filled', 'DisplayName', 'Map Points');
                end
                
                % Traiter les poses estimées si présentes
                if ~isempty(TformsConcatenated)
                    % Vérifier la taille de la matrice des poses
                    expectedColsTform = 4 * obj.NumberOfPoses;
                    if size(TformsConcatenated, 1) == 4 && size(TformsConcatenated, 2) == expectedColsTform
                        % Traiter chaque pose estimée
                        for i = 1:obj.NumberOfPoses
                            startColTform = (i-1)*4 + 1;
                            endColTform = i*4;
                            currTform = TformsConcatenated(:, startColTform:endColTform);
                            
                            if ~all(currTform(:) == 0)
                                currPose = rigidtform3d(currTform);
                                
                                % Plot de la caméra
                                if isempty(obj.CameraPlots{i})
                                    obj.CameraPlots{i} = plotCamera('AbsolutePose', currPose, 'Parent', obj.MapPlotAxes, ...
                                        'Size', cameraSize, 'Color', obj.Colors{i});
                                else
                                    obj.CameraPlots{i}.AbsolutePose = currPose;
                                    obj.CameraPlots{i}.Size = cameraSize;
                                end

                                % Plot de la trajectoire estimée
                                estimatedLocation = currPose.Translation;
                                if isempty(obj.CameraTrajectoryPlots{i})
                                    if any(estimatedLocation)
                                        obj.CameraTrajectoryPlots{i} = plot3(obj.MapPlotAxes, ...
                                            estimatedLocation(1), estimatedLocation(2), estimatedLocation(3), ...
                                            ['-'], 'Color', obj.Colors{i}, 'LineWidth', 1.5, ...
                                            'DisplayName', ['Estimated Trajectory ' num2str(i)]);
                                    end
                                else
                                    set(obj.CameraTrajectoryPlots{i}, ...
                                        'XData', [obj.CameraTrajectoryPlots{i}.XData, estimatedLocation(1)], ...
                                        'YData', [obj.CameraTrajectoryPlots{i}.YData, estimatedLocation(2)], ...
                                        'ZData', [obj.CameraTrajectoryPlots{i}.ZData, estimatedLocation(3)]);
                                end
                            end
                        end
                    else
                        warning('La matrice des poses doit être de taille 4x%d pour %d poses', expectedColsTform, obj.NumberOfPoses);
                    end
                end

                % Traiter les ground truths si présents
                if ~isempty(GtruthsConcatenated)
                    expectedColsGtruth = 3 * obj.NumberOfPoses;
                    if size(GtruthsConcatenated, 1) == 1 && size(GtruthsConcatenated, 2) == expectedColsGtruth
                        % Traiter chaque ground truth
                        for i = 1:obj.NumberOfPoses
                            startColGtruth = (i-1)*3 + 1;
                            endColGtruth = i*3;
                            currGtruth = GtruthsConcatenated(1, startColGtruth:endColGtruth);

                            if ~all(currGtruth == 0)
                                if isempty(obj.GroundTruthPlots{i})
                                    obj.GroundTruthPlots{i} = plot3(obj.MapPlotAxes, ...
                                        currGtruth(1), currGtruth(2), currGtruth(3), ...
                                        '-', 'Color', [0 0.8 0], 'LineWidth', 1.5, ...
                                        'DisplayName', ['Ground Truth ' num2str(i)]);
                                else
                                    set(obj.GroundTruthPlots{i}, ...
                                        'XData', [obj.GroundTruthPlots{i}.XData, currGtruth(1)], ...
                                        'YData', [obj.GroundTruthPlots{i}.YData, currGtruth(2)], ...
                                        'ZData', [obj.GroundTruthPlots{i}.ZData, currGtruth(3)]);
                                end
                            end
                        end
                    else
                        warning('La matrice des ground truths doit être de taille 1x%d pour %d poses', expectedColsGtruth, obj.NumberOfPoses);
                    end
                end

                % Mise à jour de la légende
                legendItems = [];
                legendNames = {};
                
                if ~isempty(obj.LocalMapPlot)
                    legendItems = [legendItems, obj.LocalMapPlot];
                    legendNames = [legendNames, {'Map Points'}];
                end
                
                % Ajouter toutes les trajectoires existantes à la légende
                for i = 1:obj.NumberOfPoses
                    if ~isempty(obj.CameraTrajectoryPlots{i}) && isvalid(obj.CameraTrajectoryPlots{i})
                        legendItems = [legendItems, obj.CameraTrajectoryPlots{i}];
                        legendNames = [legendNames, {['Estimated Trajectory ' num2str(i)]}];
                    end
                    if ~isempty(obj.GroundTruthPlots{i}) && isvalid(obj.GroundTruthPlots{i})
                        legendItems = [legendItems, obj.GroundTruthPlots{i}];
                        legendNames = [legendNames, {['Ground Truth ' num2str(i)]}];
                    end
                end
                
                % Mettre à jour la légende si nous avons des éléments à afficher
                if ~isempty(legendItems)
                    legend(legendItems, legendNames, 'location', 'northwest', 'color', 'w', 'FontWeight', 'bold');
                end
                
                drawnow;
            catch e
                disp(['Error in stepImpl: ' e.message]);
                disp(['Error details: ' getReport(e)]);
            end
        end

        function resetImpl(obj)
        % Create figure
        fig = figure('Name', 'Visual Localization System', ...
                     'Color', 'black', ...
                             'Position', [100, 100, 1500, 900]);
            
            % Vérification et gestion des axes
            if ~isempty(obj.MapPlotAxes)
                close(obj.MapPlotAxes.Parent);
            end
            obj.MapPlotAxes = axes(fig);
            
            % Préparation des couleurs pour le nuage de points
            color = obj.WorldPoints(:, 2);
            color = max(-10, min(2, color));
            
            % Configuration initiale des axes
            set(obj.MapPlotAxes, ...
                'Color', 'black', ...
                'XColor', 'white', ...
                'YColor', 'white', ...
                'ZColor', 'white', ...
                'GridColor', [0.2 0.2 0.2], ...
                'Box', 'on');
            grid(obj.MapPlotAxes, 'on');
            
            % Configuration du point cloud player avec parent
            obj.PointCloudPlayer = pcplayer(obj.XLim, obj.YLim, obj.ZLim, ...
                                          'VerticalAxis', 'z', ...
                                          'VerticalAxisDir', 'up', ...
                                          'Parent', obj.MapPlotAxes);
            
            % Mise à jour de la position de la figure
            set(fig, 'Position', [100, 100, 900, 500]);
            
            % Affichage du nuage de points
            hold(obj.MapPlotAxes, 'on');
            obj.PointCloudPlayer.view(obj.WorldPoints, color);
            
            % Configuration des limites avec marge
            margin = 0.1;
            xlim(obj.MapPlotAxes, [obj.XLim(1)-diff(obj.XLim)*margin, obj.XLim(2)+diff(obj.XLim)*margin]);
            ylim(obj.MapPlotAxes, [obj.YLim(1)-diff(obj.YLim)*margin, obj.YLim(2)+diff(obj.YLim)*margin]);
            zlim(obj.MapPlotAxes, [obj.ZLim(1)-diff(obj.ZLim)*margin, obj.ZLim(2)+diff(obj.ZLim)*margin]);
            
            % Labels des axes
            xlabel(obj.MapPlotAxes, 'X (m)', 'Color', 'white');
            ylabel(obj.MapPlotAxes, 'Y (m)', 'Color', 'white');
            zlabel(obj.MapPlotAxes, 'Z (m)', 'Color', 'white');
            
            % Configuration de la vue
            view(obj.MapPlotAxes, [-37.5, 30]);
            camproj(obj.MapPlotAxes, 'perspective');
            camva(obj.MapPlotAxes, 15);
            
            % Configuration de la caméra
            maxRange = max([diff(obj.XLim), diff(obj.YLim), diff(obj.ZLim)]);
            campos(obj.MapPlotAxes, [maxRange, maxRange, maxRange/2]);
            camtarget(obj.MapPlotAxes, [mean(obj.XLim), mean(obj.YLim), mean(obj.ZLim)]);
            camup(obj.MapPlotAxes, [0, 0, 1]);
            
            % Ajout du système de coordonnées
            axisLength = maxRange * 0.1;
            line(obj.MapPlotAxes, [0 axisLength], [0 0], [0 0], 'Color', 'r', 'LineWidth', 2);
            line(obj.MapPlotAxes, [0 0], [0 axisLength], [0 0], 'Color', 'g', 'LineWidth', 2);
            line(obj.MapPlotAxes, [0 0], [0 0], [0 axisLength], 'Color', 'b', 'LineWidth', 2);
            
            % Activation de la rotation 3D
            rotate3d(obj.MapPlotAxes, 'on');
            
            % Réinitialisation des tableaux de plots
            obj.CameraPlots = cell(1, obj.NumberOfPoses);
            obj.CameraTrajectoryPlots = cell(1, obj.NumberOfPoses);
            obj.GroundTruthPlots = cell(1, obj.NumberOfPoses);
            obj.LocalMapPlot = [];
            
            % Forcer la mise à jour de l'affichage
            drawnow;
        end

        function flag = isInputSizeMutableImpl(~,~)
            flag = false;
        end
        
        function [name1, name2] = getInputNamesImpl(~)
            name1 = 'TformID';
            name2 = 'Gtruth';
        end
    end
end