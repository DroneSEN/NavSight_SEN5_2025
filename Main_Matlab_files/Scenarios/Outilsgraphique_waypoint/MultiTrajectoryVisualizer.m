function MultiTrajectoryVisualizer
% MULTITRAJECTORYVISUALIZER - Visualisateur de trajectoires multiples synchronisées
%
% Cette application permet:
% 1. De visualiser plusieurs fichiers .mat contenant des waypoints simultanément
% 2. De simuler le mouvement des drones le long des trajectoires de façon synchronisée
% 3. D'exporter des vues et animations des trajectoires multiples
%
% Format attendu: Waypoints au format (t, x, y, z, phi, theta, psi)

% Initialisation de la figure principale avec une taille plus grande
fig = figure('Name', 'Multi-Trajectory Visualizer', 'NumberTitle', 'off', ...
    'Position', [100, 50, 1400, 900], 'MenuBar', 'none', 'Toolbar', 'figure');

% Variables globales
data = struct();
data.trajectories = {};  % Liste des trajectoires chargées
data.isPlaying = false;
data.playbackTimer = [];
data.playbackRate = 1;
data.currentTime = 0;
data.globalStartTime = 0;
data.globalEndTime = 0;
data.droneModels = {};
data.colorMap = {'b', 'r', 'g', 'm', 'c', 'y', 'k'};

% Création des axes pour la visualisation 3D (réduit pour faire plus de place aux contrôles)
ax = axes('Parent', fig, 'Position', [0.32, 0.22, 0.66, 0.7]);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');
axis(ax, 'equal');
view(ax, 3);
xlabel(ax, 'X (avant)');
ylabel(ax, 'Y (gauche)');
zlabel(ax, 'Z (haut)');
title(ax, 'Trajectoires synchronisées');

% Limites par défaut pour la visualisation
defaultLimits = [-10 100 -120 10 -5 40];
axis(ax, defaultLimits);

% Création du panneau de contrôle (élargi)
controlPanel = uipanel('Title', 'Contrôles', 'Position', [0.01, 0.22, 0.30, 0.7]);

% Espace pour les boutons manquants
uicontrol('Parent', controlPanel, 'Style', 'text', ...
    'String', 'Trajectoires chargées:', 'Position', [10, 550, 150, 20], ...
    'HorizontalAlignment', 'left');

trajectoryList = uicontrol('Parent', controlPanel, 'Style', 'listbox', ...
    'Position', [10, 430, 380, 140], ...
    'String', {}, 'Max', 2);  % Max = 2 pour permettre la sélection multiple

% Boutons de gestion des trajectoires (déplacés)
btnLoad = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
    'String', 'Charger trajectoire...', 'Position', [10, 400, 100, 25], ...
    'Callback', @loadTrajectory);

btnRemove = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
    'String', 'Supprimer', 'Position', [150, 400, 100, 25], ...
    'Callback', @removeTrajectory);

btnClearAll = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
    'String', 'Tout effacer', 'Position', [300, 400, 100, 25], ...
    'Callback', @clearAllTrajectories);

% Options d'affichage (modifié pour éviter les chevauchements)
displayPanel = uipanel('Parent', controlPanel, 'Title', 'Options d''affichage', ...
    'Position', [0.03, 0.33, 0.94, 0.33]);

% Checkbox pour les options d'affichage - première colonne
cbShowWaypoints = uicontrol('Parent', displayPanel, 'Style', 'checkbox', ...
    'String', 'Waypoints', 'Position', [10, 125, 180, 20], ...
    'Value', 1, 'Callback', @updateDisplay);

cbShowPath = uicontrol('Parent', displayPanel, 'Style', 'checkbox', ...
    'String', 'Chemins', 'Position', [10, 100, 180, 20], ...
    'Value', 1, 'Callback', @updateDisplay);

cbShowDrones = uicontrol('Parent', displayPanel, 'Style', 'checkbox', ...
    'String', 'Drones', 'Position', [10, 75, 180, 20], ...
    'Value', 1, 'Callback', @updateDisplay);

cbShowAxes = uicontrol('Parent', displayPanel, 'Style', 'checkbox', ...
    'String', 'Axes drones', 'Position', [10, 50, 180, 20], ...
    'Value', 0, 'Callback', @updateDisplay);

cbShowGrid = uicontrol('Parent', displayPanel, 'Style', 'checkbox', ...
    'String', 'Grille au sol', 'Position', [10, 25, 180, 20], ...
    'Value', 1, 'Callback', @toggleGrid);

% Deuxième colonne (déplacée)
cbShowLabels = uicontrol('Parent', displayPanel, 'Style', 'checkbox', ...
    'String', 'Labels', 'Position', [200, 125, 180, 20], ...
    'Value', 0, 'Callback', @updateDisplay);

cbShowTimeMarker = uicontrol('Parent', displayPanel, 'Style', 'checkbox', ...
    'String', 'Marqueur temps', 'Position', [200, 100, 180, 20], ...
    'Value', 1, 'Callback', @updateDisplay);

