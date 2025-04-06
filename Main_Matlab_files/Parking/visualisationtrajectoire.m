%% Visualisation combinée des données IMU et vidéo pour synchronisation manuelle
% Ce script permet de visualiser simultanément la vidéo et les données IMU
% afin de permettre à l'utilisateur de synchroniser manuellement les deux sources

% Enregistrer ce fichier sous le nom "visualisationtrajectoire.m"

%% Déclaration des variables globales pour la portée des fonctions
global isPlaying currentTime videoOffset imuOffset videoPath;
global videoOffsetEdit imuOffsetEdit timeSlider;
global vr accelTimeLine gyroTimeLine trajectoryMarker posMarker;
global videoAxes accelAxes gyroAxes position timeInSeconds;
global playTimer fps angVelTimeInSeconds;

%% Charger les données
videoPath = 'parking_mat2.mp4';
load('mat2.mat');

% Vérifier et traiter les données IMU
if exist('Acceleration', 'var')
    accelTimetable = Acceleration;
    accelVarNames = accelTimetable.Properties.VariableNames;
    acceleration = table2array(accelTimetable(:, accelVarNames));
    timestamps = accelTimetable.Timestamp;
    
    % Convertir les timestamps en secondes depuis le début
    timeInSeconds = seconds(timestamps - timestamps(1));
    
    % Afficher des informations sur les données
    disp(['Dimensions de Acceleration: ', num2str(size(acceleration))]);
else
    error('Variable Acceleration non trouvée dans le fichier mat2.mat');
end

if exist('AngularVelocity', 'var')
    angularVelocityTimetable = AngularVelocity;
    angVelVarNames = angularVelocityTimetable.Properties.VariableNames;
    angularVelocity = table2array(angularVelocityTimetable(:, angVelVarNames));
    
    % Vérifier les dimensions
    angVelTimestamps = angularVelocityTimetable.Timestamp;
    angVelTimeInSeconds = seconds(angVelTimestamps - angVelTimestamps(1));
    
    disp(['Dimensions de AngularVelocity: ', num2str(size(angularVelocity))]);
else
    warning('Variable AngularVelocity non trouvée');
    angularVelocity = [];
    angVelTimeInSeconds = [];
end

if exist('Orientation', 'var')
    orientationTimetable = Orientation;
    orientVarNames = orientationTimetable.Properties.VariableNames;
    orientation = table2array(orientationTimetable(:, orientVarNames));
    
    % Vérifier les dimensions
    orientTimestamps = orientationTimetable.Timestamp;
    orientTimeInSeconds = seconds(orientTimestamps - orientTimestamps(1));
    
    disp(['Dimensions de Orientation: ', num2str(size(orientation))]);
else
    warning('Variable Orientation non trouvée');
    orientation = [];
    orientTimeInSeconds = [];
end

% Ouvrir la vidéo
vr = VideoReader(videoPath);
fps = vr.FrameRate;
disp(['Frame rate de la vidéo: ', num2str(fps), ' fps']);

% Calculer l'accélération totale (magnitude)
accelMagnitude = sqrt(sum(acceleration.^2, 2));

% Filtrer l'accélération pour enlever la gravité
[b, a] = butter(3, 0.1, 'high');
filteredAccel = filtfilt(b, a, accelMagnitude);

% Estimation de la position par double intégration 
% (très approximative, sert uniquement à la visualisation)
velocity = zeros(length(filteredAccel), 3);
position = zeros(length(filteredAccel), 3);

% Estimer le pas de temps moyen
dt = mean(diff(timeInSeconds));
disp(['Pas de temps moyen des données IMU: ', num2str(dt), ' secondes']);

% Intégration de l'accélération
for i = 2:length(filteredAccel)
    % Intégrer l'accélération pour obtenir la vitesse
    velocity(i,:) = velocity(i-1,:) + acceleration(i,:) * dt;
    
    % Appliquer un filtre passe-haut pour réduire la dérive
    if i > 10
        velocity(i,:) = velocity(i,:) - mean(velocity(max(1,i-10):i,:));
    end
    
    % Intégrer la vitesse pour obtenir la position
    position(i,:) = position(i-1,:) + velocity(i,:) * dt;
