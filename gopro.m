classdef gopro < handle

    properties (Access = public)
        TTL
        ConfidenceThreshold
        BoxsizeThreshold
        DistanceThreshold
        SearchingStep
        TrackingStep
        AveragingWindow
    end

    properties (Access = private)
        %properties
        Video
        Detector
        Sensor
        PassingDistances
        Data

        %variables that are useful to encapsulate in the class
        trackedPos
        trackingState
        absence
        locations
        avgsize
        bcount
        avgdistance
        area
    end

    methods (Access = public)
        function v = vid(gopro)
            v = gopro.Video;
        end
        function init(gopro, video)
            %setup video reader
            if nargin == 2
                gopro.Video =  VideoReader(video);
            end
            % Sensor configuration
            focalLength    = [988.4268, 1005.4];
            principalPoint = [956.4559, 540.2352];
            imageSize      = [1080 1920];
            height = 0.968;
            pitch = 0;   
            camIntrinsics = cameraIntrinsics(focalLength, principalPoint, imageSize);
            gopro.Sensor  = monoCamera(camIntrinsics, height, 'Pitch', pitch);
        
            % Width of a common vehicle is between 1.5 to 2.5 meters
            vehicleWidth = [1.5, 2.5];
            gopro.Detector = configureDetectorMonoCamera(vehicleDetectorFasterRCNN(), gopro.Sensor, vehicleWidth);

            gopro.PassingDistances = [];
            gopro.trackedPos = [];
            gopro.Data = [];

            gopro.TTL = 6;
            gopro.BoxsizeThreshold = .5;
            gopro.ConfidenceThreshold = .8;
            gopro.TrackingStep = .08;
            gopro.SearchingStep = 1.5;
            gopro.AveragingWindow = 5;
        end
        function setV(gopro, video)
            gopro.Video = VideoReader(video);
        end
        function clear(gopro)
            gopro.PassingDistances = [];
            gopro.trackedPos = [];
            gopro.Data = [];
        end

        function process(gopro, start)
            nextID = 0;
            gopro.Video.CurrentTime = start;
            cars = [];

            while gopro.Video.CurrentTime < gopro.Video.Duration - gopro.SearchingStep
                if isempty(cars)
                    gopro.Video.CurrentTime = gopro.Video.CurrentTime + gopro.SearchingStep;
                else
                    gopro.Video.CurrentTime = gopro.Video.CurrentTime + gopro.TrackingStep;
                end
                frame = gopro.Video.readFrame;
    
                [bboxes, scores] = detect(gopro.Detector, frame); 
                bboxes = bboxes(scores > gopro.ConfidenceThreshold, :);
                scores = scores(scores > gopro.ConfidenceThreshold);
                %perhaps filter out bboxes with a center left of 800
                bboxes = bboxes((bboxes(:,1) + bboxes(:,3)/2) > 750, :);
                
                % bboxes
                % scores
                [bboxes, scores] = fixOverlap(bboxes, scores, .3);
                numcars = length(cars);

                if numcars > 0
                    % disp("numcars: " + num2str(numcars))
                    % for i = 1:numcars
                    %     carr = cars(i);
                    %     disp("CarID: " + num2str(carr.ID))
                    %     disp(carr.getAll())
                    % end
                    if length(bboxes) >= 1
                        pBoxes = [];
                        for i = 1:numcars
                            pBoxes = [pBoxes; cars(i).predictTime(gopro.Video.CurrentTime, 3)];
                        end
                        
                        D = distance(pBoxes, bboxes);
                        if size(D, 1) <= size(D, 2)
                            [M, I] = minsum(D);
                            %assign bbox #1 to car I then remove I from cars and move to next
                            %row and assign Ith car the next bbox from the truncated cars list
                            indexed = [];
                            for i = 1:length(I)
                                if i > 1
                                    plus = sum(I(1:i-1)<I(i));
                                else
                                    plus = 0;
                                end
                                
                                %disp("I:" + I)
                                %disp("I(i)" + I(i))
                                %disp("Plus: " + plus)
                                d = D(i, I(i) + plus);
                                if d < 400
                                    %perhaps don't assign bboxes to cars when D > 400
                                    indexed = [indexed, I(i) + plus];
                                    cars(I(i) + plus).addTime(gopro.Video.CurrentTime, scores(i), d, bboxes(i,:));
                                end
                            end
                            unindexed = setdiff(1:length(cars), indexed);
                            %disp(unindexed)
                            for i = 1:length(unindexed)
                                if cars(unindexed(i)).addAbsence()
                                    %save car info to file
                                    gopro.Data = [gopro.Data; cars(unindexed(i)).getAll()];
                                    %remove car from cars
                                    cars = cars(setdiff(1:length(cars), unindexed(i)));

                                    unindexed = unindexed - 1;
                                end
                            end
                        else
                            D = D';
                            [M, I] = minsum(D);
                            %assign bbox I to car #1 then remove I from bboxes and move to next
                            %row and assign next car to bbox I from the truncated bbox list
                            for i = 1:numcars
                                d = D(i, I(i));
                                if d < 400
                                    %perhaps don't assign bboxes to cars when D > 400   
                                    cars(i).addTime(gopro.Video.CurrentTime, scores(I(i)), d, bboxes(I(i), :));
                                end
                                bboxes = bboxes(setdiff(1:size(bboxes,1), I(i)), :);
                                scores = scores(setdiff(1:size(scores,1), I(i)));
                                D(:, I(i)) = [];
                            end
                            for i = 1:size(bboxes,1)
                                ncar = car(nextID);
                                nextID = nextID + 1;
                                ncar.addTime(gopro.Video.CurrentTime, scores(i), 0, bboxes(i, :))
                                cars = [cars, ncar];
                            end
                        end

                    else
                        nremoved = 0;
                        for i = 1:length(cars)
                            if addAbsence(cars(i - nremoved))
                                %save car info to file
                                gopro.Data = [gopro.Data; cars(i - nremoved).getAll()];
                                %remove car from cars
                                cars = cars(setdiff(1:length(cars), i - nremoved));
                                nremoved = nremoved + 1;
                            end
                        end
                    end
                else
                    for i = 1:size(bboxes, 1)
                        ncar = car(nextID);
                        nextID = nextID + 1;
                        ncar.addTime(gopro.Video.CurrentTime, scores(i), 0, bboxes(i, :))
                        cars = [cars, ncar];
                    end
                end
            
            end
        end
        
        function load(gopro, data)
            m = readmatrix(data);
            M = [];
            car = [];
            id = 0;
            for r = m'
                r = r';
                if sum(r(2:end)) == 0
                    if ~isempty(car)
                        M = [M; car];
                        car = [];
                    end
                    id = r(1);
                else
                    car = [car; [r(1), id, r(2:end)]];
                end
            end
            M = [M; car];
            gopro.Data = M;
        end

        function savePassingData(gopro, filename)
            distances = repmat(gopro.Data, 1);
            distances(:, end-3:end-2) = gopro.computeVehicleLocations(distances(:,end-3:end));
            distances(:, end-1:end) = [];
            
            passing = [];
            for i = 1:size(distances, 1)
                if distances(i, 5) < 8
                    passing = [passing; [distances(i, 2), distances(i, 6), distances(i, 5), distances(i, 1)]];
                end
            end
            
            avgs = [];
            passing = sortrows(passing);
            curr = 0;
            total = 0;
            count = 0;
            for i = 1:size(passing, 1)
                if passing(i,1) ~= curr
                    if count > 2 && total < 0
                        avgs = [avgs; [curr, total/count]];
                    end
                    curr = passing(i,1);
                    total = 0;
                    count = 0;
                end
                total = total + passing(i, 2);
                count = count + 1;
            end

            if nargin == 2
                %writematrix(distances, filename + "D.txt");
                %writematrix(passing, filename + "P.txt");
                writematrix(avgs, filename + "A.txt");
            else
                %writematrix(distances, "DistanceData.txt");
                %writematrix(distances, "PassingData.txt");
                writematrix(distances, "AvgPassing.txt");
            end
        end  

        function save(gopro, name)
            if nargin == 2
                writematrix(gopro.Data, name + "F.txt");
            else
                writematrix(gopro.Data, "FullData.txt");
            end
        end
        
    end


    methods (Access = private)
        function locations = computeVehicleLocations(gopro, bboxes)
            locations = zeros(size(bboxes,1),2);
            for i = 1:size(bboxes, 1)
                bbox  = bboxes(i, :);
                
                % Get [x,y] location of the center of the lower portion of the
                % detection bounding box in meters. bbox is [x, y, width, height] in
                % image coordinates, where [x,y] represents upper-left corner.
                yBottom = bbox(2) + bbox(4) - 1;
                xCenter = bbox(1) + (bbox(3)-1)/15; % approximate center
                
                locations(i,:) = imageToVehicle(gopro.Sensor, [xCenter, yBottom]);
            end
        end
    end
end