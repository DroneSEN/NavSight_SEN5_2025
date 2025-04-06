%% Construction du dataset pour simulation 3D SLAM visuel inertiel %%
% Ce script convertit les données IMU du drone dans le format uavData
% compatible avec les algorithmes de SLAM visuel-inertiel

% Nom du dossier de sortie
outputFolder = 'drone_data';

% Créer le dossier s'il n'existe pas
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
    mkdir(fullfile(outputFolder, 'images'));
end

% Charger les données IMU
load('mat2.mat');

% Extraire les données d'accéléromètre et de gyroscope
if exist('Acceleration', 'var') && exist('AngularVelocity', 'var')
    disp('Données IMU trouvées, extraction en cours...');
    
    % Extraire les timestamps
    accelTimestamps = Acceleration.Timestamp;
    gyroTimestamps = AngularVelocity.Timestamp;
    
    % Convertir en secondes depuis le début
    accelTimeInSeconds = seconds(accelTimestamps - accelTimestamps(1));
    gyroTimeInSeconds = seconds(gyroTimestamps - gyroTimestamps(1));
    
    % Extraire les données numériques
    accelVarNames = Acceleration.Properties.VariableNames;
    gyroVarNames = AngularVelocity.Properties.VariableNames;
    
    accelReadings = table2array(Acceleration(:, accelVarNames));
    gyroReadings = table2array(AngularVelocity(:, gyroVarNames));
    
    % Afficher les informations
    disp(['Nombre d''échantillons d''accélération: ', num2str(size(accelReadings, 1))]);
    disp(['Nombre d''échantillons de gyroscope: ', num2str(size(gyroReadings, 1))]);
    
    % S'assurer que les dimensions correspondent
    if size(accelReadings, 1) ~= size(gyroReadings, 1)
        disp('Les dimensions de l''accéléromètre et du gyroscope ne correspondent pas.');
        disp('Harmonisation des données...');
        
        % Utiliser la plus petite dimension
        minLength = min(size(accelReadings, 1), size(gyroReadings, 1));
        accelReadings = accelReadings(1:minLength, :);
        gyroReadings = gyroReadings(1:minLength, :);
        accelTimeInSeconds = accelTimeInSeconds(1:minLength);
        gyroTimeInSeconds = gyroTimeInSeconds(1:minLength);
        
        disp(['Dimensions harmonisées à : ', num2str(minLength), ' échantillons']);
    end
else
    error('Données IMU non trouvées dans le fichier mat2.mat');
end

% Vérifier si la vidéo existe
videoPath = 'parkingsynchro.mp4';
if exist(videoPath, 'file')
    disp('Vidéo trouvée, extraction des informations...');
    
    % Ouvrir la vidéo
    vr = VideoReader(videoPath);
    
    % Obtenir les informations sur la vidéo
    fps = vr.FrameRate;
    numFrames = vr.NumFrames;
    imageSize = [vr.Height, vr.Width];
    
    disp(['FPS: ', num2str(fps)]);
    disp(['Nombre total d''images: ', num2str(numFrames)]);
    
    % Créer les timestamps pour les images
    imageTimeStamps = (0:numFrames-1)./fps;
    
    % Paramètres intrinsèques de la caméra (estimation pour un smartphone standard)
    % Les valeurs par défaut peuvent être ajustées selon les caractéristiques de la caméra
    focalLength = [imageSize(2) * 0.8, imageSize(2) * 0.8]; % Approximation basée sur la largeur de l'image
    principalPoint = [imageSize(2)/2, imageSize(1)/2]; % Centre de l'image
    
    % Créer l'objet intrinsics
    intrinsics = cameraIntrinsics(focalLength, principalPoint, imageSize);
    
    % Extraire des images à partir de la vidéo (optionnel - peut être commenté si non nécessaire)
    % Cette étape peut prendre du temps pour les longues vidéos
    extractImages = true ; % Mettre à true pour extraire les images
    
    if extractImages
        disp('Extraction des images de la vidéo...');
        vr.CurrentTime = 0;
        frameCount = 0;
        
        while hasFrame(vr)
            frame = readFrame(vr);
            imwrite(frame, fullfile(outputFolder, 'images', sprintf('frame_%06d.png', frameCount)));
            frameCount = frameCount + 1;
            
            % Afficher la progression
            if mod(frameCount, 100) == 0
                disp(['Images extraites: ', num2str(frameCount), '/', num2str(numFrames)]);
            end
        end
        
        disp('Extraction des images terminée.');
    end
    
else
    warning(['Vidéo ', videoPath, ' non trouvée. Utilisation de valeurs par défaut pour les paramètres de la caméra.']);
    
    % Valeurs par défaut si la vidéo n'est pas trouvée
    fps = 30;
    numFrames = min(length(accelTimeInSeconds), 1000); % Estimation basée sur les données IMU
    imageSize = [720, 1280]; % Taille d'image standard
    imageTimeStamps = (0:numFrames-1)./fps;
    
    % Paramètres intrinsèques par défaut
    focalLength = [1000, 1000];
    principalPoint = [imageSize(2)/2, imageSize(1)/2];
    intrinsics = cameraIntrinsics(focalLength, principalPoint, imageSize);
