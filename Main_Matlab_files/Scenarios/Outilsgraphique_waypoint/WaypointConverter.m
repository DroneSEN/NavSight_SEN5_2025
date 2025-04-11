function WaypointConverter
% WAYPOINTCONVERTER - Convertir les formats de waypoints
%
% Cette application permet:
% 1. De convertir des waypoints entre différents formats
% 2. De fusionner plusieurs fichiers de waypoints
% 3. D'appliquer des transformations (rotation, translation, inversion, etc.)
%
% Formats supportés:
% - (t, x, y, z, phi, theta, psi)
% - (x, y, z, t) format ancien
% - (deltat, x, y, z, psi) format intermédiaire

% Initialisation de la figure principale
fig = figure('Name', 'Waypoint Converter', 'NumberTitle', 'off', ...
    'Position', [100, 100, 800, 600], 'MenuBar', 'none', 'Toolbar', 'none');

% Variables globales
data.inputWayPts = {};  % Cellule contenant plusieurs ensembles de waypoints
data.outputWayPts = [];
data.inputFormat = 'standard'; % 'standard', 'legacy', 'delta'
data.outputFormat = 'standard';

% Création du panneau principal
mainPanel = uipanel('Parent', fig, 'Title', 'Convertisseur de Waypoints', ...
    'Position', [0.02, 0.02, 0.96, 0.96]);

% Zone d'entrée
inputPanel = uipanel('Parent', mainPanel, 'Title', 'Fichiers d''entrée', ...
    'Position', [0.05, 0.55, 0.9, 0.4]);

% Liste des fichiers chargés
fileListBox = uicontrol('Parent', inputPanel, 'Style', 'listbox', ...
    'Position', [20, 100, 350, 120], ...
    'String', {}, 'Max', 2); % Max = 2 pour permettre sélection multiple

% Boutons pour gérer les fichiers
btnLoad = uicontrol('Parent', inputPanel, 'Style', 'pushbutton', ...
    'String', 'Charger fichier...', 'Position', [390, 190, 120, 30], ...
    'Callback', @loadWaypointFile);

btnRemove = uicontrol('Parent', inputPanel, 'Style', 'pushbutton', ...
    'String', 'Supprimer', 'Position', [390, 150, 120, 30], ...
    'Callback', @removeSelectedFile);

btnClear = uicontrol('Parent', inputPanel, 'Style', 'pushbutton', ...
    'String', 'Tout effacer', 'Position', [390, 110, 120, 30], ...
    'Callback', @clearAllFiles);

% Format d'entrée
uicontrol('Parent', inputPanel, 'Style', 'text', ...
    'String', 'Format d''entrée:', 'Position', [20, 70, 100, 20], ...
    'HorizontalAlignment', 'left');

inputFormatDropdown = uicontrol('Parent', inputPanel, 'Style', 'popupmenu', ...
    'String', {'Standard (t,x,y,z,phi,theta,psi)', 'Ancien (x,y,z,t)', 'Delta (deltat,x,y,z,psi)'}, ...
    'Position', [130, 70, 240, 20], 'Value', 1, ...
    'Callback', @inputFormatChanged);

% Informations sur les waypoints chargés
uicontrol('Parent', inputPanel, 'Style', 'text', ...
    'String', 'Info:', 'Position', [20, 40, 40, 20], ...
    'HorizontalAlignment', 'left');

waypointInfoText = uicontrol('Parent', inputPanel, 'Style', 'text', ...
    'String', 'Aucun fichier chargé', 'Position', [70, 40, 300, 20], ...
    'HorizontalAlignment', 'left');

% Zone de transformation
transformPanel = uipanel('Parent', mainPanel, 'Title', 'Transformations', ...
    'Position', [0.05, 0.3, 0.9, 0.22]);

% Options de transformation
uicontrol('Parent', transformPanel, 'Style', 'text', ...
    'String', 'Opérations:', 'Position', [20, 100, 100, 20], ...
    'HorizontalAlignment', 'left');

cbCombine = uicontrol('Parent', transformPanel, 'Style', 'checkbox', ...
    'String', 'Combiner les fichiers', 'Position', [120, 100, 150, 20], ...
    'Value', 0);