end

%% Créer l'interface utilisateur
fig = figure('Name', 'Visualisation IMU et Vidéo', 'Position', [100 100 1200 800]);

% Panel pour les contrôles
controlPanel = uipanel('Title', 'Contrôles', 'Position', [0.02 0.02 0.96 0.15]);

% Paramètres de synchronisation
uicontrol('Parent', controlPanel, 'Style', 'text', 'String', 'Décalage Vidéo (sec):', ...
    'Position', [20 60 150 20]);
videoOffsetEdit = uicontrol('Parent', controlPanel, 'Style', 'edit', 'String', '0', ...
    'Position', [180 60 100 20]);

uicontrol('Parent', controlPanel, 'Style', 'text', 'String', 'Décalage IMU (sec):', ...
    'Position', [300 60 150 20]);
imuOffsetEdit = uicontrol('Parent', controlPanel, 'Style', 'edit', 'String', '0', ...
    'Position', [460 60 100 20]);

% Boutons de contrôle
playBtn = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', 'String', 'Lecture', ...
    'Position', [20 10 100 30], 'Callback', @playCallback);

pauseBtn = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', 'String', 'Pause', ...
    'Position', [140 10 100 30], 'Callback', @pauseCallback);

stopBtn = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', 'String', 'Arrêt', ...
    'Position', [260 10 100 30], 'Callback', @stopCallback);

syncBtn = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', 'String', 'Appliquer Sync', ...
    'Position', [380 10 120 30], 'Callback', @syncCallback);

exportBtn = uicontrol('Parent', controlPanel, 'Style', 'pushbutton', 'String', 'Exporter Vidéo', ...
    'Position', [520 10 120 30], 'Callback', @exportCallback);

% Slider pour le temps
timeSlider = uicontrol('Parent', controlPanel, 'Style', 'slider', ...
    'Min', 0, 'Max', min(vr.Duration, max(timeInSeconds)), ...
    'Value', 0, 'Position', [640 10 500 30], 'Callback', @sliderCallback);

% Panel pour la visualisation
visPanel = uipanel('Title', 'Visualisation', 'Position', [0.02 0.18 0.96 0.80]);

% Sous-panel pour la vidéo
videoPanel = uipanel('Parent', visPanel, 'Title', 'Vidéo', 'Position', [0.01 0.4 0.48 0.58]);
videoAxes = axes('Parent', videoPanel);

% Sous-panel pour les données IMU
imuPanel = uipanel('Parent', visPanel, 'Title', 'Données IMU', 'Position', [0.51 0.01 0.48 0.97]);

% Axes pour les graphiques IMU
accelAxes = axes('Parent', imuPanel, 'Position', [0.1 0.73 0.85 0.25]);
title(accelAxes, 'Accélération');
hold(accelAxes, 'on');

gyroAxes = axes('Parent', imuPanel, 'Position', [0.1 0.41 0.85 0.25]);
title(gyroAxes, 'Vitesse angulaire');
hold(gyroAxes, 'on');

trajectoryAxes = axes('Parent', imuPanel, 'Position', [0.1 0.08 0.85 0.25]);
title(trajectoryAxes, 'Trajectoire estimée (XY)');
hold(trajectoryAxes, 'on');

% Sous-panel pour la position 3D
posPanel = uipanel('Parent', visPanel, 'Title', 'Position 3D', 'Position', [0.01 0.01 0.48 0.38]);
posAxes = axes('Parent', posPanel);
title(posAxes, 'Trajectoire 3D');
hold(posAxes, 'on');
view(posAxes, 3);
grid(posAxes, 'on');

% Initialiser les variables globales
isPlaying = false;
currentTime = 0;
videoOffset = 0;
imuOffset = 0;

