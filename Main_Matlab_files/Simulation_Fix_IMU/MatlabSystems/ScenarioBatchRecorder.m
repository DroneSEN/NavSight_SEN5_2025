classdef ScenarioBatchRecorder < matlab.System
    % untitled Add summary here
    %
    % This template includes the minimum set of functions required
    % to define a System object.

    % Public, tunable properties
    properties

    end

    % Public, nontunable properties
    properties (Nontunable)
        % Répertoire des scénarios (avec \ à la fin)
        ScenariosDirectory = "C:\Users\vince\Documents\SEN5\CollaborativeSLAM\Scenarios\";

        % Nom du scénario à charger
        ScenarioName = "4"

        % Taille des images
        ImageSize = [720, 1280];

        % Taille du buffer (nombres d'images)
        BufferSize = 10;
    end

    % Pre-computed constants or internal states
    properties (Access = private)
        % Index des frame
        FrameIndex = 1;

        % Buffer d'images
        ImageBuffer

        % Index du buffer
        BufferIndex = 1;
    end

    methods (Access = protected)
        function setupImpl(obj)

            % Allocation du buffer
            obj.ImageBuffer = cell(1,obj.BufferSize);
        end

        function stepImpl(obj, img)

            % Safety feature
            if obj.FrameIndex > 9999
                error('Too much frames (FrameIndex > 9999)');
            end

            % Store the image in the buffer
            obj.ImageBuffer{obj.BufferIndex} = img;

            % Increment buffer index
            obj.BufferIndex = obj.BufferIndex + 1;

            % If the buffer is full, save images in parallel
            if obj.BufferIndex > obj.BufferSize
                % Save images in parrallel

                baseIndex = obj.FrameIndex;
                scenarioDir = obj.ScenariosDirectory;
                scenarioName = obj.ScenarioName;
                bufferSize = obj.BufferSize;
                buffer = obj.ImageBuffer;

                parfor bufInternalIndex = 1:bufferSize
                    % Save the image
                    fileName = sprintf('frame_%04d.png', int32(baseIndex+(bufInternalIndex-1)));
                    fullPath = fullfile(scenarioDir, scenarioName, "images", fileName);

                    % Retrieve the image in the buffer
                    image = buffer{bufInternalIndex};

                    % Store the image
                    imwrite(image, fullPath);
                end

                % Update the frame index
                obj.FrameIndex = obj.FrameIndex + obj.BufferSize;

                % Reset the index
                obj.BufferIndex = 1;
            end


        end

        function resetImpl(obj)
            % Initialize / reset internal properties
        end
    end
end
