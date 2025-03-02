classdef ImagePlayerSystem < matlab.System
    properties
        imageFolder = '/Users/quentinlandon/Library/CloudStorage/OneDrive-ESTACA/Slam_Asynchrone/scenarios/1/images'
        cameraSize = [720, 960]
        groundTruthFile = '/Users/quentinlandon/Library/CloudStorage/OneDrive-ESTACA/Slam_Asynchrone/scenarios/1/uavData.mat'
    end

    properties(Access = private)
        imds
        imageTimeStamps
        currFrame
        lastIdx
    end

    methods(Access = protected)
        function setupImpl(obj)
            % Charger les images et les timestamps
            obj.imds = imageDatastore(obj.imageFolder);
            obj.currFrame = uint8(zeros(obj.cameraSize));
            obj.lastIdx = 1;

            % Charger les timestamps des images
            data = load(obj.groundTruthFile);
            obj.imageTimeStamps = data.uavData.timeStamps.imageTimeStamps;
        end

        function [frame, timestamp, frameIdx, maxIdx] = stepImpl(obj, t)
            % t est le temps de simulation actuel

            % Trouver l'index correspondant au temps actuel dans les timestamps
            [~, currentIdx] = min(abs(obj.imageTimeStamps - t));

            % Si l'index a changé, charger une nouvelle image
            if currentIdx ~= obj.lastIdx
                obj.currFrame = uint8(readimage(obj.imds, currentIdx));
                obj.lastIdx = currentIdx;
            end

            % Sorties
            frame = obj.currFrame;
            timestamp = obj.imageTimeStamps(currentIdx);
            frameIdx = currentIdx;
            maxIdx = length(obj.imageTimeStamps);
        end

        function resetImpl(obj)
            obj.currFrame = uint8(zeros(obj.cameraSize));
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

        function [frame, timestamp, frameIdx, maxIdx] = getOutputSizeImpl(obj)
            frame = obj.cameraSize;
            timestamp = [1, 1];
            frameIdx = [1, 1];
            maxIdx = [1, 1];
        end

        function [frame, timestamp, frameIdx, maxIdx] = getOutputDataTypeImpl(~)
            frame = 'uint8';
            timestamp = 'double';
            frameIdx = 'double';
            maxIdx = 'double';
        end

        function [frame, timestamp, frameIdx, maxIdx] = isOutputComplexImpl(~)
            frame = false;
            timestamp = false;
            frameIdx = false;
            maxIdx = false;
        end

        function [frame, timestamp, frameIdx, maxIdx] = isOutputFixedSizeImpl(~)
            frame = true;
            timestamp = true;
            frameIdx = true;
            maxIdx = true;
        end
    end
end