cbInvert = uicontrol('Parent', transformPanel, 'Style', 'checkbox', ...
    'String', 'Inverser le trajet', 'Position', [270, 100, 150, 20], ...
    'Value', 0);

cbNormalize = uicontrol('Parent', transformPanel, 'Style', 'checkbox', ...
    'String', 'Normaliser le temps (commencer à 0)', 'Position', [420, 100, 220, 20], ...
    'Value', 0);

% Translation
uicontrol('Parent', transformPanel, 'Style', 'text', ...
    'String', 'Translation:', 'Position', [20, 70, 100, 20], ...
    'HorizontalAlignment', 'left');

uicontrol('Parent', transformPanel, 'Style', 'text', ...
    'String', 'X:', 'Position', [120, 70, 20, 20], ...
    'HorizontalAlignment', 'left');

editTransX = uicontrol('Parent', transformPanel, 'Style', 'edit', ...
    'String', '0', 'Position', [140, 70, 50, 20]);

uicontrol('Parent', transformPanel, 'Style', 'text', ...
    'String', 'Y:', 'Position', [200, 70, 20, 20], ...
    'HorizontalAlignment', 'left');

editTransY = uicontrol('Parent', transformPanel, 'Style', 'edit', ...
    'String', '0', 'Position', [220, 70, 50, 20]);

uicontrol('Parent', transformPanel, 'Style', 'text', ...
    'String', 'Z:', 'Position', [280, 70, 20, 20], ...
    'HorizontalAlignment', 'left');

editTransZ = uicontrol('Parent', transformPanel, 'Style', 'edit', ...
    'String', '0', 'Position', [300, 70, 50, 20]);

% Rotation
uicontrol('Parent', transformPanel, 'Style', 'text', ...
    'String', 'Rotation (deg):', 'Position', [20, 40, 100, 20], ...
    'HorizontalAlignment', 'left');

uicontrol('Parent', transformPanel, 'Style', 'text', ...
    'String', 'Phi:', 'Position', [120, 40, 30, 20], ...
    'HorizontalAlignment', 'left');

editRotPhi = uicontrol('Parent', transformPanel, 'Style', 'edit', ...
    'String', '0', 'Position', [150, 40, 50, 20]);

uicontrol('Parent', transformPanel, 'Style', 'text', ...
    'String', 'Theta:', 'Position', [210, 40, 40, 20], ...
    'HorizontalAlignment', 'left');

editRotTheta = uicontrol('Parent', transformPanel, 'Style', 'edit', ...
    'String', '0', 'Position', [250, 40, 50, 20]);

uicontrol('Parent', transformPanel, 'Style', 'text', ...
    'String', 'Psi:', 'Position', [310, 40, 30, 20], ...
    'HorizontalAlignment', 'left');

editRotPsi = uicontrol('Parent', transformPanel, 'Style', 'edit', ...
    'String', '0', 'Position', [340, 40, 50, 20]);

% Facteur d'échelle pour le temps
uicontrol('Parent', transformPanel, 'Style', 'text', ...
    'String', 'Facteur temps:', 'Position', [410, 40, 100, 20], ...
    'HorizontalAlignment', 'left');

editTimeScale = uicontrol('Parent', transformPanel, 'Style', 'edit', ...
    'String', '1.0', 'Position', [510, 40, 50, 20]);

% Bouton pour appliquer les transformations
btnApply = uicontrol('Parent', transformPanel, 'Style', 'pushbutton', ...
    'String', 'Appliquer', 'Position', [520, 10, 100, 25], ...
    'Callback', @applyTransformations);

% Zone de sortie
outputPanel = uipanel('Parent', mainPanel, 'Title', 'Sortie', ...
    'Position', [0.05, 0.05, 0.9, 0.22]);

% Format de sortie
uicontrol('Parent', outputPanel, 'Style', 'text', ...
    'String', 'Format de sortie:', 'Position', [20, 60, 100, 20], ...
    'HorizontalAlignment', 'left');

outputFormatDropdown = uicontrol('Parent', outputPanel, 'Style', 'popupmenu', ...
    'String', {'Standard (t,x,y,z,phi,theta,psi)', 'Ancien (x,y,z,t)', 'Delta (deltat,x,y,z,psi)'}, ...
    'Position', [130, 60, 240, 20], 'Value', 1, ...
    'Callback', @outputFormatChanged);

