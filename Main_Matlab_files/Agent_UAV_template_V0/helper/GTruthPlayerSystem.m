% classdef GTruthPlayerSystem < matlab.System
%     properties
%         groundTruthFile = '/Users/quentinlandon/Library/CloudStorage/OneDrive-ESTACA/Slam_Asynchrone/scenarios/1/uavData.mat'
%     end
% 
%     properties(Access = private)
%         imuTimeStamps
%         groundTruthData
%         lastIdx
%     end
% 
%     methods(Access = protected)
%         function setupImpl(obj)
%             % Charger les données de vérité terrain
%             data = load(obj.groundTruthFile);
%             obj.imuTimeStamps = data.uavData.timeStamps.imuTimeStamps;
%             obj.groundTruthData = data.uavData.gTruth;
%             obj.lastIdx = 1;
%         end
% 
%         function [pose, timestamp, poseIdx, maxIdx] = stepImpl(obj, t)
%             % t est le temps de simulation actuel
%             % Trouver l'index correspondant au temps actuel dans les timestamps IMU
%             [~, currentIdx] = min(abs(obj.imuTimeStamps - t));
% 
%             % Sorties
%             pose = obj.groundTruthData(currentIdx, :);
%             timestamp = obj.imuTimeStamps(currentIdx);
%             poseIdx = currentIdx;
%             maxIdx = length(obj.imuTimeStamps);
% 
%             obj.lastIdx = currentIdx;
%         end
% 
%         function resetImpl(obj)
%             obj.lastIdx = 1;
%         end
% 
%         % Méthodes pour gérer les entrées
%         function num = getNumInputsImpl(~)
%             num = 1;
%         end
% 
%         function name = getInputNamesImpl(~)
%             name = 't';
%         end
% 
%         function validateInputsImpl(~, t)
%             validateattributes(t, {'numeric'}, {'scalar', 'real', 'finite'});
%         end
% 
%         % Méthodes pour les sorties
%         function [pose, timestamp, poseIdx, maxIdx] = getOutputSizeImpl(~)
%             pose = [1, 7];
%             timestamp = [1, 1];
%             poseIdx = [1, 1];
%             maxIdx = [1, 1];
%         end
% 
%         function [pose, timestamp, poseIdx, maxIdx] = getOutputDataTypeImpl(~)
%             pose = 'double';
%             timestamp = 'double';
%             poseIdx = 'double';
%             maxIdx = 'double';
%         end
% 
%         function [pose, timestamp, poseIdx, maxIdx] = isOutputComplexImpl(~)
%             pose = false;
%             timestamp = false;
%             poseIdx = false;
%             maxIdx = false;
%         end
% 
%         function [pose, timestamp, poseIdx, maxIdx] = isOutputFixedSizeImpl(~)
%             pose = true;
%             timestamp = true;
%             poseIdx = true;
%             maxIdx = true;
%         end
% 
%     end
% end

classdef GTruthPlayerSystem < matlab.System
    properties
        groundTruthFile = '/Users/quentinlandon/Library/CloudStorage/OneDrive-ESTACA/Slam_Asynchrone/scenarios/2/uavData.mat'
    end
    
    properties(Access = private)
        imuTimeStamps
        groundTruthData
        accelReadings
        gyroReadings
        lastIdx
    end
    
    methods(Access = protected)
        function setupImpl(obj)
            % Charger les données de vérité terrain et IMU
            data = load(obj.groundTruthFile);
            obj.imuTimeStamps = data.uavData.timeStamps.imuTimeStamps;
            obj.groundTruthData = data.uavData.gTruth;
            obj.accelReadings = data.uavData.accelReadings;  % Ajout des lectures d'accéléromètre
            obj.gyroReadings = data.uavData.gyroReadings;  % Ajout des lectures d'accéléromètre
            obj.lastIdx = 1;
        end
        
        function [pose, timestamp, accel, gyro, poseIdx, maxIdx] = stepImpl(obj, t)
            % t est le temps de simulation actuel
            % Trouver l'index correspondant au temps actuel dans les timestamps IMU
            [~, currentIdx] = min(abs(obj.imuTimeStamps - t));
            
            % Sorties
            pose = obj.groundTruthData(currentIdx, :);
            timestamp = obj.imuTimeStamps(currentIdx);
            accel = obj.accelReadings(currentIdx, :);  % Nouvelle sortie pour l'accélération
            gyro = obj.gyroReadings(currentIdx, :); 
            poseIdx = currentIdx;
            maxIdx = length(obj.imuTimeStamps);
            obj.lastIdx = currentIdx;
        end
        
        function resetImpl(obj)
            obj.lastIdx = 1;
        end
        
        % Méthodes pour gérer les entrées
        function num = getNumInputsImpl(~)
            num = 1;
        end
        
        function name = getInputNamesImpl(~)
            name = 't';
        end
        
        function validateInputsImpl(~, t)
            validateattributes(t, {'numeric'}, {'scalar', 'real', 'finite'});
        end
        
        % Méthodes pour les sorties
        function [pose, timestamp, accel, gyro, poseIdx, maxIdx] = getOutputSizeImpl(~)
            pose = [1, 7];
            timestamp = [1, 1];
            accel = [1, 3];  % Nouvelle taille pour l'accélération
            gyro = [1, 3];
            poseIdx = [1, 1];
            maxIdx = [1, 1];
        end
        
        function [pose, timestamp, accel, gyro, poseIdx, maxIdx] = getOutputDataTypeImpl(~)
            pose = 'double';
            timestamp = 'double';
            accel = 'double';  % Type pour l'accélération
            gyro = 'double';
            poseIdx = 'double';
            maxIdx = 'double';
        end
        
        function [pose, timestamp, accel, gyro, poseIdx, maxIdx] = isOutputComplexImpl(~)
            pose = false;
            timestamp = false;
            accel = false;  % Non complexe pour l'accélération
            gyro = false;
            poseIdx = false;
            maxIdx = false;
        end
        
        function [pose, timestamp, accel, gyro, poseIdx, maxIdx] = isOutputFixedSizeImpl(~)
            pose = true;
            timestamp = true;
            accel = true;  % Taille fixe pour l'accélération
            gyro = true;
            poseIdx = true;
            maxIdx = true;
        end
    end
end