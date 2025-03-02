classdef ScenarioRecorder < matlab.System
    % untitled Add summary here
    %
    % This template includes the minimum set of functions required
    % to define a System object.

    % Public, tunable properties
    properties

    end

    % Public, nontunable properties
    properties (Nontunable)
        % Frame path
        ScenarioFrameDir = 'C:\Users\vince\Documents\SEN5\CollaborativeSLAM\v0\scenarios\3\images';
    end

    % Pre-computed constants or internal states
    properties (Access = private)
        % Index des frame
        FrameIndex = 1;
    end

    methods (Access = protected)
        function setupImpl(obj)
            
        end

        function stepImpl(obj, img)

            % Safety feature
            if obj.FrameIndex > 9999
                error('Too much frames (FrameIndex > 9999)');
            end

            % Save the image
            fileName = sprintf('frame_%04d.png', int32(obj.FrameIndex));
            fullPath = fullfile(obj.ScenarioFrameDir, fileName);
            imwrite(img, fullPath);
            
            % Incrementing the frame index
            obj.FrameIndex = obj.FrameIndex + 1;

        end

        function resetImpl(obj)
            % Initialize / reset internal properties
        end
    end
end