% Boutons de sortie
btnPreview = uicontrol('Parent', outputPanel, 'Style', 'pushbutton', ...
    'String', 'Aperçu', 'Position', [400, 60, 100, 25], ...
    'Callback', @previewOutput);

btnSave = uicontrol('Parent', outputPanel, 'Style', 'pushbutton', ...
    'String', 'Sauvegarder...', 'Position', [520, 60, 100, 25], ...
    'Callback', @saveOutput);

% Informations sur les waypoints de sortie
uicontrol('Parent', outputPanel, 'Style', 'text', ...
    'String', 'Info:', 'Position', [20, 20, 40, 20], ...
    'HorizontalAlignment', 'left');

outputInfoText = uicontrol('Parent', outputPanel, 'Style', 'text', ...
    'String', 'Aucune conversion effectuée', 'Position', [70, 20, 300, 20], ...
    'HorizontalAlignment', 'left');

% Fonctions de callback
    function loadWaypointFile(~, ~)
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
            
            % Récupérer les waypoints
            waypts = loadedData.(wayptsVarName);
            
            % Vérifier et convertir le format si nécessaire
            switch data.inputFormat
                case 'standard'
                    % Format attendu: (t, x, y, z, phi, theta, psi)
                    [rows, cols] = size(waypts);
                    if cols < 7
                        errordlg('Format de waypoints incompatible avec le format standard', 'Erreur de format');
                        return;
                    end
                    % Utiliser tel quel
                    convertedWaypts = waypts;
                    
                case 'legacy'
                    % Format attendu: (x, y, z, t)
                    [rows, cols] = size(waypts);
                    if cols ~= 4
                        errordlg('Format de waypoints incompatible avec le format ancien', 'Erreur de format');
                        return;
                    end
                    % Convertir vers (t, x, y, z, phi, theta, psi)
                    convertedWaypts = [waypts(:, 4), waypts(:, 1:3), zeros(rows, 3)];
                    
                case 'delta'
                    % Format attendu: (deltat, x, y, z, psi)
                    [rows, cols] = size(waypts);
                    if cols < 5
                        errordlg('Format de waypoints incompatible avec le format delta', 'Erreur de format');
                        return;
                    end
                    
                    % Convertir les delta temps en temps absolu
                    absTime = zeros(rows, 1);
                    for i = 2:rows
                        absTime(i) = absTime(i-1) + waypts(i, 1);
                    end
                    
                    % Créer les waypoints au format standard
                    convertedWaypts = [absTime, waypts(:, 2:4), waypts(:, 5), zeros(rows, 2)];
                    if cols >= 6
                        convertedWaypts(:, 6) = waypts(:, 6); % theta si disponible
                    end
                    if cols >= 7
                        convertedWaypts(:, 7) = waypts(:, 7); % phi si disponible
                    end
            end
            
            % Ajouter à la liste des waypoints
            data.inputWayPts{end+1} = convertedWaypts;
            
            % Mettre à jour la liste des fichiers
            currentFiles = get(fileListBox, 'String');
            set(fileListBox, 'String', [currentFiles; file]);
            
            % Mettre à jour les informations
            updateWaypointInfo();
            
        catch err
            errordlg(['Erreur lors du chargement: ' err.message], 'Erreur');
        end
    end

    function removeSelectedFile(~, ~)
        selected = get(fileListBox, 'Value');
        if isempty(selected) || selected == 0
            return;
        end
        
        % Récupérer la liste actuelle
        files = get(fileListBox, 'String');
        if isempty(files)
            return;
        end
        
        % Supprimer les fichiers sélectionnés
        data.inputWayPts(selected) = [];
        files(selected) = [];
        
        % Mettre à jour la liste
        set(fileListBox, 'String', files);
        set(fileListBox, 'Value', min(selected(1), length(files)));
        
        % Mettre à jour les informations
        updateWaypointInfo();
    end

    function clearAllFiles(~, ~)
        % Effacer tous les fichiers
        data.inputWayPts = {};
        set(fileListBox, 'String', {});
        set(fileListBox, 'Value', []);
        
        % Mettre à jour les informations
        updateWaypointInfo();
    end

    function inputFormatChanged(src, ~)
        % Changer le format d'entrée
        val = get(src, 'Value');
        switch val
            case 1
                data.inputFormat = 'standard';
            case 2
                data.inputFormat = 'legacy';
            case 3
                data.inputFormat = 'delta';
        end
        
        % Si des fichiers sont déjà chargés, demander s'il faut les recharger
        if ~isempty(data.inputWayPts)
            choice = questdlg('Le format d''entrée a changé. Voulez-vous effacer les fichiers actuellement chargés?', ...
                'Format changé', 'Oui', 'Non', 'Non');
            if strcmp(choice, 'Oui')
                clearAllFiles();
            end
        end
    end

    function outputFormatChanged(src, ~)
        % Changer le format de sortie
        val = get(src, 'Value');
        switch val
            case 1
                data.outputFormat = 'standard';
            case 2
                data.outputFormat = 'legacy';
            case 3
                data.outputFormat = 'delta';
        end
    end

    function updateWaypointInfo()
        if isempty(data.inputWayPts)
            set(waypointInfoText, 'String', 'Aucun fichier chargé');
            return;
        end
        
        numFiles = length(data.inputWayPts);
        totalWaypoints = 0;
        for i = 1:numFiles
            totalWaypoints = totalWaypoints + size(data.inputWayPts{i}, 1);
        end
        
        infoStr = sprintf('%d fichier(s), %d waypoints au total', numFiles, totalWaypoints);
        set(waypointInfoText, 'String', infoStr);
    end

    function applyTransformations(~, ~)
        if isempty(data.inputWayPts)
            warndlg('Aucun fichier de waypoints chargé', 'Avertissement');
            return;
        end
        
        % Récupérer les waypoints
        waypoints = data.inputWayPts;
        
        % Combiner les fichiers si demandé
        if get(cbCombine, 'Value') && length(waypoints) > 1
            combined = [];
            for i = 1:length(waypoints)
                if isempty(combined)
                    combined = waypoints{i};
                else
                    % Ajuster les temps pour qu'ils se suivent
                    newWaypts = waypoints{i};
                    if ~isempty(combined) && ~isempty(newWaypts)
                        timeOffset = combined(end, 1) + 1; % Ajouter 1 seconde entre les fichiers
                        newWaypts(:, 1) = newWaypts(:, 1) - newWaypts(1, 1) + timeOffset;
                    end
                    combined = [combined; newWaypts];
                end
            end
            waypoints = {combined};
        end
        
        % Appliquer les transformations à chaque ensemble de waypoints
        for i = 1:length(waypoints)
            wpts = waypoints{i};
            
            % Inverser le trajet si demandé
            if get(cbInvert, 'Value')
                wpts = flipud(wpts); % Inverser l'ordre des lignes
                
                % Inverser les temps
                maxTime = max(wpts(:, 1));
                wpts(:, 1) = maxTime - wpts(:, 1) + wpts(end, 1);
                
                % Inverser les orientations
                wpts(:, 5:7) = wpts(:, 5:7) + pi; % Ajouter 180 degrés
                
                % Normaliser les angles entre -pi et pi
                wpts(:, 5:7) = mod(wpts(:, 5:7) + pi, 2*pi) - pi;
            end
            
            % Normaliser le temps si demandé
            if get(cbNormalize, 'Value')
                wpts(:, 1) = wpts(:, 1) - wpts(1, 1);
            end
            
            % Appliquer la translation
            transX = str2double(get(editTransX, 'String'));
            transY = str2double(get(editTransY, 'String'));
            transZ = str2double(get(editTransZ, 'String'));
            
            if ~isnan(transX)
                wpts(:, 2) = wpts(:, 2) + transX;
            end
            if ~isnan(transY)
                wpts(:, 3) = wpts(:, 3) + transY;
            end
            if ~isnan(transZ)
                wpts(:, 4) = wpts(:, 4) + transZ;
            end
            
            % Appliquer la rotation (en transformant les degrés en radians)
            rotPhi = str2double(get(editRotPhi, 'String')) * pi/180;
            rotTheta = str2double(get(editRotTheta, 'String')) * pi/180;
            rotPsi = str2double(get(editRotPsi, 'String')) * pi/180;
            
            if ~isnan(rotPhi) || ~isnan(rotTheta) || ~isnan(rotPsi)
                % Créer la matrice de rotation
                R = eye(3);
                
                if ~isnan(rotPsi)
                    % Rotation autour de l'axe Z (yaw)
                    Rz = [cos(rotPsi), -sin(rotPsi), 0;
                          sin(rotPsi), cos(rotPsi), 0;
                          0, 0, 1];
                    R = Rz * R;
                end
                
                if ~isnan(rotTheta)
                    % Rotation autour de l'axe Y (pitch)
                    Ry = [cos(rotTheta), 0, sin(rotTheta);
                          0, 1, 0;
                          -sin(rotTheta), 0, cos(rotTheta)];
                    R = Ry * R;
                end
                
                if ~isnan(rotPhi)
                    % Rotation autour de l'axe X (roll)
                    Rx = [1, 0, 0;
                          0, cos(rotPhi), -sin(rotPhi);
                          0, sin(rotPhi), cos(rotPhi)];
                    R = Rx * R;
                end
                
                % Appliquer la rotation aux positions
                for j = 1:size(wpts, 1)
                    pos = wpts(j, 2:4)';
                    rotatedPos = R * pos;
                    wpts(j, 2:4) = rotatedPos';
                    
                    % Mettre à jour les angles d'Euler
                    if ~isnan(rotPhi)
                        wpts(j, 5) = wpts(j, 5) + rotPhi;
                    end
                    if ~isnan(rotTheta)
                        wpts(j, 6) = wpts(j, 6) + rotTheta;
                    end
                    if ~isnan(rotPsi)
                        wpts(j, 7) = wpts(j, 7) + rotPsi;
                    end
                    
                    % Normaliser les angles entre -pi et pi
                    wpts(j, 5:7) = mod(wpts(j, 5:7) + pi, 2*pi) - pi;
                end
            end
            
            % Appliquer le facteur d'échelle de temps
            timeScale = str2double(get(editTimeScale, 'String'));
            if ~isnan(timeScale) && timeScale > 0
                wpts(:, 1) = wpts(:, 1) * timeScale;
            end
            
            waypoints{i} = wpts;
        end
        
        % Stocker le résultat
        if length(waypoints) == 1
            data.outputWayPts = waypoints{1};
        else
            data.outputWayPts = waypoints;
        end
        
        % Mettre à jour les informations de sortie
        updateOutputInfo();
    end

    function updateOutputInfo()
        if isempty(data.outputWayPts)
            set(outputInfoText, 'String', 'Aucune conversion effectuée');
            return;
        end
        
        % Si c'est une cellule (plusieurs ensembles de waypoints)
        if iscell(data.outputWayPts)
            numSets = length(data.outputWayPts);
            totalWaypoints = 0;
            for i = 1:numSets
                totalWaypoints = totalWaypoints + size(data.outputWayPts{i}, 1);
            end
            infoStr = sprintf('%d ensembles, %d waypoints au total', numSets, totalWaypoints);
        else
            numWaypoints = size(data.outputWayPts, 1);
            duration = data.outputWayPts(end, 1) - data.outputWayPts(1, 1);
            infoStr = sprintf('%d waypoints, durée: %.1f s', numWaypoints, duration);
        end
        
        set(outputInfoText, 'String', infoStr);
    end

    function previewOutput(~, ~)
        if isempty(data.outputWayPts)
            warndlg('Aucun waypoint à prévisualiser. Veuillez d''abord appliquer des transformations.', 'Avertissement');
            return;
        end
        
        % Créer une nouvelle figure pour l'aperçu
        previewFig = figure('Name', 'Aperçu des waypoints', 'NumberTitle', 'off', ...
            'Position', [150, 150, 800, 600]);
        
        % Créer un axe 3D
        ax = axes('Parent', previewFig);
        hold(ax, 'on');
        grid(ax, 'on');
        box(ax, 'on');
        axis(ax, 'equal');
        view(ax, 3);
        xlabel(ax, 'X (avant)');
        ylabel(ax, 'Y (gauche)');
        zlabel(ax, 'Z (haut)');
        title(ax, 'Aperçu des waypoints');
        
        % Dessiner les waypoints
        if iscell(data.outputWayPts)
            % Plusieurs ensembles
            colors = {'b', 'r', 'g', 'm', 'c', 'k'};
            for i = 1:length(data.outputWayPts)
                wpts = data.outputWayPts{i};
                color = colors{mod(i-1, length(colors))+1};
                
                % Tracer les points et la ligne
                scatter3(ax, wpts(:, 2), wpts(:, 3), wpts(:, 4), 50, color, 'filled');
                plot3(ax, wpts(:, 2), wpts(:, 3), wpts(:, 4), [color '-'], 'LineWidth', 2);
                
                % Ajouter les numéros de waypoints
                for j = 1:size(wpts, 1)
                    text(ax, wpts(j, 2), wpts(j, 3), wpts(j, 4)+1, ...
                        sprintf('%d.%d', i, j), 'FontWeight', 'bold');
                end
            end
        else
            % Un seul ensemble
            wpts = data.outputWayPts;
            
            % Tracer les points et la ligne
            scatter3(ax, wpts(:, 2), wpts(:, 3), wpts(:, 4), 50, 'b', 'filled');
            plot3(ax, wpts(:, 2), wpts(:, 3), wpts(:, 4), 'b-', 'LineWidth', 2);
            
            % Ajouter les numéros de waypoints
            for i = 1:size(wpts, 1)
                text(ax, wpts(i, 2), wpts(i, 3), wpts(i, 4)+1, ...
                    num2str(i), 'FontWeight', 'bold');
            end
        end
        
        % Dessiner le plan du sol (z=0)
        minX = min(xlim(ax));
        maxX = max(xlim(ax));
        minY = min(ylim(ax));
        maxY = max(ylim(ax));
        
        patch([minX, maxX, maxX, minX], ...
              [minY, minY, maxY, maxY], ...
              [0, 0, 0, 0], [0.8, 0.8, 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    end

    function saveOutput(~, ~)
        if isempty(data.outputWayPts)
            warndlg('Aucun waypoint à sauvegarder. Veuillez d''abord appliquer des transformations.', 'Avertissement');
            return;
        end
        
        [file, path] = uiputfile('*.mat', 'Sauvegarder les waypoints');
        if isequal(file, 0)
            return;
        end
        
        fullPath = fullfile(path, file);
        
        try
            % Convertir au format de sortie requis
            finalWayPts = convertToOutputFormat(data.outputWayPts);
            
            % Sauvegarder
            if iscell(finalWayPts)
                % Sauvegarder plusieurs ensembles
                for i = 1:length(finalWayPts)
                    WayPts = finalWayPts{i};
                    [~, name, ext] = fileparts(fullPath);
                    setPath = fullfile(path, [name '_' num2str(i) ext]);
                    save(setPath, 'WayPts');
                end
                msgbox(sprintf('%d fichiers de waypoints sauvegardés avec succès.', length(finalWayPts)), 'Sauvegarde réussie');
            else
                % Sauvegarder un seul ensemble
                WayPts = finalWayPts;
                save(fullPath, 'WayPts');
                msgbox('Waypoints sauvegardés avec succès.', 'Sauvegarde réussie');
            end
            
        catch err
            errordlg(['Erreur lors de la sauvegarde: ' err.message], 'Erreur');
        end
    end

    function output = convertToOutputFormat(input)
        % Convertir les waypoints au format de sortie requis
        
        if iscell(input)
            % Convertir chaque ensemble
            output = cell(size(input));
            for i = 1:length(input)
                output{i} = convertSingleSetToOutputFormat(input{i});
            end
        else
            % Convertir un seul ensemble
            output = convertSingleSetToOutputFormat(input);
        end
    end

    function output = convertSingleSetToOutputFormat(waypts)
        % Convertir un seul ensemble de waypoints au format requis
        switch data.outputFormat
            case 'standard'
                % Format (t, x, y, z, phi, theta, psi)
                output = waypts; % Déjà au bon format
                
            case 'legacy'
                % Format (x, y, z, t)
                output = [waypts(:, 2:4), waypts(:, 1)];
                
            case 'delta'
                % Format (deltat, x, y, z, psi)
                deltaTime = diff([0; waypts(:, 1)]);
                output = [deltaTime, waypts(:, 2:4), waypts(:, 5)];
                
                % Ajouter theta et phi si disponibles
                if size(waypts, 2) >= 6
                    output = [output, waypts(:, 6)];
                end
                if size(waypts, 2) >= 7
                    output = [output, waypts(:, 7)];
                end
        end
    end
end