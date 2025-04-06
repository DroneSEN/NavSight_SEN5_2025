function EnhancedWaypointGUI
% WAYPOINTGUI - Interface graphique améliorée pour la création et la visualisation de waypoints
%
% Cette application permet:
% 1. De créer graphiquement des waypoints pour les trajectoires de drones
% 2. De charger et visualiser plusieurs trajectoires simultanément
% 3. D'éditer des waypoints existants par glisser-déposer dans l'interface 3D
% 4. D'ajouter des points 3D de référence dans l'environnement à partir d'un fichier .mat
% 5. De sauvegarder les waypoints dans le format (t, x, y, z, phi, theta, psi)

% Initialisation de la figure principale
fig = figure('Name', 'Enhanced Waypoint Editor', 'NumberTitle', 'off', ...
    'Position', [100, 100, 1200, 700], 'MenuBar', 'none', 'Toolbar', 'figure');

% Variables globales pour stocker les données
data = struct();
data.trajectories = {}; % Liste des trajectoires chargées
data.activeTrajectory = 0; % Index de la trajectoire active
data.referencePoints = []; % Points 3D de référence
data.referenceLabels = {}; % Labels des points de référence
data.refPointHandles = []; % Handles des points de référence
data.isDragging = false;
data.selectedWaypoint = []; % [trajectoryIndex, waypointIndex]
data.isModified = false;
data.filename = '';
data.timeMode = 'absolute'; % 'absolute' ou 'delta'

% Structure pour stocker les handles graphiques de chaque trajectoire
data.handles = struct();

% Création des axes pour la visualisation 3D
ax = axes('Parent', fig, 'Position', [0.3, 0.1, 0.65, 0.8]);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');
axis(ax, 'equal');
view(ax, 3);
xlabel(ax, 'X (avant)');
ylabel(ax, 'Y (gauche)');
zlabel(ax, 'Z (haut)');
title(ax, 'Trajectoires de drones');

% Limites par défaut pour la visualisation
defaultLimits = [-10 100 -120 10 -5 40];
axis(ax, defaultLimits);

% Création du panneau de contrôle
controlPanel = uipanel('Title', 'Contrôles', 'Position', [0.01, 0.1, 0.28, 0.8]);

% Liste des trajectoires
uicontrol('Parent', controlPanel, 'Style', 'text', ...
    'String', 'Trajectoires:', 'Position', [10, 520, 150, 20], ...
    'HorizontalAlignment', 'left');

trajectoryList = uicontrol('Parent', controlPanel, 'Style', 'listbox', ...
    'Position', [10, 400, 250, 120], ...
    'Callback', @selectTrajectory);

% Boutons de gestion des trajectoires
btnNew = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
    'String', 'Nouvelle trajectoire', 'Position', [10, 370, 120, 25], ...
    'Callback', @newTrajectory);

btnLoad = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
    'String', 'Charger .mat', 'Position', [140, 370, 120, 25], ...
    'Callback', @loadWaypoints);

btnRemove = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
    'String', 'Supprimer', 'Position', [10, 340, 120, 25], ...
    'Callback', @removeTrajectory);

btnSave = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
    'String', 'Sauvegarder', 'Position', [140, 340, 120, 25], ...
    'Callback', @saveWaypoints);

% Couleurs des trajectoires
uicontrol('Parent', controlPanel, 'Style', 'text', ...
    'String', 'Couleur:', 'Position', [10, 310, 50, 20], ...
    'HorizontalAlignment', 'left');

colorDropdown = uicontrol('Parent', controlPanel, 'Style', 'popupmenu', ...
    'String', {'Bleu', 'Rouge', 'Vert', 'Magenta', 'Cyan', 'Jaune', 'Noir'}, ...
    'Position', [70, 310, 100, 25], ...
    'Callback', @changeTrajectoryColor);

% Visibilité des trajectoires
visibilityCheck = uicontrol('Parent', controlPanel, 'Style', 'checkbox', ...
    'String', 'Visible', 'Position', [180, 310, 80, 20], ...
    'Value', 1, 'Callback', @toggleTrajectoryVisibility);

% Séparateur
uicontrol('Parent', controlPanel, 'Style', 'text', ...
    'String', '____________________________', ...
    'Position', [10, 290, 250, 20], 'ForegroundColor', [0.5 0.5 0.5]);

% Mode de temps
uicontrol('Parent', controlPanel, 'Style', 'text', ...
    'String', 'Mode de temps:', 'Position', [10, 270, 100, 20], ...
    'HorizontalAlignment', 'left');

timeModeGroup = uibuttongroup('Parent', controlPanel, ...
    'Position', [110, 265, 150, 30], ...
    'SelectionChangedFcn', @timeModeSwitched);

radioAbs = uicontrol('Parent', timeModeGroup, 'Style', 'radiobutton', ...
    'String', 'Absolu', 'Position', [10, 5, 60, 20], ...
    'Value', 1);

