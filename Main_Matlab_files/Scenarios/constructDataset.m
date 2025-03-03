%% Construction du dataset pour simulation 3D SLAM visuel inertiel %%

% Charger les fichiers MAT
% Choix du scénario
selectedScenarioStr = "10";

% Scenario name

% Chargement de la sortie du scénario
% Charger les données (Accéléromètre, Gyroscope et ground truth)
load(strcat(selectedScenarioStr, '/simulationOutput.mat'), 'out');

% Ground truth
% (x,y,z, qw, qx, qy, qz)
gTruth = permute(out.gTruth.Data, [3 2 1]);

% Extraire les données acc et gyro
imuTimeStamps = out.AccData.Time; % Timestamps
accelReadings = permute(out.AccData.Data, [3 2 1]); % Accéléromètre
gyroReadings = permute(out.GyroData.Data, [3 2 1]); % Gyroscope

% Déterminer le nombre d'images dans le dossier
folderImage = strcat(selectedScenarioStr,'/images');   % Spécifiez le dossier contenant les images
imageFiles = dir(fullfile(folderImage, '*.png'));                   % Suppose que les images sont en format PNG
numImages = length(imageFiles);

% Créer les timeStamps
% On se base sur les FPS de la caméra
f_cam = 30;    % FPS
imageTimeStamps = (0:numImages-1)./f_cam;              % XX x 1 tableau avec des 1

% Paramètres intrinsèques de la caméra pour la simulation 3D
focalLength    = [1109, 1109];       % en pixels
principalPoint = [640, 360];         % en pixels
imageSize      = [720, 1280];        % en pixels

% Valeurs par défaut pour intrinsics
intrinsics = cameraIntrinsics(focalLength, principalPoint, imageSize);


% Définir une matrice de rotation identité (aucune rotation)
R = eye(3);  % Matrice 3x3 identité

% Définir un vecteur de translation nul
t = [0; 0; 0];  % Pas de translation

% Créer la matrice de transformation homogène
T = [R t; 
     0 0 0 1];  % Matrice 4x4

% Créer l'objet se3
camToIMUTransform = se3(eul2rotm([0 0 -pi/2]), [0 0 0]);

% Construire la structure principale
uavData = struct(...
    'accelReadings', accelReadings, ...            % Données accéléromètre (double)
    'gyroReadings', gyroReadings, ...              % Données gyroscope (double)
    'images', [], ...                              % Cellule contenant les images
    'intrinsics', intrinsics, ...                  % Objet cameraIntrinsics
    'timeStamps', struct(...
        'imageTimeStamps', imageTimeStamps, ...    % Timestamps des images
        'imuTimeStamps', imuTimeStamps ...         % Timestamps des données IMU
    ), ...
    'gTruth', gTruth, ...                          % Données de vérité terrain
    'camToIMUTransform', camToIMUTransform, ...    % Transformation caméra vers IMU
    'optimized', true, ...                         % Indique que le scénario est optimisé (les images ne sont pas contenues dans ce fichier)
    'frameCount', numImages  ...
);

% Vérification : Confirmer que uavData est bien une structure 1x1
if numel(uavData) == 1
    disp('La structure uavData est bien au format 1x1.');
else
    error('Erreur : uavData n''est pas au format 1x1.');
end

% Sauvegarder la structure dans un fichier MAT
save(strcat(selectedScenarioStr, '/uavData.mat'), 'uavData');
disp('Structure uavData sauvegardée avec succès.');