% Tracer les données IMU initiales
plot(accelAxes, timeInSeconds, acceleration);
xlabel(accelAxes, 'Temps (s)');
ylabel(accelAxes, 'Accélération (m/s²)');
legend(accelAxes, 'X', 'Y', 'Z');

if ~isempty(angularVelocity) && ~isempty(angVelTimeInSeconds)
    % Utiliser le temps spécifique pour les données de vitesse angulaire
    plot(gyroAxes, angVelTimeInSeconds, angularVelocity);
    xlabel(gyroAxes, 'Temps (s)');
    ylabel(gyroAxes, 'Vitesse angulaire (rad/s)');
    legend(gyroAxes, 'X', 'Y', 'Z');
end

plot(trajectoryAxes, position(:,1), position(:,2));
xlabel(trajectoryAxes, 'X (m)');
ylabel(trajectoryAxes, 'Y (m)');

% Tracer la trajectoire 3D
plot3(posAxes, position(:,1), position(:,2), position(:,3));
xlabel(posAxes, 'X (m)');
ylabel(posAxes, 'Y (m)');
zlabel(posAxes, 'Z (m)');

% Créer les marqueurs de temps actuels (lignes verticales)
accelTimeLine = line(accelAxes, [0 0], get(accelAxes, 'YLim'), 'Color', 'r', 'LineWidth', 2);
gyroTimeLine = line(gyroAxes, [0 0], get(gyroAxes, 'YLim'), 'Color', 'r', 'LineWidth', 2);