cbTrails = uicontrol('Parent', displayPanel, 'Style', 'checkbox', ...
    'String', 'Afficher traînées', 'Position', [200, 75, 180, 20], ...
    'Value', 1, 'Callback', @updateDisplay);

uicontrol('Parent', displayPanel, 'Style', 'text', ...
    'String', 'Longueur traînée:', 'Position', [200, 50, 120, 20], ...
    'HorizontalAlignment', 'left');

editTrailLength = uicontrol('Parent', displayPanel, 'Style', 'edit', ...
    'String', '5', 'Position', [320, 50, 40, 20], ...
    'Callback', @updateDisplay);

uicontrol('Parent', displayPanel, 'Style', 'text', ...
    'String', 'sec', 'Position', [360, 50, 30, 20], ...
    'HorizontalAlignment', 'left');

% Options de synchronisation (repositionné)
syncPanel = uipanel('Parent', controlPanel, 'Title', 'Synchronisation', ...
    'Position', [0.03, 0.12, 0.94, 0.19]);

rbGlobalTime = uicontrol('Parent', syncPanel, 'Style', 'radiobutton', ...
    'String', 'Temps global', 'Position', [20, 70, 150, 20], ...
    'Value', 1, 'Callback', @syncModeChanged);

rbNormalizedTime = uicontrol('Parent', syncPanel, 'Style', 'radiobutton', ...
    'String', 'Temps normalisé', 'Position', [200, 70, 150, 20], ...
    'Value', 0, 'Callback', @syncModeChanged);

% Offset de temps (repositionné)
uicontrol('Parent', syncPanel, 'Style', 'text', ...
    'String', 'Offset temps:', 'Position', [20, 50, 100, 20], ...
    'HorizontalAlignment', 'left');

editTimeOffset = uicontrol('Parent', syncPanel, 'Style', 'edit', ...
    'String', '0', 'Position', [120, 50, 70, 20]);

btnApplyOffset = uicontrol('Parent', syncPanel, 'Style', 'pushbutton', ...
    'String', 'Appliquer', 'Position', [200, 50, 100, 20], ...
    'Callback', @applyTimeOffset);

% Information (repositionné et agrandi)
infoText = uicontrol('Parent', controlPanel, 'Style', 'text', ...
    'Position', [10, 10, 380, 50], ...
    'HorizontalAlignment', 'left', 'String', 'Chargez des trajectoires pour commencer.');

% Panneau de lecteur
timePanel = uipanel('Parent', fig, 'Title', 'Contrôle de lecture', ...
    'Position', [0.01, 0.01, 0.98, 0.18]);

% Slider pour la position temporelle
timeSlider = uicontrol('Parent', timePanel, 'Style', 'slider', ...
    'Min', 0, 'Max', 100, 'Value', 0, ...
    'Position', [120, 80, 1100, 20], ...
    'Callback', @timeSliderChanged);

timeText = uicontrol('Parent', timePanel, 'Style', 'text', ...
    'String', '0.0 s', 'Position', [1230, 80, 80, 20], ...
    'HorizontalAlignment', 'left');

uicontrol('Parent', timePanel, 'Style', 'text', ...
    'String', 'Temps:', 'Position', [70, 80, 50, 20], ...
    'HorizontalAlignment', 'right');

% Contrôles de lecture (séparés horizontalement)
btnPlay = uicontrol('Parent', timePanel, 'Style', 'pushbutton', ...
    'String', '▶️', 'Position', [250, 40, 60, 30], ...
    'Callback', @togglePlayback, 'FontSize', 14);

btnReset = uicontrol('Parent', timePanel, 'Style', 'pushbutton', ...
    'String', '⏮️', 'Position', [170, 40, 60, 30], ...
    'Callback', @resetPlayback, 'FontSize', 14);

btnEnd = uicontrol('Parent', timePanel, 'Style', 'pushbutton', ...
    'String', '⏭️', 'Position', [330, 40, 60, 30], ...
    'Callback', @endPlayback, 'FontSize', 14);

% Vitesse de lecture (repositionné)
uicontrol('Parent', timePanel, 'Style', 'text', ...
    'String', 'Vitesse:', 'Position', [420, 45, 60, 20], ...
    'HorizontalAlignment', 'left');

speedOptions = {'0.25x', '0.5x', '1x', '2x', '5x', '10x'};
speedValues = [0.25, 0.5, 1, 2, 5, 10];

speedDropdown = uicontrol('Parent', timePanel, 'Style', 'popupmenu', ...
    'String', speedOptions, 'Position', [480, 45, 80, 20], ...
    'Value', 3, 'Callback', @changeSpeed);

% Export (repositionné)
btnExportView = uicontrol('Parent', timePanel, 'Style', 'pushbutton', ...
    'String', 'Exporter vue', 'Position', [900, 40, 150, 30], ...
    'Callback', @exportCurrentView);

btnExportAnim = uicontrol('Parent', timePanel, 'Style', 'pushbutton', ...
    'String', 'Exporter animation', 'Position', [1070, 40, 150, 30], ...
    'Callback', @exportAnimation);

% Mode de synchronisation
data.syncMode = 'global'; % 'global' ou 'normalized'

