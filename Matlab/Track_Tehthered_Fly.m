
function TFlyTrack() 
    %==========================================================================
    % Create System objects used for detecting a single moving object,
    % and displaying the results. Data are saved to a user defined ".txt" file
    % and the tracking video (".avi") with inserted markers is also saved in the
    % same directory as the data file.
    % The data are TAB delimited: time stamp; angle of ellipsoid; x & y
    % coords of the ellipsoid barycenter.
    % You can also use this script as a quick and dirty way of previewing your 
    % camera view. If you just close the preview window when finished previewing
    % the script will close gracefully without performing any tracking.
    % Script by M@Z (Jan_2021). 
    % The ellipsoid tracking algorithm is by Raphael Candelier and you can find 
    % out more about it here:
    % http://raphael.candelier.fr/?blog=Image%20Moments
    %==========================================================================
    
    delete(imaqfind);
    clc;
    evalin('base','clear');

    %%%%%%%%%DEFINE YOUR VIDEO CAMERA HERE%%%%%%%%%%%%%%%%%%%%%%%%%%
%     vid = videoinput('pointgrey',1,'F7_Mono16_1288x964_Mode0'); % This is for the PointGrey camera
    vid = videoinput('macvideo'); % This is for the inbuilt camera on a macbook
    vid.FramesPerTrigger = 1;
    % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
		
    % % % %To view a complete list of all the properties supported by a video 
    % % % %input object or a video source object
    get(vid) 
    % % % 
    % % % to view the properties of the currently selected video source
    % % % src = getselectedsource(vid); 
    % % % src.Shutter = 5;
    % % % src.Gain = 3;
    % % % src.FrameRate = 30;
    % % % 
    triggerconfig(vid, 'manual');
    % % % 
    % % % %%%%%%%%%%%%%%%%FILE RELATED STUFF HERE%%%%%%%%%%%%%%%%%%
    % % % %set file name and directory
    [file,path] = uiputfile('*.txt','SPECIFY TRACKING DATA FILE'); 
    
    %%%%%%%IF NO FILE PATH IS PROVIDED TERMINATE SCRIPT%%%%%%%%%%%%
    if isequal(file,0) || isequal(path,0)
        return;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    FileName_NoExt = strrep(file,'.txt',''); %STRIP OFF '.txt' PART OF FILENAME
   
    % % % 
    %%%%%%CHECK IF USER WANTS TO SAVE VIDEO OR NOT%%%%%%%%%%%%%%%%%%%
    answer = questdlg('Do you want to save the video?', ...
	'SAVE TRACKING VIDEO','YES', 'NO','NO');
        % Handle response
        switch answer
            case 'YES'
                save_video = 1;
            case 'NO'
                save_video = 0;
        end
        
    if save_video == 1
        VideoSave = VideoWriter(fullfile(path,FileName_NoExt), 'Motion JPEG AVI');
        open(VideoSave);
    end
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
        % % % %############START THE VIDEO CAMERA#####################%    
        % Create a preview window. This turns off the default
        % toolbar and menubar in the figure.
    
        start(vid);
            vidRes = vid.VideoResolution;
            imWidth = vidRes(1);
            imHeight = vidRes(2);
            nBands = vid.NumberOfBands;
            
            %%%%%%OPEN PREVIEW WINDOW%%%%%%%%%%%%%%%%
            prev_fig = figure('Menubar', 'none',...
                   'Toolbar', 'none',...
                   'NumberTitle','Off',...
                   'Position', [300, 300, imWidth/2, imHeight/2],... 
                   'Name', 'PREVIEWING CAMERA'); 

            uicontrol('String', 'Close', 'Callback', 'close(gcf)',...
                'Units','normalized',...
                'Position', [0 0 0.15 .07]);
            uicontrol('String', 'Capture', 'Callback', @capture, ...
                'Units','normalized',...
                'Position', [.17 0 .15 .07]);
            
            hImage = image(zeros(imHeight, imWidth, nBands) );
            
            preview(vid, hImage);
            uiwait(prev_fig);
            
            %%%%%%ONCE FRAME HAS BEEN CAPTURED STOP AND CLOSE
            %%%%%%PREVIEW
            closepreview(vid);
            delete(prev_fig);
            
        %%%%%DEFINE SOME VARIABLES HERE%%%%%%%%%%%%%%%%
        Framecount = 1;
        Tot_Frame = 1;
        Time =[0];
        x={}; %%%%PUT IN SOME X, Y VALUES OR GET AN
        y={}; %%%%ERROR FURTHER DOWN THE LINE, BECAUSE
        optostim=[0];  %%%%INDEXING AN EMPTY VECTOR....  
        TrialNumber = 1;
        Trial = [0];
        Myrect = [0];
        HowManyTrials = 1;
        ExpNFlies = 1;
        MyFlyAngle = [0];
        Thrshldng_Done = 0;
        Level = 0.3;      %%%REFERS TO THE THRESHOLDING LEVEL (SCALE 0:1)
        assignin('base', 'Level', Level);
        Start_time = 0;
        Time = [0];
        Barycenter_x=[0];
        Barycenter_y=[0];
        frame1 = getsnapshot(vid);