% Marqueur de position actuelle
trajectoryMarker = plot(trajectoryAxes, position(1,1), position(1,2), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
posMarker = plot3(posAxes, position(1,1), position(1,2), position(1,3), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');

% Initialiser l'affichage de la vidéo
if hasFrame(vr)
    frame = readFrame(vr);
    imshow(frame, 'Parent', videoAxes);
end

% Timer pour la lecture automatique
playTimer = timer('ExecutionMode', 'fixedRate', 'Period', 0.033, ...
    'TimerFcn', @timerCallback);

% Initialiser l'affichage
updateVisualization();

% Cleanup lorsque la figure est fermée
set(fig, 'CloseRequestFcn', @cleanupFcn);

%% Fonctions de callback et utilitaires
function updateVisualization()
    global currentTime videoOffset imuOffset videoOffsetEdit imuOffsetEdit;
    global vr accelTimeLine gyroTimeLine trajectoryMarker posMarker;
    global videoAxes timeSlider timeInSeconds position;
    
    % Appliquer les offsets
    videoOffset = str2double(get(videoOffsetEdit, 'String'));
    imuOffset = str2double(get(imuOffsetEdit, 'String'));
    
    % Temps effectifs avec offsets
    effectiveVideoTime = currentTime + videoOffset;
    effectiveIMUTime = currentTime + imuOffset;
    
    % Mettre à jour la vidéo si nécessaire
    if effectiveVideoTime >= 0 && effectiveVideoTime <= vr.Duration
        % Positionner la vidéo au temps actuel
        vr.CurrentTime = effectiveVideoTime;
        if hasFrame(vr)
            frame = readFrame(vr);
            imshow(frame, 'Parent', videoAxes);
            title(videoAxes, sprintf('Vidéo (t = %.2f s)', effectiveVideoTime));
        end
    end
    
    % Mettre à jour les marqueurs IMU
    if effectiveIMUTime >= 0 && effectiveIMUTime <= max(timeInSeconds)
        % Trouver l'index IMU le plus proche du temps actuel
        [~, imuIdx] = min(abs(timeInSeconds - effectiveIMUTime));
        
        % Mettre à jour les lignes de temps
        set(accelTimeLine, 'XData', [effectiveIMUTime effectiveIMUTime]);
        set(gyroTimeLine, 'XData', [effectiveIMUTime effectiveIMUTime]);
        
        % Mettre à jour les marqueurs de position
        set(trajectoryMarker, 'XData', position(imuIdx,1), 'YData', position(imuIdx,2));
        set(posMarker, 'XData', position(imuIdx,1), 'YData', position(imuIdx,2), 'ZData', position(imuIdx,3));
        
        % Mettre à jour le slider
        set(timeSlider, 'Value', currentTime);
    end
    
    % Rafraîchir l'affichage
    drawnow;
end

function playCallback(~, ~)
    global isPlaying playTimer;
    if ~isPlaying
        isPlaying = true;
        start(playTimer);
    end
end

function pauseCallback(~, ~)
    global isPlaying playTimer;
    if isPlaying
        isPlaying = false;
        stop(playTimer);
    end
end

function stopCallback(~, ~)
    global isPlaying playTimer currentTime;
    if isPlaying
        isPlaying = false;
        stop(playTimer);
    end
    currentTime = 0;
    updateVisualization();
end

function syncCallback(~, ~)
    updateVisualization();
end

function sliderCallback(hObject, ~)
    global currentTime;
    currentTime = get(hObject, 'Value');
    updateVisualization();
end

function timerCallback(~, ~)
    global isPlaying currentTime videoOffset imuOffset vr timeInSeconds;
    
    if isPlaying
        % Avancer le temps
        currentTime = currentTime + 0.033;  % ~30 FPS
        
        % Vérifier si on a atteint la fin
        if currentTime >= min(vr.Duration - videoOffset, max(timeInSeconds) - imuOffset)
            isPlaying = false;
            stop(playTimer);
            return;
        end
        
        updateVisualization();
    end
end

function exportCallback(~, ~)
    global videoPath videoOffset imuOffset fps;
    
    % Vérifier que videoPath est défini et valide
    if isempty(videoPath) || ~ischar(videoPath)
        videoPath = 'parking_mat2.mp4';  % Utiliser un chemin par défaut
    end
    
    % Créer une nouvelle vidéo synchronisée
    [fileName, pathName] = uiputfile('*.mp4', 'Enregistrer la vidéo synchronisée');
    if fileName == 0
        return;
    end
    
    outputPath = fullfile(pathName, fileName);
    
    % Calculer le décalage en frames
    frameOffset = round(videoOffset * fps);
    
    % Configurer la vidéo de sortie
    outputVideo = VideoWriter(outputPath, 'MPEG-4');
    outputVideo.FrameRate = fps;
    open(outputVideo);
    
    % Réinitialiser la vidéo
    try
        localVr = VideoReader(videoPath);
    catch
        errordlg(['Impossible d''ouvrir la vidéo : ' videoPath], 'Erreur');
        return;
    end
    
    % Sauter les frames du début si nécessaire (si offset positif)
    if frameOffset > 0
        for i = 1:frameOffset
            if hasFrame(localVr)
                readFrame(localVr);
            else
                break;
            end
        end
    end
    
    % Ou ajouter des frames noirs au début (si offset négatif)
    if frameOffset < 0
        blackFrame = zeros(localVr.Height, localVr.Width, 3, 'uint8');
        for i = 1:-frameOffset
            writeVideo(outputVideo, blackFrame);
        end
    end
    
    % Écrire les frames dans la vidéo de sortie
    h = waitbar(0, 'Exportation de la vidéo...');
    frameCount = 0;
    totalFrames = localVr.Duration * fps;
    
    while hasFrame(localVr)
        frame = readFrame(localVr);
        writeVideo(outputVideo, frame);
        frameCount = frameCount + 1;
        
        % Mettre à jour la barre de progression
        if mod(frameCount, 30) == 0
            waitbar(frameCount/totalFrames, h);
        end
    end
    
    % Fermer la vidéo et la barre de progression
    close(outputVideo);
    close(h);
    
    msgbox(sprintf('Vidéo synchronisée enregistrée dans %s', outputPath), 'Exportation terminée');
end

function cleanupFcn(~, ~)
    global isPlaying playTimer;
    
    % Arrêter le timer s'il est en cours d'exécution
    if isPlaying
        stop(playTimer);
    end
    delete(playTimer);
    closereq;
end