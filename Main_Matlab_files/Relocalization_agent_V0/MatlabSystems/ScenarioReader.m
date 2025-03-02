classdef ScenarioReader < matlab.System
    % ScenarioReader: Système pour lire séquentiellement des images d'un répertoire
    
    properties (Nontunable)
        % Répertoire des scénarios
        ScenariosDirectory = "C:\Users\vince\Documents\SEN5\CollaborativeSLAM\Scenarios";

        % Nom du scénario à charger
        ScenarioName = "6";

        ImageSize = [720 1280 3];
    end
    
    properties (Access = private)
        UavData

        ImageFiles    % Liste des fichiers image
        CurrentIndex  % Index image courant

        ImageCount    % Nombre d'images
    end
    
    methods (Access = protected)
        function setupImpl(obj)
            % Initialisation du système
            obj.ImageFiles = dir(fullfile(obj.ScenariosDirectory, obj.ScenarioName, "images", 'frame_*.png'));

            % Load uav data
            obj.UavData = load(fullfile(obj.ScenariosDirectory, obj.ScenarioName, "uavData.mat"), "uavData").uavData;
            disp(obj.UavData)

            % Nombre total d'images
            obj.ImageCount = length(obj.ImageFiles);
                        
            % Initialiser l'index
            obj.CurrentIndex = 1;

            % Affichage
            disp(strcat(num2str(obj.ImageCount), " frames loaded"))
        end
        
        function [currImg, imgIndex, timestamp, gTruth, stopFlag] = stepImpl(obj)
            % Vérifier si on a atteint la dernière image
            if obj.CurrentIndex > length(obj.ImageFiles)
                stopFlag = true;
                currImg = uint8(zeros(obj.ImageSize(1), obj.ImageSize(2), obj.ImageSize(3)));  % Image vide
                imgIndex = length(obj.ImageFiles);
                timestamp = 0;
                gTruth = zeros(7,1);
                return;
            end
            
            % Charger l'image courante
            currImgPath = fullfile(obj.ScenariosDirectory, obj.ScenarioName, "images", obj.ImageFiles(obj.CurrentIndex).name);
            currImg = imread(currImgPath);
            
            % Timestamp
            timestamp = obj.UavData.timeStamps.imageTimeStamps(obj.CurrentIndex);

            % Ground truth
            % Find the corresponding timestamp index in IMU data
            imuIndex = floor(obj.CurrentIndex * length(obj.UavData.timeStamps.imuTimeStamps)/length(obj.UavData.timeStamps.imageTimeStamps));
            gTruth = obj.UavData.gTruth(imuIndex,:)';
            
            % Sorties
            imgIndex = obj.CurrentIndex;
            stopFlag = false;
            
            % Préparer l'index pour la prochaine étape
            obj.CurrentIndex = obj.CurrentIndex + 1;
        end
        
        function resetImpl(obj)
            % Réinitialiser l'index
            obj.CurrentIndex = 1;
        end

        % ================= Utilities =================
        function [currImg, imgIndex,timestamp, gTruth, stopFlag] = getOutputSizeImpl(obj)
            % Retourne la taille pour chaque port de sortie
            currImg = obj.ImageSize;
            imgIndex = [1, 1]; 
            timestamp = [1, 1];
            gTruth = [7, 1];
            stopFlag = [1, 1];
        end

        function [currImg, imgIndex, timestamp, gTruth, stopFlag] = getOutputDataTypeImpl(~)
            % Retourne le type de données pour chaque port de sortie
            currImg = "uint8"; 
            imgIndex = "double";
            timestamp = "double";
            gTruth = "double";
            stopFlag = "boolean";
        end

        function [currImg, imgIndex, timestamp, gTruth, stopFlag] = isOutputComplexImpl(~)
            % Retourne false pour chaque port de sortie avec des données non complexes
            currImg = false;
            imgIndex = false; 
            timestamp = false;
            gTruth = false;
            stopFlag = false; 
        end

        function [currImg, imgIndex, timestamp, gTruth, stopFlag] = isOutputFixedSizeImpl(~)
            % Retourne true pour chaque port de sortie avec une taille fixe
            currImg = true;
            imgIndex = true;
            timestamp = true;
            gTruth = true;
            stopFlag = true;
        end

    end
end