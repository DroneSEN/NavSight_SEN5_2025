% ==============================
% 1️⃣ Définition du dossier des images
% ==============================
dossier = '/Users/quentinlandon/Library/CloudStorage/OneDrive-ESTACA/Slam_Asynchrone/scenarios/2/images'; 

% Vérifier que le dossier existe
if ~isfolder(dossier)
    error("Le dossier spécifié n'existe pas !");
end

% Créer un imageDatastore pour charger les images
imds = imageDatastore(dossier, 'FileExtensions', {'.png', '.jpg', '.jpeg', '.tif'});

% Vérifier s'il y a bien des images
if isempty(imds.Files)
    error('Aucune image trouvée dans le dossier spécifié.');
end

% ==============================
% 2️⃣ Génération du Bag of Features avec ORB
% ==============================

bag = bagOfFeatures(imds, ...
    'CustomExtractor', @helperORBFeatureExtractorFunction, ... % Fonction d'extraction ORB
    'TreeProperties', [3, 10], ...  % Paramètres de l'arbre (clusters visuels)
    'StrongestFeatures', 1); % Utilisation des features les plus fortes

% ==============================
% 3️⃣ Sauvegarde du modèle pour utilisation ultérieure
% ==============================

save('bag.mat', 'bag');

disp('✅ Bag of Features créé et sauvegardé avec succès !');