radioDelta = uicontrol('Parent', timeModeGroup, 'Style', 'radiobutton', ...
    'String', 'Delta', 'Position', [75, 5, 60, 20]);

% Gestion des waypoints
uicontrol('Parent', controlPanel, 'Style', 'text', ...
    'String', 'Waypoints:', 'Position', [10, 240, 70, 20], ...
    'HorizontalAlignment', 'left');

btnAddWaypoint = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
    'String', 'Ajouter waypoint', 'Position', [10, 210, 120, 25], ...
    'Callback', @addWaypoint);

btnDeleteWaypoint = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
    'String', 'Supprimer waypoint', 'Position', [140, 210, 120, 25], ...
    'Callback', @deleteWaypoint);

% Gestion des points de référence
uicontrol('Parent', controlPanel, 'Style', 'text', ...
    'String', 'Points de référence:', 'Position', [10, 180, 150, 20], ...
    'HorizontalAlignment', 'left');

btnLoadRefPoints = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
    'String', 'Charger points 3D', 'Position', [10, 150, 120, 25], ...
    'Callback', @loadReferencePoints);

btnClearRefPoints = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
    'String', 'Effacer points', 'Position', [140, 150, 120, 25], ...
    'Callback', @clearReferencePoints);

% Options d'affichage
uicontrol('Parent', controlPanel, 'Style', 'text', ...
    'String', 'Options d''affichage:', 'Position', [10, 120, 150, 20], ...
    'HorizontalAlignment', 'left');

cbShowWaypoints = uicontrol('Parent', controlPanel, 'Style', 'checkbox', ...
    'String', 'Afficher les waypoints', 'Position', [10, 95, 150, 20], ...
    'Value', 1, 'Callback', @updatePlot);

cbShowLines = uicontrol('Parent', controlPanel, 'Style', 'checkbox', ...
    'String', 'Afficher les lignes', 'Position', [160, 95, 120, 20], ...
    'Value', 1, 'Callback', @updatePlot);

cbShowLabels = uicontrol('Parent', controlPanel, 'Style', 'checkbox', ...
    'String', 'Afficher les labels', 'Position', [10, 70, 150, 20], ...
    'Value', 1, 'Callback', @updatePlot);

cbShowGroundPlane = uicontrol('Parent', controlPanel, 'Style', 'checkbox', ...
    'String', 'Plan au sol', 'Position', [160, 70, 120, 20], ...
    'Value', 1, 'Callback', @toggleGroundPlane);

% Instructions
instructionText = uicontrol('Parent', controlPanel, 'Style', 'text', ...
    'String', 'Astuce: Cliquez et glissez un waypoint pour le déplacer', ...
    'Position', [10, 40, 250, 20], 'ForegroundColor', [0.4 0.4 0.4], ...
    'HorizontalAlignment', 'left');

% Champ de statut
statusText = uicontrol('Style', 'text', 'Position', [50, 20, 400, 20], ...
    'HorizontalAlignment', 'left', 'String', 'Prêt.');

% Tableau pour afficher les waypoints (déplacé vers la droite)
waypointTable = uitable('Parent', fig, 'Position', [350, 50, 800, 100], ...
    'ColumnName', {'Trajectoire', 'Index', 'Temps', 'X', 'Y', 'Z', 'Phi', 'Theta', 'Psi'}, ...
    'ColumnEditable', [false false true true true true true true true], ...
    'ColumnWidth', {70, 50, 70, 70, 70, 70, 70, 70, 70}, ...
    'CellEditCallback', @waypointEdited, ...
    'CellSelectionCallback', @waypointSelected);

% Initialisation
updateTrajectoryList();
setStatus('Prêt. Créez une nouvelle trajectoire ou chargez un fichier .mat.');

% Configuration d'événements pour le glisser-déposer
set(fig, 'WindowButtonMotionFcn', @mouseMoved);
set(fig, 'WindowButtonUpFcn', @mouseReleased);