%         frame = rgb2gray(frame1);
        frame = rgb2gray(ycbcr2rgb(frame1));
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%CHECK IF ROI HAS BEEN CREATED, ELSE QUIT SCRIPT%%%%%%%%
        z = findall(0,'type','figure','Name',...
            'SELECT ROI: DOUBLE CLICK INSIDE ROI TO CONFIRM');
        
        if isempty(z)
            delete(vid); 
            return;
        else
            figure(ROI_Fig);
            [J, rect] = imcrop(frame);
            Myrect = rect; 
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
        %%%%HERE WE OPEN A NEW WINDOW WHICH WILL CONTAIN THE ORIGINAL GRAYSCALE
        %%%%IMAGE BESIDE THE B/W THRESHOLDED VERSION WITH A SLIDE CONTROL TO
        %%%%CHOOSE THE THRESHOLDING LEVEL

        f1 = figure('Menubar', 'none',...
                     'Toolbar', 'none',...
                     'Name','USE SLIDER TO SELECT THRSHLD LEVEL',...
                     'NumberTitle','off');

        J1 = imcrop(frame, Myrect);
        J = im2bw(J1, Level);
        figure(f1);
        subplot(1,2,1);
        imhandle = imshow(J1);
        subplot(1,2,2);
        imshow(J);

        % create buttons
        figure(f1);
        sld = uicontrol(f1, 'style', 'slider',... 
                        'String', 'Thrsh select',...
                        'Position', [10 20 100 20], ...
                        'Min', 0,...
                        'Max', 1, ...
                        'SliderStep', [0.01 0.1],...
                        'Value', 0.3);

        btn = uicontrol(f1, 'Style','pushbutton','String','TRACK NOW',...
            'Callback', @button, 'Position', [120, 20 100, 20]) 

        addlistener(sld, 'Value', 'PostSet', @MyCallBack);

    %    exit_loop = uicontrol('Style', 'pushbutton', 'String', ...
    %               'Done', 'Position', [120 20 50 20], 'Callback',...
    %               @(src,obj) close(gui_figure));
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %WAIT FOR THRESHOLDING TO BE COMPLETED, THEN START TRACKING...
    uiwait(f1);
    
    if Thrshldng_Done == 0
        delete(findall(0));
        return;
    end
    
%    open(VideoSave);
    
    %TRACKING WILL START WHEN 'TRACK NOW' BUTTON IS PRESSED
    %CHECK THE FUNCTION 'button' AT END OF SCRIPT...
    
    %%%%%%NEED TO CONVERT IMAGE TO RGB TO ALLOW FOR 'INSERTSHAPE' TO WORK
    %%%%%%LATER DURING THE ACTUAL TRACKING PART OF THE SCRIPT...
    J1 = cat(3, J1, J1, J1);
    
    Stop_fig = figure('Menubar', 'none',...
                      'Toolbar', 'none',...
                      'Name','STOP TRACKING',...
                      'Position', [300, 300, imWidth/2, imHeight/2],...
                      'NumberTitle','off');
    btn = uicontrol(Stop_fig, 'Style','pushbutton','String','STOP',...
                'Callback', @stop_trk, 'Position', [12, 20 50, 50])  
  
   delete(f1);
   delete(ROI_Fig);
   
   %%%%%%%NOW OPEN TRACKING WINDOW SHOWING VIDEO OF TRACKING%%%%%%%%%%%%%
   figure(Stop_fig);
   imshow(J1);
        
    %%%%%%%%%%%START A TIMER HERE%%%%%%%%%%%%%%
    %#########################################%
                     Start_time=tic;            
    %#########################################% 
    %  Detect moving objects, and track them across video frames
    %%%%%%%%%%%%REPEAT THE PROCEDURE 'HowManyTrials' TIMES%%%%%%%%%%%%%
    %##################################################################%
    while (TrialNumber < (HowManyTrials+1) && Thrshldng_Done == 1);

    Framecount = 1; %%%%%%%START Framecount TIMER OVER AGAIN
                    %%%%%%%FOR EACH TRIAL                                         
            
            frame1 = getsnapshot(vid);
            frame = rgb2gray(ycbcr2rgb(frame1));
            J1 = imcrop(frame, Myrect);
            J = im2bw(J1, Level);
            E = get_ellipse(J, true);
            
            MyFlyAngle(Tot_Frame) = E.theta;
            Barycenter_x(Tot_Frame) = E.x;
            Barycenter_y(Tot_Frame) = E.y;

            %%%%%%%%THIS IS TIME SINCE START OF TRACKING%%%%%%%
            Time(Tot_Frame) = toc(Start_time);