% Fonctions de callback
    function loadTrajectory(~, ~)
        [file, path] = uigetfile('*.mat', 'Sélectionner un fichier de waypoints', 'MultiSelect', 'on');
        if isequal(file, 0)
            return;
        end
        
        % Gérer le cas d'un seul fichier ou plusieurs fichiers
        if ischar(file) % Un seul fichier
            files = {file};
        else % Plusieurs fichiers
            files = file;
        end
        
        % Charger chaque fichier
        for f = 1:length(files)
            currentFile = files{f};
            fullPath = fullfile(path, currentFile);
            
            try
                loadedData = load(fullPath);
                fieldNames = fieldnames(loadedData);
                
                % Rechercher la variable WayPts dans le fichier chargé
                wayptsVarName = '';
                for i = 1:length(fieldNames)
                    if strcmpi(fieldNames{i}, 'WayPts') || strcmpi(fieldNames{i}, 'waypts')
                        wayptsVarName = fieldNames{i};
                        break;
                    end
                end
                
                if isempty(wayptsVarName)
                    errordlg(['Aucune variable WayPts trouvée dans ' currentFile], 'Erreur de chargement');
                    continue;
                end
                
                % Vérifier le format des données
                waypts = loadedData.(wayptsVarName);
                [rows, cols] = size(waypts);
                
                if cols < 7
                    errordlg(['Format de waypoints non supporté dans ' currentFile], 'Erreur de format');
                    continue;
                end
                
                % Créer une nouvelle trajectoire
                newTraj = struct();
                [~, name, ~] = fileparts(currentFile);
                newTraj.name = name;
                newTraj.waypoints = waypts;
                newTraj.color = data.colorMap{mod(length(data.trajectories), length(data.colorMap))+1};
                newTraj.visible = true;
                newTraj.startTime = min(waypts(:, 1));
                newTraj.endTime = max(waypts(:, 1));
                newTraj.timeOffset = 0;
                newTraj.interpolatedPath = [];
                
                % Calculer le chemin interpolé
                newTraj.interpolatedPath = generateInterpolatedPath(waypts);
                
                % Ajouter la trajectoire à la liste
                data.trajectories{end+1} = newTraj;
                
                setInfoText(['Fichier chargé: ' currentFile]);
            catch err
                errordlg(['Erreur lors du chargement de ' currentFile ': ' err.message], 'Erreur');
            end
        end
        
        % Mettre à jour l'affichage
        updateTrajectoryList();
        updateGlobalTimeRange();
        updateDisplay();
    end

    % Toutes les autres fonctions sont identiques à la version précédente
    % ... (Le reste du code est inchangé)
    
    function removeTrajectory(~, ~)
        % Supprimer les trajectoires sélectionnées
        selected = get(trajectoryList, 'Value');
        if isempty(selected)
            return;
        end
        
        % Récupérer la liste actuelle
        trajectoryNames = get(trajectoryList, 'String');
        
        % Supprimer les trajectoires sélectionnées (en commençant par la fin pour éviter de décaler les indices)
        for i = length(selected):-1:1
            idx = selected(i);
            if idx <= length(data.trajectories)
                data.trajectories(idx) = [];
            end
        end
        
        % Mettre à jour l'affichage
        updateTrajectoryList();
        updateGlobalTimeRange();
        updateDisplay();
        
        setInfoText('Trajectoire(s) supprimée(s)');
    end

    function clearAllTrajectories(~, ~)
        % Effacer toutes les trajectoires
        data.trajectories = {};
        
        % Mettre à jour l'affichage
        updateTrajectoryList();
        cla(ax);
        
        % Réinitialiser le temps
        data.currentTime = 0;
        data.globalStartTime = 0;
        data.globalEndTime = 0;
        timeSlider.Min = 0;
        timeSlider.Max = 100;
        timeSlider.Value = 0;
        timeText.String = '0.0 s';
        
        setInfoText('Toutes les trajectoires ont été effacées');
    end

    function updateDisplay(~, ~)
        % Effacer l'affichage actuel
        cla(ax);
        
        if isempty(data.trajectories)
            return;
        end
        
        % Dessiner le plan du sol si nécessaire
        if get(cbShowGrid, 'Value')
            drawGroundPlane();
        end
        
        % Afficher chaque trajectoire
        for t = 1:length(data.trajectories)
            traj = data.trajectories{t};
            
            if ~traj.visible
                continue;
            end
            
            % Obtenir les positions des waypoints
            waypts = traj.waypoints;
            if isempty(waypts)
                continue;
            end
            
            % Obtenir la couleur de la trajectoire
            color = traj.color;
            
            % Afficher les waypoints
            if get(cbShowWaypoints, 'Value')
                x = waypts(:, 2);
                y = waypts(:, 3);
                z = waypts(:, 4);
                
                % Tracer les waypoints
                scatter3(ax, x, y, z, 50, color, 'filled', 'MarkerEdgeColor', 'k');
                
                % Afficher les labels des waypoints
                if get(cbShowLabels, 'Value')
                    for i = 1:length(x)
                        text(ax, x(i), y(i), z(i) + 1, [traj.name ' #' num2str(i)], ...
                            'FontSize', 8, 'HorizontalAlignment', 'center');
                    end
                end
            end
            
            % Afficher le chemin
            if get(cbShowPath, 'Value') && ~isempty(traj.interpolatedPath)
                plot3(ax, traj.interpolatedPath(:, 1), traj.interpolatedPath(:, 2), ...
                    traj.interpolatedPath(:, 3), color, 'LineWidth', 2);
            end
            
            % Afficher le drone à la position actuelle
            if get(cbShowDrones, 'Value')
                % Obtenir la position et l'orientation actuelles
                effectiveTime = data.currentTime - traj.timeOffset;
                
                % Si en mode normalisé, convertir le temps
                if strcmp(data.syncMode, 'normalized')
                    % Convertir le temps normalisé (0-1) en temps spécifique à la trajectoire
                    normalizedTime = (data.currentTime - data.globalStartTime) / ...
                        (data.globalEndTime - data.globalStartTime);
                    effectiveTime = traj.startTime + normalizedTime * (traj.endTime - traj.startTime);
                end
                
                % Vérifier si le temps est dans la plage de la trajectoire
                if effectiveTime >= traj.startTime && effectiveTime <= traj.endTime
                    [pos, orient] = getCurrentPose(traj, effectiveTime);
                    
                    % Dessiner le drone
                    drawDrone(pos, orient, color, t);
                    
                    % Afficher les traînées si activées
                    if get(cbTrails, 'Value')
                        drawTrail(traj, effectiveTime, color);
                    end
                end
            end
            
            % Afficher le marqueur de temps actuel
            if get(cbShowTimeMarker, 'Value')
                drawTimeMarker(traj);
            end
        end
        
        % Ajuster les limites des axes si nécessaire
        if isempty(get(ax, 'UserData')) || isequal(get(ax, 'UserData'), 'auto')
            adjustAxisLimits();
            set(ax, 'UserData', 'manual');
        end
    end
    
    function drawGroundPlane()
        % Récupérer les limites actuelles
        axLimits = axis(ax);
        
        % Créer le plan au sol (z=0)
        minX = axLimits(1);
        maxX = axLimits(2);
        minY = axLimits(3);
        maxY = axLimits(4);
        
        % Dessiner le plan
        patch([minX, maxX, maxX, minX], [minY, minY, maxY, maxY], [0, 0, 0, 0], ...
            [0.8, 0.8, 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'Tag', 'GroundPlane');
        
        % Ajouter une grille
        gridSpacing = 5;
        
        % Lignes horizontales (dans la direction Y)
        for y = ceil(minY/gridSpacing)*gridSpacing:gridSpacing:floor(maxY/gridSpacing)*gridSpacing
            plot3(ax, [minX, maxX], [y, y], [0, 0], 'Color', [0.6, 0.6, 0.6], 'LineStyle', ':');
        end
        
        % Lignes verticales (dans la direction X)
        for x = ceil(minX/gridSpacing)*gridSpacing:gridSpacing:floor(maxX/gridSpacing)*gridSpacing
            plot3(ax, [x, x], [minY, maxY], [0, 0], 'Color', [0.6, 0.6, 0.6], 'LineStyle', ':');
        end
    end
    
    function toggleGrid(src, ~)
        % Afficher ou masquer la grille
        updateDisplay();
    end
    
    function drawDrone(position, orientation, color, droneIndex)
        % Paramètres du drone
        droneSize = 2; % Taille du drone
        
        % Position du drone
        x = position(1);
        y = position(2);
        z = position(3);
        
        % Orientation du drone (angles d'Euler)
        phi = orientation(1);   % Roll
        theta = orientation(2); % Pitch
        psi = orientation(3);   % Yaw
        
        % Créer la matrice de rotation
        R = eul2rotm([psi, theta, phi], 'ZYX');
        
        % Points pour le corps du drone (quadcopter simple)
        points = droneSize * [
             1,  0,  0;  % Avant
             0,  1,  0;  % Droite
            -1,  0,  0;  % Arrière
             0, -1,  0;  % Gauche
             0,  0,  0.5;  % Haut
             0,  0, -0.5]; % Bas
        
        % Appliquer la rotation
        rotatedPoints = (R * points')';
        
        % Translater à la position du drone
        rotatedPoints = rotatedPoints + repmat([x, y, z], size(rotatedPoints, 1), 1);
        
        % Dessiner le corps du drone (forme d'un X)
        plot3(ax, [rotatedPoints(1,1), rotatedPoints(3,1)], ...
                 [rotatedPoints(1,2), rotatedPoints(3,2)], ...
                 [rotatedPoints(1,3), rotatedPoints(3,3)], ...
                 'Color', color, 'LineWidth', 2);
        
        plot3(ax, [rotatedPoints(2,1), rotatedPoints(4,1)], ...
                 [rotatedPoints(2,2), rotatedPoints(4,2)], ...
                 [rotatedPoints(2,3), rotatedPoints(4,3)], ...
                 'Color', color, 'LineWidth', 2);
        
        % Dessiner la direction (avant du drone)
        plot3(ax, [x, rotatedPoints(1,1)], ...
                 [y, rotatedPoints(1,2)], ...
                 [z, rotatedPoints(1,3)], ...
                 'Color', 'g', 'LineWidth', 2);
        
        % Ajouter un label au drone
        if get(cbShowLabels, 'Value')
            text(ax, x, y, z+droneSize, ['Drone ' num2str(droneIndex)], ...
                'Color', color, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        end
        
        % Dessiner les axes du drone si demandé
        if get(cbShowAxes, 'Value')
            % Longueur des axes
            axisLength = droneSize * 1.5;
            
            % Axes x, y, z dans le repère du drone
            xAxis = R * [axisLength; 0; 0];
            yAxis = R * [0; axisLength; 0];
            zAxis = R * [0; 0; axisLength];
            
            % Dessiner les axes
            plot3(ax, [x, x+xAxis(1)], [y, y+xAxis(2)], [z, z+xAxis(3)], 'r-', 'LineWidth', 1.5);
            plot3(ax, [x, x+yAxis(1)], [y, y+yAxis(2)], [z, z+yAxis(3)], 'g-', 'LineWidth', 1.5);
            plot3(ax, [x, x+zAxis(1)], [y, y+zAxis(2)], [z, z+zAxis(3)], 'b-', 'LineWidth', 1.5);
            
            % Ajouter des étiquettes
            text(ax, x+xAxis(1), y+xAxis(2), z+xAxis(3), 'X', 'Color', 'r');
            text(ax, x+yAxis(1), y+yAxis(2), z+yAxis(3), 'Y', 'Color', 'g');
            text(ax, x+zAxis(1), y+zAxis(2), z+zAxis(3), 'Z', 'Color', 'b');
        end
    end
    
    function drawTrail(traj, currentTime, color)
        % Dessiner une traînée derrière le drone
        try
            % Longueur de la traînée en secondes
            trailLength = str2double(get(editTrailLength, 'String'));
            if isnan(trailLength) || trailLength <= 0
                trailLength = 5; % Valeur par défaut
            end
            
            % Calculer le temps de début de la traînée
            startTrailTime = max(traj.startTime, currentTime - trailLength);
            
            % Obtenir les positions pour la période de la traînée
            times = traj.interpolatedPath(:, 4); % Colonne du temps
            positions = traj.interpolatedPath(:, 1:3); % Colonnes x, y, z
            
            % Trouver les indices correspondant à la période de la traînée
            trailIndices = find(times >= startTrailTime & times <= currentTime);
            
            if length(trailIndices) > 1
                % Modifier légèrement la couleur pour la traînée
                trailColor = adjustColor(color, 0.7); % Couleur plus claire pour la traînée
                
                % Dessiner la traînée
                trailPositions = positions(trailIndices, :);
                plot3(ax, trailPositions(:, 1), trailPositions(:, 2), trailPositions(:, 3), ...
                    'Color', trailColor, 'LineWidth', 3, 'LineStyle', '-.');
            end
        catch
            % En cas d'erreur, ne pas afficher de traînée
        end
    end
    
    function newColor = adjustColor(colorStr, factor)
        % Convertir la chaîne de couleur en valeurs RGB
        switch colorStr
            case 'b'
                rgb = [0, 0, 1];
            case 'r'
                rgb = [1, 0, 0];
            case 'g'
                rgb = [0, 0.5, 0];
            case 'm'
                rgb = [1, 0, 1];
            case 'c'
                rgb = [0, 1, 1];
            case 'y'
                rgb = [1, 1, 0];
            case 'k'
                rgb = [0, 0, 0];
            otherwise
                rgb = [0, 0, 1]; % Bleu par défaut
        end
        
        % Ajuster la couleur (plus claire ou plus foncée)
        if factor < 1
            % Plus clair
            newColor = rgb + (1 - rgb) * (1 - factor);
        else
            % Plus foncé
            newColor = rgb * factor;
        end
    end
    
    function drawTimeMarker(traj)
        % Afficher un marqueur à la position temporelle actuelle sur la trajectoire
        try
            effectiveTime = data.currentTime - traj.timeOffset;
            
            % Si en mode normalisé, convertir le temps
            if strcmp(data.syncMode, 'normalized')
                normalizedTime = (data.currentTime - data.globalStartTime) / ...
                    (data.globalEndTime - data.globalStartTime);
                effectiveTime = traj.startTime + normalizedTime * (traj.endTime - traj.startTime);
            end
            
            % Vérifier si le temps est dans la plage de la trajectoire
            if effectiveTime >= traj.startTime && effectiveTime <= traj.endTime
                % Trouver la position correspondante
                [pos, ~] = getCurrentPose(traj, effectiveTime);
                
                % Dessiner un marqueur vertical
                plot3(ax, [pos(1), pos(1)], [pos(2), pos(2)], [0, pos(3)], ...
                    'Color', traj.color, 'LineStyle', '--', 'LineWidth', 1);
                
                % Dessiner un cercle à la position au sol
                t = linspace(0, 2*pi, 20);
                radius = 1;
                xc = pos(1) + radius * cos(t);
                yc = pos(2) + radius * sin(t);
                zc = zeros(size(t));
                plot3(ax, xc, yc, zc, 'Color', traj.color, 'LineWidth', 1);
            end
        catch
            % En cas d'erreur, ne rien afficher
        end
    end
    
    function path = generateInterpolatedPath(waypoints)
        % Générer un chemin interpolé à partir des waypoints
        if size(waypoints, 1) < 2
            path = [];
            return;
        end
        
        % Paramètres d'interpolation
        numPoints = max(500, 10 * size(waypoints, 1));
        
        % Temps d'échantillonnage
        t = linspace(waypoints(1, 1), waypoints(end, 1), numPoints)';
        
        % Interpoler les positions (x, y, z)
        x = interp1(waypoints(:, 1), waypoints(:, 2), t, 'pchip');
        y = interp1(waypoints(:, 1), waypoints(:, 3), t, 'pchip');
        z = interp1(waypoints(:, 1), waypoints(:, 4), t, 'pchip');
        
        % Stocker le chemin interpolé avec les temps
        path = [x, y, z, t];
    end
    
    function [position, orientation] = getCurrentPose(traj, time)
        % Obtenir la position et l'orientation à un temps donné
        waypts = traj.waypoints;
        
        % Position par défaut
        position = [0, 0, 0];
        orientation = [0, 0, 0];
        
        if isempty(waypts)
            return;
        end
        
        % Trouver les waypoints avant et après le temps actuel
        times = waypts(:, 1);
        
        % Si le temps est avant le premier waypoint
        if time <= times(1)
            position = waypts(1, 2:4);
            orientation = waypts(1, 5:7);
            return;
        end
        
        % Si le temps est après le dernier waypoint
        if time >= times(end)
            position = waypts(end, 2:4);
            orientation = waypts(end, 5:7);
            return;
        end
        
        % Interpoler la position
        x = interp1(times, waypts(:, 2), time, 'pchip');
        y = interp1(times, waypts(:, 3), time, 'pchip');
        z = interp1(times, waypts(:, 4), time, 'pchip');
        
        % Interpoler l'orientation (attention aux angles qui tournent)
        phi = unwrap(interp1(times, unwrap(waypts(:, 5)), time, 'pchip'));
        theta = unwrap(interp1(times, unwrap(waypts(:, 6)), time, 'pchip'));
        psi = unwrap(interp1(times, unwrap(waypts(:, 7)), time, 'pchip'));
        
        position = [x, y, z];
        orientation = [phi, theta, psi];
    end
    
    function timeSliderChanged(~, ~)
        % Mettre à jour le temps courant
        data.currentTime = timeSlider.Value;
        
        % Mettre à jour l'affichage du temps
        timeText.String = sprintf('%.1f s', data.currentTime);
        
        % Mettre à jour l'affichage
        updateDisplay();
    end
    
    function togglePlayback(~, ~)
        % Inverser l'état de lecture
        data.isPlaying = ~data.isPlaying;
        
        if data.isPlaying
            % Démarrer la lecture
            btnPlay.String = '⏸️';
            
            % Créer le timer si nécessaire
            if isempty(data.playbackTimer) || ~isvalid(data.playbackTimer)
                data.playbackTimer = timer('ExecutionMode', 'fixedRate', ...
                    'Period', 0.05 / data.playbackRate, ...
                    'TimerFcn', @updatePlayback);
            end
            
            % Démarrer le timer
            start(data.playbackTimer);
        else
            % Arrêter la lecture
            btnPlay.String = '▶️';
            
            % Arrêter le timer s'il existe
            if ~isempty(data.playbackTimer) && isvalid(data.playbackTimer)
                stop(data.playbackTimer);
            end
        end
    end
    
    function updatePlayback(~, ~)
        if ~data.isPlaying || isempty(data.trajectories)
            return;
        end
        
        % Incrémenter le temps
        newTime = data.currentTime + 0.05 * data.playbackRate;
        
        % Vérifier si on a atteint la fin
        if newTime >= data.globalEndTime
            newTime = data.globalEndTime;
            
            % Arrêter la lecture à la fin
            if ~isempty(data.playbackTimer) && isvalid(data.playbackTimer)
                stop(data.playbackTimer);
            end
            data.isPlaying = false;
            btnPlay.String = '▶️';
        end
        
        % Mettre à jour le slider
        timeSlider.Value = newTime;
        data.currentTime = newTime;
        
        % Mettre à jour l'affichage du temps
        timeText.String = sprintf('%.1f s', data.currentTime);
        
        % Mettre à jour l'affichage
        updateDisplay();
    end
    
    function resetPlayback(~, ~)
        % Retourner au début
        timeSlider.Value = data.globalStartTime;
        data.currentTime = data.globalStartTime;
        timeText.String = sprintf('%.1f s', data.currentTime);
        updateDisplay();
    end
    
    function endPlayback(~, ~)
        % Aller à la fin
        timeSlider.Value = data.globalEndTime;
        data.currentTime = data.globalEndTime;
        timeText.String = sprintf('%.1f s', data.currentTime);
        updateDisplay();
    end
    
    function changeSpeed(src, ~)
        % Changer la vitesse de lecture
        selected = get(src, 'Value');
        data.playbackRate = speedValues(selected);
        
        % Mettre à jour la période du timer si actif
        if ~isempty(data.playbackTimer) && isvalid(data.playbackTimer)
            data.playbackTimer.Period = 0.05 / data.playbackRate;
        end
    end
    
    function updateTrajectoryList()
        % Mettre à jour la liste des trajectoires
        if isempty(data.trajectories)
            set(trajectoryList, 'String', {}, 'Value', []);
            return;
        end
        
        names = cell(length(data.trajectories), 1);
        for i = 1:length(data.trajectories)
            traj = data.trajectories{i};
            timeRangeStr = sprintf(' [%.1fs - %.1fs]', traj.startTime, traj.endTime);
            if traj.timeOffset ~= 0
                offsetStr = sprintf(' (offset: %+.1fs)', traj.timeOffset);
            else
                offsetStr = '';
            end
            names{i} = [traj.name timeRangeStr offsetStr];
        end
        
        % Conserver la sélection si possible
        currentSelection = get(trajectoryList, 'Value');
        if isempty(currentSelection) || max(currentSelection) > length(names)
            currentSelection = 1;
        end
        
        set(trajectoryList, 'String', names, 'Value', currentSelection);
    end
    
    function updateGlobalTimeRange()
        % Calculer la plage de temps globale
        if isempty(data.trajectories)
            data.globalStartTime = 0;
            data.globalEndTime = 100;
        else
            % Trouver les temps min et max parmi toutes les trajectoires
            minTime = Inf;
            maxTime = -Inf;
            
            for i = 1:length(data.trajectories)
                traj = data.trajectories{i};
                
                % Appliquer l'offset de temps
                adjStartTime = traj.startTime + traj.timeOffset;
                adjEndTime = traj.endTime + traj.timeOffset;
                
                minTime = min(minTime, adjStartTime);
                maxTime = max(maxTime, adjEndTime);
            end
            
            data.globalStartTime = minTime;
            data.globalEndTime = maxTime;
        end
        
        % Mettre à jour le slider
        if data.globalStartTime == data.globalEndTime
            % Éviter une plage de temps nulle
            data.globalEndTime = data.globalStartTime + 1;
        end
        
        timeSlider.Min = data.globalStartTime;
        timeSlider.Max = data.globalEndTime;
        
        % Réinitialiser la position actuelle si nécessaire
        if data.currentTime < data.globalStartTime || data.currentTime > data.globalEndTime
            data.currentTime = data.globalStartTime;
            timeSlider.Value = data.currentTime;
            timeText.String = sprintf('%.1f s', data.currentTime);
        end
        
        setInfoText(sprintf('Plage de temps: %.1fs - %.1fs', data.globalStartTime, data.globalEndTime));
    end
    
    function syncModeChanged(src, ~)
        % Changer le mode de synchronisation
        if src == rbGlobalTime
            data.syncMode = 'global';
        else
            data.syncMode = 'normalized';
        end
        
        % Mettre à jour l'affichage
        updateDisplay();
        setInfoText(['Mode de synchronisation: ' data.syncMode]);
    end
    
    function applyTimeOffset(~, ~)
        % Appliquer un offset de temps aux trajectoires sélectionnées
        selected = get(trajectoryList, 'Value');
        if isempty(selected)
            warndlg('Sélectionnez au moins une trajectoire.', 'Aucune sélection');
            return;
        end
        
        % Récupérer l'offset
        offsetValue = str2double(get(editTimeOffset, 'String'));
        if isnan(offsetValue)
            errordlg('Veuillez entrer une valeur numérique valide pour l''offset.', 'Erreur');
            return;
        end
        
        % Appliquer l'offset aux trajectoires sélectionnées
        for i = 1:length(selected)
            idx = selected(i);
            if idx <= length(data.trajectories)
                data.trajectories{idx}.timeOffset = offsetValue;
            end
        end
        
        % Mettre à jour l'affichage
        updateTrajectoryList();
        updateGlobalTimeRange();
        updateDisplay();
        
        setInfoText(sprintf('Offset de %.1fs appliqué aux trajectoires sélectionnées', offsetValue));
    end
    
    function adjustAxisLimits()
        if isempty(data.trajectories)
            axis(ax, defaultLimits);
            return;
        end
        
        % Trouver les limites globales pour toutes les trajectoires
        minX = Inf;
        maxX = -Inf;
        minY = Inf;
        maxY = -Inf;
        minZ = Inf;
        maxZ = -Inf;
        
        for t = 1:length(data.trajectories)
            traj = data.trajectories{t};
            
            if ~isempty(traj.waypoints)
                x = traj.waypoints(:, 2);
                y = traj.waypoints(:, 3);
                z = traj.waypoints(:, 4);
                
                minX = min(minX, min(x));
                maxX = max(maxX, max(x));
                minY = min(minY, min(y));
                maxY = max(maxY, max(y));
                minZ = min(minZ, min(z));
                maxZ = max(maxZ, max(z));
            end
        end
        
        if isinf(minX) || isinf(maxX) || isinf(minY) || isinf(maxY) || isinf(minZ) || isinf(maxZ)
            axis(ax, defaultLimits);
            return;
        end
        
        % Ajouter une marge
        margin = 10;
        
        % S'assurer que les limites ne sont pas vides
        if minX == maxX
            minX = minX - 5;
            maxX = maxX + 5;
        end
        if minY == maxY
            minY = minY - 5;
            maxY = maxY + 5;
        end
        if minZ == maxZ
            minZ = max(0, minZ - 2);
            maxZ = maxZ + 5;
        end
        
        % Appliquer les nouvelles limites
        axis(ax, [minX-margin, maxX+margin, minY-margin, maxY+margin, max(0, minZ-margin), maxZ+margin]);
    end
    
    function exportCurrentView(~, ~)
        % Exporter la vue actuelle
        [file, path] = uiputfile({'*.png', 'PNG Image'; '*.jpg', 'JPEG Image'; '*.fig', 'MATLAB Figure'}, ...
            'Exporter la vue actuelle');
        
        if isequal(file, 0)
            return;
        end
        
        fullPath = fullfile(path, file);
        [~, ~, ext] = fileparts(fullPath);
        
        if strcmpi(ext, '.fig')
            % Sauvegarder comme figure MATLAB
            savefig(fig, fullPath);
        else
            % Exporter comme image
            exportgraphics(ax, fullPath, 'Resolution', 300);
        end
        
        setInfoText(['Vue exportée vers: ' fullPath]);
    end
    
    function exportAnimation(~, ~)
        % Exporter une animation
        [file, path] = uiputfile({'*.gif', 'GIF Animation'; '*.avi', 'AVI Video'}, ...
            'Exporter l''animation');
        
        if isequal(file, 0)
            return;
        end
        
        fullPath = fullfile(path, file);
        [~, ~, ext] = fileparts(fullPath);
        
        % Paramètres de l'animation
        frameRate = 30;  % Images par seconde
        duration = data.globalEndTime - data.globalStartTime;  % Durée totale en secondes
        numFrames = ceil(frameRate * duration);
        
        % Créer une barre de progression
        progFig = uifigure('Name', 'Exportation en cours...', 'Position', [300, 300, 400, 150]);
        prog = uiprogressdlg(progFig, 'Title', 'Exportation de l''animation', ...
            'Message', 'Préparation...', 'Value', 0, 'Cancelable', 'on');
        
        try
            % Préparer l'exportation
            if strcmpi(ext, '.gif')
                % Pour GIF
                times = linspace(data.globalStartTime, data.globalEndTime, numFrames);
                
                for i = 1:numFrames
                    if prog.CancelRequested
                        break;
                    end
                    
                    % Mettre à jour la barre de progression
                    prog.Value = i / numFrames;
                    prog.Message = sprintf('Image %d sur %d...', i, numFrames);
                    
                    % Positionner les drones au temps actuel
                    data.currentTime = times(i);
                    timeSlider.Value = data.currentTime;
                    timeText.String = sprintf('%.1f s', data.currentTime);
                    updateDisplay();
                    drawnow;
                    
                    % Capturer l'image
                    frame = getframe(ax);
                    im = frame2im(frame);
                    [imind, cm] = rgb2ind(im, 256);
                    
                    % Écrire dans le fichier GIF
                    if i == 1
                        imwrite(imind, cm, fullPath, 'gif', 'Loopcount', inf, 'DelayTime', 1/frameRate);
                    else
                        imwrite(imind, cm, fullPath, 'gif', 'WriteMode', 'append', 'DelayTime', 1/frameRate);
                    end
                end
            else  % AVI
                % Créer l'objet vidéo
                v = VideoWriter(fullPath);
                v.FrameRate = frameRate;
                open(v);
                
                times = linspace(data.globalStartTime, data.globalEndTime, numFrames);
                
                for i = 1:numFrames
                    if prog.CancelRequested
                        break;
                    end
                    
                    % Mettre à jour la barre de progression
                    prog.Value = i / numFrames;
                    prog.Message = sprintf('Image %d sur %d...', i, numFrames);
                    
                    % Positionner les drones au temps actuel
                    data.currentTime = times(i);
                    timeSlider.Value = data.currentTime;
                    timeText.String = sprintf('%.1f s', data.currentTime);
                    updateDisplay();
                    drawnow;
                    
                    % Capturer l'image et l'ajouter à la vidéo
                    frame = getframe(ax);
                    writeVideo(v, frame);
                end
                
                % Fermer la vidéo
                close(v);
            end
            
            setInfoText(['Animation exportée vers: ' fullPath]);
        catch err
            errordlg(['Erreur lors de l''exportation: ' err.message], 'Erreur');
        end
        
        % Fermer la barre de progression
        close(prog);
        close(progFig);
    end
    
    function setInfoText(msg)
        set(infoText, 'String', msg);
    end

    % Initialiser l'interface
    setInfoText('Prêt. Chargez des trajectoires pour commencer.');
end