end

% Synchroniser l'IMU et les images (si nécessaire)
% Ici, nous utilisons les offsets déterminés précédemment
imuOffset = -1.9; % L'IMU est en avance de 1.9 secondes

% Ajuster les timestamps de l'IMU en fonction de l'offset
adjustedAccelTime = accelTimeInSeconds + imuOffset;
adjustedGyroTime = gyroTimeInSeconds + imuOffset;

% Génération d'une trajectoire approximative pour la vérité terrain (gTruth)
% Puisque nous n'avons pas de données de vérité terrain, nous estimons
% une trajectoire basée sur l'intégration des données IMU

% Intégration des données IMU pour obtenir une estimation grossière de la trajectoire
numSamples = size(accelReadings, 1);
velocity = zeros(numSamples, 3);
position = zeros(numSamples, 3);

% Estimer le pas de temps moyen
dt = mean(diff(accelTimeInSeconds));

% Intégration simple (approximative)
for i = 2:numSamples
    % Intégrer l'accélération pour obtenir la vitesse
    velocity(i,:) = velocity(i-1,:) + accelReadings(i,:) * dt;
    
    % Appliquer un filtre pour réduire la dérive
    if i > 10
        velocity(i,:) = velocity(i,:) - mean(velocity(max(1,i-10):i,:));
    end
    
    % Intégrer la vitesse pour obtenir la position
    position(i,:) = position(i-1,:) + velocity(i,:) * dt;
end

% Créer une orientation approximative basée sur les données du gyroscope
orientation = zeros(numSamples, 4); % [qw, qx, qy, qz]
orientation(:,1) = 1; % Initialiser les quaternions à l'identité (qw=1, qx=qy=qz=0)

% Vérifier les dimensions avant la concaténation
disp(['Dimensions de position: ', num2str(size(position))]);
disp(['Dimensions d''orientation: ', num2str(size(orientation))]);

% S'assurer que les dimensions correspondent avant la concaténation
if size(position, 1) == size(orientation, 1)
    % Combiner la position et l'orientation pour créer la vérité terrain approximative
    gTruth = [position, orientation];
    disp(['Dimensions de gTruth: ', num2str(size(gTruth))]);
else
    error('Les dimensions de position et orientation ne correspondent pas pour la création de gTruth');
end

% Définir la transformation caméra vers IMU
% Par défaut, nous supposons que la caméra est alignée avec l'IMU
% avec une rotation de -90 degrés autour de l'axe Z (pour aligner les axes X et Y)
camToIMUTransform = se3(eul2rotm([0 0 -pi/2]), [0 0 0]);

% Construire la structure uavData
uavData = struct(...
    'accelReadings', accelReadings, ... % Données accéléromètre (double)
    'gyroReadings', gyroReadings, ... % Données gyroscope (double)
    'images', [], ... % Cellule contenant les images (vide, optimisé)
    'intrinsics', intrinsics, ... % Objet cameraIntrinsics
    'timeStamps', struct(...
        'imageTimeStamps', imageTimeStamps, ... % Timestamps des images
        'imuTimeStamps', accelTimeInSeconds ... % Timestamps des données IMU
    ), ...
    'gTruth', gTruth, ... % Données de vérité terrain approximative
    'camToIMUTransform', camToIMUTransform, ... % Transformation caméra vers IMU
    'optimized', true, ... % Indique que le scénario est optimisé (les images ne sont pas contenues dans ce fichier)
    'frameCount', numFrames ...
);

% Vérification : Confirmer que uavData est bien une structure 1x1
if numel(uavData) == 1
    disp('La structure uavData est bien au format 1x1.');
else
    error('Erreur : uavData n''est pas au format 1x1.');
end

% Sauvegarder la structure dans un fichier MAT
save(fullfile(outputFolder, 'uavData.mat'), 'uavData');
disp(['Structure uavData sauvegardée avec succès dans ', fullfile(outputFolder, 'uavData.mat')]);

% Créer un fichier d'informations supplémentaires
fid = fopen(fullfile(outputFolder, 'info.txt'), 'w');
fprintf(fid, 'Dataset de drone généré à partir des données IMU et vidéo\n');
fprintf(fid, '------------------------------------------------------\n');
fprintf(fid, 'Date de création: %s\n', datestr(now));
fprintf(fid, 'Nombre d''échantillons IMU: %d\n', numSamples);
fprintf(fid, 'Nombre d''images: %d\n', numFrames);
fprintf(fid, 'Fréquence d''échantillonnage IMU: %.2f Hz\n', 1/dt);
fprintf(fid, 'Fréquence des images: %.2f Hz\n', fps);
fprintf(fid, 'Offset appliqué à l''IMU: %.2f secondes\n', imuOffset);
fprintf(fid, 'Taille des images: %d x %d pixels\n', imageSize(1), imageSize(2));
fclose(fid);

disp('Fichier d''informations créé.');
disp('Traitement terminé avec succès!');