%%%%%%%%            displayTrackingResults();

            Framecount = Framecount + 1;%%%FRAME COUNT FOR EACH TRIAL
            Trial(Tot_Frame) = TrialNumber;
            Tot_Frame = Tot_Frame + 1; %%%GLOBAL FRAME COUNT
    end

    TrialNumber = TrialNumber + 1;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%EVALUATE ELAPSED TIME%%%%%%%%%%%%%%%%
                    
     Time_Elapsed = toc(Start_time);
     FrameRate = Tot_Frame/Time_Elapsed;
     
     assignin('base', 'Time_Elapsed', Time_Elapsed);
     assignin('base', 'FrameRate', FrameRate);
     
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%CLOSE VIDEO FILE & SAVE DATA%%%%%%%%%%%%
    if save_video == 1
        close(VideoSave);
    end
       
    %%%%%%%%%%%%%%TO SAVE A TABLE OF DATA%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%AS A TEXT FILE%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%WITH TAB DELIMITATION%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%Saving Time, angle of fly, x and y coords of barycenter
    
    A = [Time; MyFlyAngle; Barycenter_x; Barycenter_y];
    
    %%%%%%%MAYBE BETTER FOR WINDOWS ENVIRONMENTS....
    %%%%%RECONSTRUCTS PATH AND FILE NAME IN PLATFORM-SPECIFIC
    %%%%%WAY
    
    f = fullfile(path, file)

    fileID = fopen(f, 'w');
    %COLUMN NAMES:
    fprintf(fileID,'%8s\t %8s\t %8s\t %8s\n','TIME(s)','ANGLE', 'X', 'Y');
    %VALUES SAVED:
    fprintf(fileID,'%8.4f\t %8.4f\t %8.4f\t %8.4f\n', A);             
    fclose(fileID);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%AFTER FINISHING WITH TRACKING....DELETE VIDEO OBJECT AND CLOSE ALL
    %%%WINDOWS
    delete(vid);
    delete(findall(0));
    
    %%%%%%%%%%%%%FOLLOWING ARE ALL THE FUNCTION DEFINITIONS%%%%%%%%%%%%%%%
    
    function E = get_ellipse(Img, direct)
        %GET_ELLIPSE Equivalent ellipse of an image
        %   E = IM.GET_ELLIPSE(IMG) finds the equivalent ellipse of an image IMG.
        %   IMG is a n-by-m image, and E is a structure containing the ellipse
        %   properties.
        %
        %   E = IM.GET_ELLIPSE(..., 'direct', false) will not try to assign a
        %   direction based on the third moment. The orientation of the 
        %   object will be unchanged but the direction is pi-undetermined.
        %
        %   See also: IM.draw_ellipse
        %%% From: http://raphael.candelier.fr/?blog=Image%20Moments

        % --- Default values
        if ~exist('direct', 'var')
            direct = true;
        end

        % --- Computing moments

        % Object pixels coordinates
        I = find(Img);
        [j, i] = ind2sub(size(Img), I);

        % Function handle to compute the moments
        moment = @(p,q) sum((i.^p).*(j.^q).*double(Img(I)));

        % --- Prepare the output
        E = struct();

        % --- Get the Moments
        E.m00 = moment(0, 0);
        E.m10 = moment(1, 0);
        E.m01 = moment(0, 1);
        E.m11 = moment(1, 1);
        E.m02 = moment(0, 2);
        E.m20 = moment(2, 0);

        % --- Ellipse properties

        % Barycenter
        E.x = E.m10/E.m00;
        E.y = E.m01/E.m00;

        % Central moments (intermediary step)
        a = E.m20/E.m00 - E.x^2;
        b = 2*(E.m11/E.m00 - E.x*E.y);
        c = E.m02/E.m00 - E.y^2;

        % Orientation (radians)
        E.theta = 1/2*atan(b/(a-c)) + (a<c)*pi/2;

        % Minor and major axis
        E.w = sqrt(8*(a+c-sqrt(b^2+(a-c)^2)))/2;
        E.l = sqrt(8*(a+c+sqrt(b^2+(a-c)^2)))/2;

        % Ellipse focal points
        d = sqrt(E.l^2-E.w^2);
        E.x1 = E.x + d*cos(E.theta);
        E.y1 = E.y + d*sin(E.theta);
        E.x2 = E.x - d*cos(E.theta);
        E.y2 = E.y - d*sin(E.theta);

        % Ellipse direction
        if direct
            tmp = [i-mean(i) j-mean(j)]*[cos(E.theta) -sin(E.theta); 
                sin(E.theta) cos(E.theta)];
            if skewness(tmp(:,1))>0

                % Fix direction
                E.theta = mod(E.theta + pi, 2*pi);
                tmp = [E.x1 E.y1];

                % Swap F1 and F2
                E.x1 = E.x2;
                E.y1 = E.y2;
                E.x2 = tmp(1);
                E.y2 = tmp(2);
            end
        end
    end


    %% Display Tracking Results
    % The |displayTrackingResults| function displays the frame (and the 
    % mask) in their respective video players. 
    % PASSED ARGUMENTS E, Tot_Frame, J1, videoPlayer, MyFlyAngle
    
        function displayTrackingResults()

    %         HowManyFlies(Tot_Frame)=(max(size(centroids)));