% Fonctions de callback
    function selectTrajectory(~, ~)
        % Sélectionner une trajectoire comme active
        selected = get(trajectoryList, 'Value');
        if isempty(selected) || selected > length(data.trajectories)
            return;
        end
        
        data.activeTrajectory = selected;
        updateTable();
        highlightActiveTrajectory();
        setStatus(['Trajectoire ' num2str(selected) ' sélectionnée.']);
    end

    function newTrajectory(~, ~)
        % Créer une nouvelle trajectoire
        newTraj = struct();
        newTraj.name = sprintf('Trajectoire %d', length(data.trajectories) + 1);
        newTraj.waypoints = zeros(1, 7); % t, x, y, z, phi, theta, psi
        newTraj.color = getDefaultColor(length(data.trajectories) + 1);
        newTraj.visible = true;
        newTraj.modified = true;
        newTraj.filename = '';
        
        % Ajouter la nouvelle trajectoire
        data.trajectories{end+1} = newTraj;
        data.activeTrajectory = length(data.trajectories);
        
        % Mettre à jour l'affichage
        updateTrajectoryList();
        updatePlot();
        updateTable();
        
        setStatus('Nouvelle trajectoire créée.');
    end

    function removeTrajectory(~, ~)
        % Supprimer la trajectoire sélectionnée
        if data.activeTrajectory == 0 || data.activeTrajectory > length(data.trajectories)
            warndlg('Veuillez sélectionner une trajectoire à supprimer.', 'Aucune sélection');
            return;
        end
        
        % Demander confirmation si la trajectoire a été modifiée
        if data.trajectories{data.activeTrajectory}.modified
            choice = questdlg('La trajectoire a été modifiée. Êtes-vous sûr de vouloir la supprimer?', ...
                'Confirmer suppression', 'Oui', 'Non', 'Non');
            if strcmp(choice, 'Non')
                return;
            end
        end
        
        % Supprimer la trajectoire
        data.trajectories(data.activeTrajectory) = [];
        
        % Mettre à jour l'index actif
        if data.activeTrajectory > length(data.trajectories)
            data.activeTrajectory = max(1, length(data.trajectories));
        end
        
        % Mettre à jour l'affichage
        updateTrajectoryList();
        updatePlot();
        updateTable();
        
        if isempty(data.trajectories)
            setStatus('Toutes les trajectoires ont été supprimées.');
        else
            setStatus(['Trajectoire supprimée. ' num2str(length(data.trajectories)) ' trajectoires restantes.']);
        end
    end

    function loadWaypoints(~, ~)
        [file, path] = uigetfile('*.mat', 'Sélectionner un fichier de waypoints');
        if isequal(file, 0)
            return;
        end
        
        fullPath = fullfile(path, file);
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
                errordlg('Aucune variable WayPts trouvée dans le fichier', 'Erreur de chargement');
                return;
            end
            
            % Vérifier le format des données
            waypts = loadedData.(wayptsVarName);
            [rows, cols] = size(waypts);
            
            if cols < 7
                errordlg('Format de waypoints non supporté. Format attendu: (t, x, y, z, phi, theta, psi)', 'Erreur de format');
                return;
            end
            
            % Créer une nouvelle trajectoire avec les waypoints chargés
            newTraj = struct();
            [~, name, ~] = fileparts(file);
            newTraj.name = name;
            newTraj.waypoints = waypts;
            newTraj.color = getDefaultColor(length(data.trajectories) + 1);
            newTraj.visible = true;
            newTraj.modified = false;
            newTraj.filename = fullPath;
            
            % Ajouter la nouvelle trajectoire
            data.trajectories{end+1} = newTraj;
            data.activeTrajectory = length(data.trajectories);
            
            % Mettre à jour l'affichage
            updateTrajectoryList();
            updatePlot();
            updateTable();
            
            % Ajuster les limites des axes pour inclure tous les waypoints
            adjustAxisLimits();
            
            setStatus(['Fichier chargé: ' file]);
        catch err
            errordlg(['Erreur lors du chargement: ' err.message], 'Erreur');
        end
    end

    function saveWaypoints(~, ~)
        if data.activeTrajectory == 0 || data.activeTrajectory > length(data.trajectories)
            warndlg('Veuillez sélectionner une trajectoire à sauvegarder.', 'Aucune sélection');
            return;
        end
        
        traj = data.trajectories{data.activeTrajectory};
        if isempty(traj.filename)
            [file, path] = uiputfile('*.mat', 'Sauvegarder les waypoints');
            if isequal(file, 0)
                return;
            end
            traj.filename = fullfile(path, file);
            data.trajectories{data.activeTrajectory}.filename = traj.filename;
        end
        
        try
            WayPts = traj.waypoints;
            save(traj.filename, 'WayPts');
            data.trajectories{data.activeTrajectory}.modified = false;
            updateTrajectoryList();
            setStatus(['Sauvegardé dans: ' traj.filename]);
        catch err
            errordlg(['Erreur lors de la sauvegarde: ' err.message], 'Erreur');
        end
    end

    function changeTrajectoryColor(~, ~)
        if data.activeTrajectory == 0 || data.activeTrajectory > length(data.trajectories)
            return;
        end
        
        colorIndex = get(colorDropdown, 'Value');
        colorMap = {'blue', 'red', 'green', 'magenta', 'cyan', 'yellow', 'black'};
        
        data.trajectories{data.activeTrajectory}.color = colorMap{colorIndex};
        updatePlot();
    end

    function toggleTrajectoryVisibility(~, ~)
        if data.activeTrajectory == 0 || data.activeTrajectory > length(data.trajectories)
            return;
        end
        
        data.trajectories{data.activeTrajectory}.visible = get(visibilityCheck, 'Value');
        updatePlot();
    end

    function timeModeSwitched(~, event)
        oldMode = data.timeMode;
        
        if event.NewValue == radioAbs
            data.timeMode = 'absolute';
        else
            data.timeMode = 'delta';
        end
        
        % Si on a changé de mode et qu'on a une trajectoire active
        if ~strcmp(oldMode, data.timeMode) && data.activeTrajectory > 0
            traj = data.trajectories{data.activeTrajectory};
            
            if ~isempty(traj.waypoints)
                if strcmp(data.timeMode, 'delta')
                    % Convertir de absolu à delta
                    deltaWayPts = traj.waypoints;
                    for i = size(traj.waypoints, 1):-1:2
                        deltaWayPts(i, 1) = traj.waypoints(i, 1) - traj.waypoints(i-1, 1);
                    end
                    data.trajectories{data.activeTrajectory}.waypoints = deltaWayPts;
                else
                    % Convertir de delta à absolu
                    absWayPts = traj.waypoints;
                    for i = 2:size(traj.waypoints, 1)
                        absWayPts(i, 1) = absWayPts(i-1, 1) + traj.waypoints(i, 1);
                    end
                    data.trajectories{data.activeTrajectory}.waypoints = absWayPts;
                end
                
                data.trajectories{data.activeTrajectory}.modified = true;
                updateTrajectoryList();
                updateTable();
                setStatus(['Mode de temps changé à: ' data.timeMode]);
            end
        end
    end

    function addWaypoint(~, ~)
        if data.activeTrajectory == 0 || data.activeTrajectory > length(data.trajectories)
            warndlg('Veuillez sélectionner une trajectoire active.', 'Aucune trajectoire active');
            return;
        end
        
        traj = data.trajectories{data.activeTrajectory};
        
        % Ajouter un waypoint à la fin
        if isempty(traj.waypoints) || size(traj.waypoints, 1) == 0
            newWaypoint = [0, 0, 0, 0, 0, 0, 0]; % t, x, y, z, phi, theta, psi
        else
            lastWaypoint = traj.waypoints(end, :);
            
            if strcmp(data.timeMode, 'absolute')
                newTime = lastWaypoint(1) + 5; % Ajout de 5 secondes par défaut
            else
                newTime = 5; % Delta de 5 secondes par défaut
            end
            
            % Garder la position et l'orientation du dernier waypoint, ou ajouter un petit offset
            newWaypoint = [newTime, lastWaypoint(2)+2, lastWaypoint(3), lastWaypoint(4), lastWaypoint(5:7)];
        end
        
        data.trajectories{data.activeTrajectory}.waypoints = [traj.waypoints; newWaypoint];
        data.trajectories{data.activeTrajectory}.modified = true;
        
        updatePlot();
        updateTable();
        updateTrajectoryList();
        
        setStatus('Waypoint ajouté.');
    end

    function deleteWaypoint(~, ~)
        if isempty(data.selectedWaypoint) || data.selectedWaypoint(1) == 0 || data.selectedWaypoint(2) == 0
            warndlg('Veuillez sélectionner un waypoint à supprimer.', 'Aucun waypoint sélectionné');
            return;
        end
        
        trajIndex = data.selectedWaypoint(1);
        waypointIndex = data.selectedWaypoint(2);
        
        if trajIndex > length(data.trajectories)
            return;
        end
        
        traj = data.trajectories{trajIndex};
        
        if waypointIndex > size(traj.waypoints, 1)
            return;
        end
        
        % Supprimer le waypoint
        if size(traj.waypoints, 1) <= 1
            % Si c'est le dernier waypoint, ne pas le supprimer
            warndlg('Impossible de supprimer le dernier waypoint d''une trajectoire.', 'Opération impossible');
            return;
        end
        
        % Supprimer le waypoint
        data.trajectories{trajIndex}.waypoints(waypointIndex, :) = [];
        data.trajectories{trajIndex}.modified = true;
        
        % Réinitialiser la sélection
        data.selectedWaypoint = [0, 0];
        
        updatePlot();
        updateTable();
        updateTrajectoryList();
        
        setStatus(['Waypoint ' num2str(waypointIndex) ' supprimé de la trajectoire ' num2str(trajIndex) '.']);
    end

    function loadReferencePoints(~, ~)
        % Charger les points 3D depuis un fichier .mat contenant mapPointSet.WorldPoints
        [file, path] = uigetfile('*.mat', 'Sélectionner un fichier de points 3D');
        if isequal(file, 0)
            return;
        end
        fullPath = fullfile(path, file);
        try
            % Charger les données du fichier .mat
            loadedData = load(fullPath);
            % Afficher les variables disponibles
            disp('Variables disponibles dans le fichier .mat:');
            disp(fieldnames(loadedData));
            worldPoints = [];
            % Vérifie si la variable mapPointSet existe
            if isfield(loadedData, 'mapPointSet')
                disp('mapPointSet trouvé');
                mapPointSet = loadedData.mapPointSet;
                % Vérifie si c'est un objet avec la propriété WorldPoints
                if isprop(mapPointSet, 'WorldPoints')
                    disp('mapPointSet.WorldPoints trouvé');
                    worldPoints = mapPointSet.WorldPoints;
                else
                    disp('La propriété WorldPoints nexiste pas dans mapPointSet');
                end
            end
            % Recherche générique si worldPoints est toujours vide
            if isempty(worldPoints)
                disp('Recherche plus générale de points 3D...');
                fields = fieldnames(loadedData);
                for i = 1:length(fields)
                    var = loadedData.(fields{i});
                    % Vérifie si c'est un tableau de points directement
                    if isnumeric(var) && size(var, 2) == 3
                        disp(['Points XYZ potentiels trouvés dans ' fields{i}]);
                        worldPoints = var;
                        break;
                    end
                    % Si c'est une structure ou objet avec WorldPoints
                    if isstruct(var) || isobject(var)
                        if isprop(var, 'WorldPoints') && isnumeric(var.WorldPoints)
                            disp(['Points XYZ trouvés dans ' fields{i} '.WorldPoints']);
                            worldPoints = var.WorldPoints;
                            break;
                        end
                    end
                end
            end
            if isempty(worldPoints)
                errordlg('Aucun point 3D trouvé dans le fichier. Vérifiez la structure du fichier .mat.', 'Points non trouvés');
                return;
            end
            % Stocker les points de référence
            data.referencePoints = worldPoints;
            % Limite d'affichage
            if size(worldPoints, 1) > 1000
                warning('Nombre de points très élevé (%d). Affichage limité aux 1000 premiers points.', size(worldPoints, 1));
                data.referencePoints = worldPoints(1:1000, :);
            end
            % Mise à jour de l'affichage
            drawReferencePoints();
            adjustAxisLimits();
            setStatus(['Chargé ' num2str(size(data.referencePoints, 1)) ' points 3D depuis ' file]);
        catch err
            errordlg(['Erreur lors du chargement: ' err.message], 'Erreur');
            disp(['Détails de l''erreur: ' err.message]);
            disp(getReport(err, 'extended'));
        end
    end
    



    function clearReferencePoints(~, ~)
        % Effacer tous les points de référence
        data.referencePoints = [];
        data.referenceLabels = {};
        
        % Supprimer les handles des points
        if ~isempty(data.refPointHandles)
            for i = 1:length(data.refPointHandles)
                if ishandle(data.refPointHandles(i))
                    delete(data.refPointHandles(i));
                end
            end
            data.refPointHandles = [];
        end
        
        setStatus('Points de référence effacés.');
    end

    function toggleGroundPlane(src, ~)
        % Afficher ou masquer le plan au sol
        showPlane = get(src, 'Value');
        
        % Chercher le handle du plan au sol
        groundHandle = findobj(ax, 'Tag', 'GroundPlane');
        
        if showPlane && isempty(groundHandle)
            % Créer le plan
            drawGroundPlane();
        elseif ~showPlane && ~isempty(groundHandle)
            % Supprimer le plan
            delete(groundHandle);
        end
    end

    function waypointEdited(src, event)
        row = event.Indices(1);
        col = event.Indices(2);
        
        % Le tableau inclut maintenant une colonne pour l'index de trajectoire
        if col == 1
            % Ne pas permettre l'édition de l'index de trajectoire
            return;
        end
        
        % Récupérer les données du tableau
        tableData = get(src, 'Data');
        trajIndex = tableData{row, 1};
        
        if trajIndex <= 0 || trajIndex > length(data.trajectories)
            return;
        end
        
        waypointIndex = tableData{row, 2};
        
        if waypointIndex <= 0 || waypointIndex > size(data.trajectories{trajIndex}.waypoints, 1)
            return;
        end
        
        % Mise à jour de la valeur dans la structure de données
        % Col 1 = index de trajectoire, Col 2 = index de waypoint, les autres cols correspondent aux waypoints
        if col > 2
            realCol = col - 2; % Ajustement pour trouver la colonne dans les waypoints
            data.trajectories{trajIndex}.waypoints(waypointIndex, realCol) = event.NewData;
            data.trajectories{trajIndex}.modified = true;
            
            % Mettre à jour la liste des trajectoires pour indiquer que celle-ci a été modifiée
            updateTrajectoryList();
            
            % Si le temps a été modifié et qu'on est en mode absolu,
            % vérifier que les temps sont toujours croissants
            if realCol == 1 && strcmp(data.timeMode, 'absolute')
                times = data.trajectories{trajIndex}.waypoints(:, 1);
                if ~issorted(times)
                    warndlg('Les temps doivent être croissants en mode absolu!', 'Avertissement');
                    % Restaurer l'ancienne valeur
                    data.trajectories{trajIndex}.waypoints(waypointIndex, 1) = event.PreviousData;
                    updateTable();
                    return;
                end
            end
            
            % Mise à jour du graphique
            updatePlot();
            setStatus(['Waypoint ' num2str(waypointIndex) ' de la trajectoire ' num2str(trajIndex) ' modifié.']);
        end
    end

    function waypointSelected(src, event)
        if isempty(event.Indices)
            return;
        end
        
        % Obtenir l'index de la trajectoire et du waypoint sélectionnés
        row = event.Indices(1);
        tableData = get(src, 'Data');
        
        if row > size(tableData, 1)
            return;
        end
        
        trajIndex = tableData{row, 1};
        waypointIndex = tableData{row, 2};
        
        % Stocker la sélection courante
        data.selectedWaypoint = [trajIndex, waypointIndex];
        
        % Surligner le waypoint dans le graphique
        highlightWaypoint(trajIndex, waypointIndex);
    end

    function highlightWaypoint(trajIndex, waypointIndex)
        % Vérifier si la trajectoire existe
        if trajIndex <= 0 || trajIndex > length(data.trajectories)
            return;
        end
        
        % Vérifier si le waypoint existe
        traj = data.trajectories{trajIndex};
        if waypointIndex <= 0 || waypointIndex > size(traj.waypoints, 1)
            return;
        end
        
        % Mettre à jour le graphique pour surligner le waypoint sélectionné
        updatePlot();
        
        % Après la mise à jour, surligner spécifiquement le waypoint sélectionné
        for t = 1:length(data.trajectories)
            if isfield(data.handles, ['traj' num2str(t)]) && isfield(data.handles.(['traj' num2str(t)]), 'waypoints')
                waypointHandles = data.handles.(['traj' num2str(t)]).waypoints;
                
                for w = 1:length(waypointHandles)
                    if t == trajIndex && w == waypointIndex
                        % Agrandir et changer la couleur du waypoint sélectionné
                        set(waypointHandles(w), 'MarkerSize', 12, 'MarkerFaceColor', 'r');
                    else
                        % Restaurer l'apparence des autres waypoints
                        set(waypointHandles(w), 'MarkerSize', 8, 'MarkerFaceColor', data.trajectories{t}.color);
                    end
                end
            end
        end
    end

    function waypointClicked(src, ~)
        % Récupérer les données stockées dans l'UserData
        userData = get(src, 'UserData');
        trajIndex = userData.trajectoryIndex;
        waypointIndex = userData.waypointIndex;
        
        % Sélectionner le waypoint
        data.selectedWaypoint = [trajIndex, waypointIndex];
        highlightWaypoint(trajIndex, waypointIndex);
        
        % Sélectionner dans le tableau
        tableData = get(waypointTable, 'Data');
        for i = 1:size(tableData, 1)
            if tableData{i, 1} == trajIndex && tableData{i, 2} == waypointIndex
                waypointTable.Selection = [i, 1];
                break;
            end
        end
        
        % Marquer le début d'un glisser-déposer
        data.isDragging = true;
    end

    function mouseMoved(~, ~)
        if data.isDragging && ~isempty(data.selectedWaypoint) && all(data.selectedWaypoint > 0)
            trajIndex = data.selectedWaypoint(1);
            waypointIndex = data.selectedWaypoint(2);
            
            if trajIndex <= 0 || trajIndex > length(data.trajectories)
                return;
            end
            
            traj = data.trajectories{trajIndex};
            if waypointIndex <= 0 || waypointIndex > size(traj.waypoints, 1)
                return;
            end
            
            currPt = get(ax, 'CurrentPoint');
            
            % Obtenir les coordonnées 3D du point courant
            newX = currPt(1, 1);
            newY = currPt(1, 2);
            newZ = currPt(1, 3);
            
            % Mettre à jour les coordonnées du waypoint
            data.trajectories{trajIndex}.waypoints(waypointIndex, 2) = newX;
            data.trajectories{trajIndex}.waypoints(waypointIndex, 3) = newY;
            data.trajectories{trajIndex}.waypoints(waypointIndex, 4) = newZ;
            data.trajectories{trajIndex}.modified = true;
            
            % Mettre à jour l'affichage
            updatePlot();
            updateTable();
            updateTrajectoryList();
            
            % Mettre en évidence le waypoint qui est en train d'être déplacé
            highlightWaypoint(trajIndex, waypointIndex);
        end
    end

    function mouseReleased(~, ~)
        if data.isDragging
            data.isDragging = false;
            if ~isempty(data.selectedWaypoint) && all(data.selectedWaypoint > 0)
                setStatus(sprintf('Waypoint %d de la trajectoire %d déplacé.', ...
                    data.selectedWaypoint(2), data.selectedWaypoint(1)));
            end
        end
    end

    function updatePlot(~, ~)
        % Effacer l'affichage actuel
        cla(ax);
        
        % Créer un handle pour chaque trajectoire
        for t = 1:length(data.trajectories)
            traj = data.trajectories{t};
            
            % Vérifier si la trajectoire est visible
            if ~traj.visible
                continue;
            end
            
            % Créer un champ pour cette trajectoire si nécessaire
            if ~isfield(data.handles, ['traj' num2str(t)])
                data.handles.(['traj' num2str(t)]) = struct();
            end
            
            % Obtenir les positions des waypoints
            waypts = traj.waypoints;
            if isempty(waypts)
                continue;
            end
            
            x = waypts(:, 2);
            y = waypts(:, 3);
            z = waypts(:, 4);
            
            % Obtenir la couleur de la trajectoire
            colorName = traj.color;
            color = getColorCode(colorName);
            
            % Tracer la ligne reliant les waypoints
            if get(cbShowLines, 'Value')
                data.handles.(['traj' num2str(t)]).line = plot3(ax, x, y, z, ...
                    'Color', color, 'LineWidth', 2);
            end
            
            % Tracer les waypoints comme des points
            if get(cbShowWaypoints, 'Value')
                for i = 1:length(x)
                    % Tracer le waypoint
                    data.handles.(['traj' num2str(t)]).waypoints(i) = plot3(ax, x(i), y(i), z(i), 'o', ...
                        'MarkerSize', 8, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', color, ...
                        'ButtonDownFcn', @waypointClicked, ...
                        'UserData', struct('trajectoryIndex', t, 'waypointIndex', i));
                    
                    % Ajouter un label avec le numéro du waypoint
                    if get(cbShowLabels, 'Value')
                        data.handles.(['traj' num2str(t)]).labels(i) = text(ax, x(i), y(i), z(i) + 1, ...
                            num2str(i), 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                            'Color', 'k');
                    end
                end
            end
        end
        
        % Dessiner les points de référence
        drawReferencePoints();
        
        % Dessiner le plan du sol si nécessaire
        if get(cbShowGroundPlane, 'Value')
            drawGroundPlane();
        end
        
        % Surligner la trajectoire active
        highlightActiveTrajectory();
    end
    
    function drawReferencePoints()
        % Supprimer les anciens points de référence
        if ~isempty(data.refPointHandles)
            for i = 1:length(data.refPointHandles)
                if ishandle(data.refPointHandles(i))
                    delete(data.refPointHandles(i));
                end
            end
            data.refPointHandles = [];
        end
        
        % Dessiner les nouveaux points de référence
        if ~isempty(data.referencePoints)
            % Utiliser scatter3 pour afficher tous les points en une seule fois
            data.refPointHandles = scatter3(ax, ...
                data.referencePoints(:, 1), ...
                data.referencePoints(:, 2), ...
                data.referencePoints(:, 3), ...
                10, ... % Taille des points
                'ks', ... % Style de point carré noir
                'MarkerFaceColor', 'y'); % Remplissage jaune
        end
    end
    
    function drawGroundPlane()
        % Trouver les limites actuelles des axes
        axLimits = axis(ax);
        
        % Définir les limites du plan
        minX = axLimits(1);
        maxX = axLimits(2);
        minY = axLimits(3);
        maxY = axLimits(4);
        
        % Créer le plan du sol (z=0)
        patch('XData', [minX, maxX, maxX, minX], ...
              'YData', [minY, minY, maxY, maxY], ...
              'ZData', [0, 0, 0, 0], ...
              'FaceColor', [0.9, 0.9, 0.9], ...
              'EdgeColor', [0.7, 0.7, 0.7], ...
              'FaceAlpha', 0.3, ...
              'Parent', ax, ...
              'Tag', 'GroundPlane');
        
        % Ajouter une grille sur le plan
        gridSpacing = 5;
        
        % Lignes horizontales
        for y = ceil(minY/gridSpacing)*gridSpacing:gridSpacing:floor(maxY/gridSpacing)*gridSpacing
            plot3(ax, [minX, maxX], [y, y], [0, 0], 'Color', [0.7, 0.7, 0.7], 'LineStyle', ':');
        end
        
        % Lignes verticales
        for x = ceil(minX/gridSpacing)*gridSpacing:gridSpacing:floor(maxX/gridSpacing)*gridSpacing
            plot3(ax, [x, x], [minY, maxY], [0, 0], 'Color', [0.7, 0.7, 0.7], 'LineStyle', ':');
        end
    end
    
    function highlightActiveTrajectory()
        % Mettre en évidence la trajectoire active
        if data.activeTrajectory > 0 && data.activeTrajectory <= length(data.trajectories)
            for t = 1:length(data.trajectories)
                if isfield(data.handles, ['traj' num2str(t)])
                    trajHandles = data.handles.(['traj' num2str(t)]);
                    
                    if isfield(trajHandles, 'line') && ishandle(trajHandles.line)
                        if t == data.activeTrajectory
                            % Rendre la ligne de la trajectoire active plus épaisse
                            set(trajHandles.line, 'LineWidth', 3);
                        else
                            set(trajHandles.line, 'LineWidth', 2);
                        end
                    end
                end
            end
            
            % Mettre à jour la couleur et la visibilité dans l'interface
            colorMap = {'blue', 'red', 'green', 'magenta', 'cyan', 'yellow', 'black'};
            colorNames = {'Bleu', 'Rouge', 'Vert', 'Magenta', 'Cyan', 'Jaune', 'Noir'};
            
            traj = data.trajectories{data.activeTrajectory};
            colorIndex = find(strcmp(colorMap, traj.color));
            if ~isempty(colorIndex)
                set(colorDropdown, 'Value', colorIndex);
            end
            
            set(visibilityCheck, 'Value', traj.visible);
        end
    end
    
    function updateTable()
        % Mettre à jour le tableau avec les waypoints de toutes les trajectoires visibles
        tableData = {};
        rowCount = 0;
        
        for t = 1:length(data.trajectories)
            traj = data.trajectories{t};
            
            if ~traj.visible && t ~= data.activeTrajectory
                continue;
            end
            
            waypts = traj.waypoints;
            
            for w = 1:size(waypts, 1)
                rowCount = rowCount + 1;
                tableData{rowCount, 1} = t; % Index de trajectoire
                tableData{rowCount, 2} = w; % Index de waypoint
                
                for c = 1:7
                    tableData{rowCount, c+2} = waypts(w, c); % Données du waypoint
                end
            end
        end
        
        set(waypointTable, 'Data', tableData);
    end
    
    function updateTrajectoryList()
        % Mettre à jour la liste des trajectoires
        listItems = {};
        
        for t = 1:length(data.trajectories)
            traj = data.trajectories{t};
            
            % Ajouter un indicateur de modification
            modifiedStr = '';
            if traj.modified
                modifiedStr = ' *';
            end
            
            % Ajouter un indicateur de visibilité
            visibleStr = '';
            if ~traj.visible
                visibleStr = ' (masqué)';
            end
            
            listItems{t} = [traj.name modifiedStr visibleStr];
        end
        
        set(trajectoryList, 'String', listItems);
        
        % Sélectionner la trajectoire active
        if data.activeTrajectory > 0 && data.activeTrajectory <= length(listItems)
            set(trajectoryList, 'Value', data.activeTrajectory);
        elseif ~isempty(listItems)
            set(trajectoryList, 'Value', 1);
            data.activeTrajectory = 1;
        else
            set(trajectoryList, 'Value', []);
            data.activeTrajectory = 0;
        end
    end
    
    function adjustAxisLimits()
        % Trouver les limites globales pour toutes les trajectoires visibles
        minX = Inf;
        maxX = -Inf;
        minY = Inf;
        maxY = -Inf;
        minZ = Inf;
        maxZ = -Inf;
        
        pointsFound = false;
        
        % Vérifier les trajectoires
        for t = 1:length(data.trajectories)
            traj = data.trajectories{t};
            
            if ~traj.visible
                continue;
            end
            
            waypts = traj.waypoints;
            
            if ~isempty(waypts)
                minX = min(minX, min(waypts(:, 2)));
                maxX = max(maxX, max(waypts(:, 2)));
                minY = min(minY, min(waypts(:, 3)));
                maxY = max(maxY, max(waypts(:, 3)));
                minZ = min(minZ, min(waypts(:, 4)));
                maxZ = max(maxZ, max(waypts(:, 4)));
                
                pointsFound = true;
            end
        end
        
        % Vérifier les points de référence
        if ~isempty(data.referencePoints)
            minX = min(minX, min(data.referencePoints(:, 1)));
            maxX = max(maxX, max(data.referencePoints(:, 1)));
            minY = min(minY, min(data.referencePoints(:, 2)));
            maxY = max(maxY, max(data.referencePoints(:, 2)));
            minZ = min(minZ, min(data.referencePoints(:, 3)));
            maxZ = max(maxZ, max(data.referencePoints(:, 3)));
            
            pointsFound = true;
        end
        
        if pointsFound
            % Ajouter une marge
            margin = 10;
            
            % Appliquer les nouvelles limites
            axis(ax, [minX-margin, maxX+margin, minY-margin, maxY+margin, minZ-margin, maxZ+margin]);
        else
            % Utiliser les limites par défaut
            axis(ax, defaultLimits);
        end
    end
    
    function setStatus(msg)
        set(statusText, 'String', msg);
    end
    
    function colorCode = getColorCode(colorName)
        % Convertir un nom de couleur en code RGB
        switch lower(colorName)
            case 'blue'
                colorCode = [0, 0, 1];
            case 'red'
                colorCode = [1, 0, 0];
            case 'green'
                colorCode = [0, 0.7, 0];
            case 'magenta'
                colorCode = [1, 0, 1];
            case 'cyan'
                colorCode = [0, 1, 1];
            case 'yellow'
                colorCode = [1, 1, 0];
            case 'black'
                colorCode = [0, 0, 0];
            otherwise
                colorCode = [0, 0, 1]; % Bleu par défaut
        end
    end
    
    function defaultColor = getDefaultColor(index)
        % Obtenir une couleur par défaut en fonction de l'index
        colorMap = {'blue', 'red', 'green', 'magenta', 'cyan', 'yellow', 'black'};
        index = mod(index - 1, length(colorMap)) + 1;
        defaultColor = colorMap{index};
    end
end