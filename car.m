classdef car < handle
    properties (Access = public)
        ID
    end
    properties (Access = private)
        Bboxes
        Scores
        times
        absence
        distFromExpected
        MAXABSENCE = 5
    end

    methods (Access = public)
        function c = car(id)
            c.ID = id;
        end
        function absent = addAbsence(car)
            car.absence = car.absence + 1;
            if car.absence == car.MAXABSENCE
                absent = true;
            else
                absent = false;
            end
        end
        
        function addTime(car, time, score, dif, bbox)
            car.absence = 0;
            if isempty(time)
                car.distFromExpected = dif;
                car.times = time;
                car.Scores = score;
                car.Bboxes = bbox;
            else
                car.distFromExpected = [car.distFromExpected; dif];
                car.times = [car.times; time];
                car.Scores = [car.Scores; score];
                car.Bboxes = [car.Bboxes; bbox];
            end
            %bbox is [x, y, width, height]
            %disp("Bboxes");
            %disp(car.Bboxes);
        end

        function pBox = predictTime(car, time, window)
            l = length(car.times);
            if l > window
                pBox = mean(car.Bboxes(l - window:l, :), 1);
            else
                pBox = mean(car.Bboxes, 1);
            end
            % a = 2;
            % 
            % if l > window
            %     dt = time - car.times(l);
            %     dT = mean(car.times(l-a:l) - car.times(l-window:l-window+a)); 
            %     dx = mean(car.Bboxes(l-a:l, 1) - car.Bboxes(l-window:l-window+a, 1));
            %     dy = mean(car.Bboxes(l-a:l, 2) - car.Bboxes(l-window:l-window+a, 2));
            %     dW = mean(car.Bboxes(l-a:l, 3) - car.Bboxes(l-window:l-window+a, 3));
            %     dH = mean(car.Bboxes(l-a:l, 4) - car.Bboxes(l-window:l-window+a, 4));
            %     dBox = [dx, dy, dW, dH];
            %     pBox = dBox * dt/dT;
            % else
            %     pBox = car.Bboxes(l, :);
            % end 
        end
        
        function all = getAll(car)
            all = [car.times, car.Scores, car.distFromExpected, car.Bboxes];
            all = [[car.ID, 0, 0, 0, 0, 0, 0]; all];
        end

        function avg = getAvg(car, window)
            avg = sum(car.Bboxes(length(car.times)-window:length(car.times), :));
            avg = avg / window;
        end
    end
end