%                  MyFlyAngle(Tot_Frame) = E.theta;
%                  Barycenter_x(Tot_Frame) = E.x;
%                  Barycenter_y(Tot_Frame) = E.y;
                 
                 %%%%%%%%THIS IS TIME SINCE START OF TRACKING%%%%%%%
%                  Time(Tot_Frame) = toc(Start_time);
                 
    %           % insert a marker inside frame.
                J1 = insertShape(J1, 'Line', [E.x1, E.y1, E.x2, E.y2],...
                           'LineWidth', 5, 'Color', 'red'); 

                %PLUS COLOURED DOTS TO INDICATE HEAD AND TAIL
                J1 = insertShape(J1, 'FilledCircle', [E.x1, E.y1, 5],... 
                    'Color', 'green');
                J1 = insertShape(J1, 'FilledCircle', [E.x2, E.y2, 5],... 
                    'Color', 'blue');  
                
              figure(Stop_fig);
              imshow(J1);
              
            if save_video == 1 
                writeVideo(VideoSave, J1);
            end
            
            assignin('base', 'MyFlyAngle', MyFlyAngle);
        end

      %%%THESE TWO FUNCTIONS RESPOND TO THE SLIDER AND BUTTON IN THE
      %%%THRESHOLDING WINDOW.

    function MyCallBack(a, b)
            Level = b.AffectedObject.Value;
            J = im2bw(J1, Level);
            figure(f1);
            subplot(1,2,2);
            imshow(J);
            %set(gca,'XTick',[], 'YTick', []);
            %xlabel('')
            assignin('base', 'Level', Level);
        end

        function button(a, b)
            Thrshldng_Done = 1;
            assignin('base', 'Thrshldng_Done', Thrshldng_Done);
            uiresume(f1);
        end
    
    
    function capture(a, b)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%THIS OPENS A FIGURE CONTAINING THE FIRST FRAME OF THE VIDEO
        %%%%ON WHICH TO PERFORM THRESHOLDING TO PRODUCE A BINARY (B/W) IMAGE
        frame1 = getsnapshot(vid);
        %frame = rgb2gray(frame1);
        frame = rgb2gray(ycbcr2rgb(frame1));

        ROI_Fig = figure('Menubar', 'none',...
                         'Toolbar', 'none',...
                         'Position', [300, 300, imWidth/2, imHeight/2],...
                         'NumberTitle','off', ...
                         'Name','SELECT ROI: DOUBLE CLICK INSIDE ROI TO CONFIRM');

%         assignin('base', 'frame', frame);
%         assignin('base', 'ROI_Fig', ROI_Fig);
        uiresume(prev_fig);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    
       function stop_trk(a, b)
            Thrshldng_Done = 0;
        end
end
