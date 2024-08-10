import cv2
import sys
import numpy as np
from scipy.stats import skew
import time
from imutils.video import FileVideoStream
from psychopy import visual, event, core
from PyQt5.QtWidgets import QApplication, QFileDialog
import pandas as pd

 
if __name__ == '__main__' :

    class Plotter:
        def __init__(self, plot_width, plot_height):
            self.width = plot_width
            self.height = plot_height
            self.color = (255, 0 ,0)
            self.val = []
            self.plot_canvas = np.ones((self.height, self.width, 3))*255

        # Update new values in plot
        def plot(self, val, label = "Fly Orientation"):
            self.val.append(int(val))
            while len(self.val) > self.width:
                self.val.pop(0)

            self.show_plot(label)

        # Show plot using opencv imshow
        def show_plot(self, label):
            self.plot_canvas = np.ones((self.height, self.width, 3))*255
            cv2.line(self.plot_canvas, (0, int(self.height/2) ), (self.width, int(self.height/2)), (0,255,0), 1)
            for i in range(len(self.val)-1):
                cv2.line(self.plot_canvas, (i, int(self.height/2) - self.val[i]), (i+1, int(self.height/2) - self.val[i+1]), self.color, 1)

            cv2.imshow(label, self.plot_canvas)
            cv2.waitKey(10)
    
    EllipseData_x = [0]
    EllipseData_y = [0]
    EllipseData_angle = [0]
    Timestamps = [0]

    def on_change(val):
        global thresh
        imageCopy = resized.copy()
        ret, thresh = cv2.threshold(imageCopy, val, 255, cv2.THRESH_BINARY)
        cv2.imshow('Thresholded', thresh)
        thresh = val

    # Read video using PyQt5 library
    ####POSSIBLY USE PyQt ALSO TO DESIGN A PROPER GUI
    app = QApplication(sys.argv)
    filename = QFileDialog.getOpenFileName(caption='Open file')
    ###########################################################

    video = cv2.VideoCapture(filename[0])

    # Exit if video not opened.
    if not video.isOpened():
        print ("Could not open video")
        sys.exit()

    # Read first frame.
    ok, frame = video.read()
    if not ok:
        print ('Cannot read video file')
        sys.exit()

    img = frame
    img2 = np.zeros((100,200,3), np.uint8)

    scale_percent = 500/img.shape[1]*100 # percent of original size
    width = int(img.shape[1] * scale_percent / 100)
    height = int(img.shape[0] * scale_percent / 100)
    dim = (width, height)
    
    # resize image
    resized = cv2.resize(img, dim)
    resized = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)

    cv2.namedWindow("Original", cv2.WINDOW_NORMAL)

    ####THIS IS THE "CONTROLS" WINDOW################
    cv2.namedWindow("Controls", cv2.WINDOW_AUTOSIZE)
    cv2.createTrackbar('thrshld', 'Controls', 127, 255, on_change)
    # cv2.createTrackbar("ROI", "Controls", 0, 1, back)
    cv2.imshow("Controls", img2)
    cv2.moveWindow("Controls", 0, round(height)+30)
    ##################################################

    cv2.namedWindow("Thresholded", cv2.WINDOW_NORMAL)
    cv2.moveWindow("Thresholded", round(width+1), 0)
    
    cv2.imshow('Original', resized)

    cv2.waitKey(0)
    cv2.destroyAllWindows()
    
    # Set up tracker. These are not all available... it depends on the 
    # version of opencv that you have,
 
    tracker_types = ['BOOSTING', 'MIL','KCF', 'TLD', 'MEDIANFLOW', 
    'GOTURN', 'MOSSE', 'CSRT']
    tracker_type = tracker_types[2]

    if tracker_type == 'BOOSTING':
        tracker = cv2.TrackerBoosting_create()
    if tracker_type == 'MIL':
        tracker = cv2.TrackerMIL_create()
    if tracker_type == 'KCF':
        tracker = cv2.TrackerKCF_create()
    if tracker_type == 'TLD':
        tracker = cv2.TrackerTLD_create()
    if tracker_type == 'MEDIANFLOW':
        tracker = cv2.TrackerMedianFlow_create()
    if tracker_type == 'GOTURN':
        tracker = cv2.TrackerGOTURN_create()
    if tracker_type == 'MOSSE':
        tracker = cv2.TrackerMOSSE_create()
    if tracker_type == "CSRT":
        tracker = cv2.TrackerCSRT_create()

    ####DEFINITIONS FOR LIVE PLOTTING
    # Create a plotter class object
    p = Plotter(400, 200)

    # Read video
    video = cv2.VideoCapture(filename[0])
 
    # Exit if video not opened.
    if not video.isOpened():
        print ("Could not open video")
        sys.exit()
 
    # Read first frame.
    ok, frame = video.read()
    Frame_Number = 0
    if not ok:
        print ('Cannot read video file')
        sys.exit()
     
    # Define an initial bounding box
    bbox = cv2.selectROI('ROI Selector', frame, True, True)
    cv2.destroyAllWindows()
 
    # Initialize KCF tracker with first frame and bounding box
    ok = tracker.init(frame, bbox)
    
    # used to record the time when we processed last frame
    prev_frame_time = 0
  
    # used to record the time at which we processed current frame
    new_frame_time = 0

    #####READ IN FRAMES IN SEPARATE THREAD
    #####TO SPEED UP TRACKING...

    # start the file video stream thread and allow the buffer to
    # start to fill
    print("[INFO] starting video file thread...")
    fvs = FileVideoStream(filename[0]).start()
    time.sleep(1.0)

    #####THIS IS FOR THE TRACKBAR DEFINED BELOW
    def nothing(x):
            pass

    cv2.namedWindow("Controls", cv2.WINDOW_AUTOSIZE)
    cv2.imshow("Controls", img2)
    cv2.createTrackbar('STOP/START', "Controls", 0, 1, nothing)
    cv2.moveWindow("Controls", 0, 250)
    cv2.namedWindow("Fly Tracker", cv2.WINDOW_AUTOSIZE)
    cv2.moveWindow("Fly Tracker", 401, 0)
    #############################################################

    #####THIS IS PSYCHOPY STUFF####################
    win = visual.Window((500, 500), allowGUI=True, winType='pyglet', 
                        color=(-1,-1,-1))

    # Initialize some stimuli
    dotPatch_1 = visual.DotStim(win, color=(0, 0, 1.0), dir=0,
        nDots=100, fieldShape='circle', fieldPos=(0.0, 0.0), fieldSize=1,
        dotSize=20,
        dotLife=-1,  # number of frames for each dot to be drawn
        signalDots='same',  # are signal dots 'same' on each frame? (see Scase et al)
        noiseDots='walk',  # do the noise dots follow random- 'walk', 'direction', or 'position'
        speed=0.01, coherence=1.0)

    dotPatch_2 = visual.DotStim(win, color=(0, 1.0, 0), dir=180,
        nDots=100, fieldShape='circle', fieldPos=(0.0, 0.0), fieldSize=1,
        dotSize=20,
        dotLife=-1,  # number of frames for each dot to be drawn
        signalDots='same',  # are signal dots 'same' on each frame? (see Scase et al)
        noiseDots='direction',  # do the noise dots follow random- 'walk', 'direction', or 'position'
        speed=0.01, coherence=1.0)
    #####END OF PSYCHOPY STUFF########################################
    ##################################################################

    # loop over frames from the video file stream
    while fvs.more():
        # Read a new frame
        frame = fvs.read()

        # Update KCF tracker
        if(frame is None):
            break
        
        ok, bbox = tracker.update(frame)

        ROI = frame[int(bbox[1]):int(bbox[1]+bbox[3]), 
                        int(bbox[0]):int(bbox[0]+bbox[2])]
             
        ROI = cv2.cvtColor(ROI, cv2.COLOR_BGR2GRAY)

        ret, frame_roi = cv2.threshold(ROI, thresh, 255, cv2.THRESH_BINARY)

        #####FIND PIXELS OF IDENTIFIED OBJECT
        [j, i] = np.where(frame_roi)


        # find contours of the object:
        contours, _ = cv2.findContours(frame_roi, cv2.RETR_TREE, 
                                       cv2.CHAIN_APPROX_SIMPLE)
        
        # for every contour:
        for cnt in contours:

            area = cv2.contourArea(cnt)
            if (len(cnt)>5 and area >= 100):  # skip objects smaller than 10x10

                ellipse = cv2.fitEllipse(cnt)

                # Fit Results:
                x = ellipse[0][0] + bbox[0]  # center x
                y = ellipse[0][1] + bbox[1] # center y
                angle = ellipse[2]  # angle
                a_min = ellipse[1][0]  # minor axis
                a_max = ellipse[1][1]  # major axis
                angle_rad = np.deg2rad(angle) + np.pi/2 # angle in rads

                #Make arrays to store data and save in file
                #at the end of the tracking process
                EllipseData_x.append(x)
                EllipseData_y.append(y)
                EllipseData_angle.append(angle)
                Timestamps.append(new_frame_time)
                
                #####THIS ALL WORKS, JUST NOT USING IT FOR THE MOMENT
                #######################################################
                # # Ellipse focal points
                # d = np.sqrt(a_max ** 2 - a_min ** 2)
                # x1 = x + d*np.cos(angle_rad) 
                # y1 = y + d*np.sin(angle_rad) 
                # x2 = x - d*np.cos(angle_rad)
                # y2 = y - d*np.sin(angle_rad)

                
                # tmp = np.matmul(np.transpose([i-np.mean(i), j-np.mean(j)]), 
                #                 [[np.cos(angle_rad), -np.sin(angle_rad)],
                #                  [np.sin(angle_rad), np.cos(angle_rad)]])
                # if (skew(tmp[:,1]) > 0):
                #     # Fix direction
                #     angle = np.mod(angle_rad + np.pi,2 * np.pi)
                #     tmp = np.array([x1,y1])
                #     # Swap F1 and F2
                #     x1 = x2
                #     y1 = y2
                #     x2 = tmp[0]
                #     y2 = tmp[1]
            ############################################################
            ############################################################

        # Draw bounding box
        if ok:
            Frame_Number = Frame_Number + 1
            # Tracking success
            # p1 = (int(bbox[0]), int(bbox[1]))
            # p2 = (int(bbox[0] + bbox[2]), int(bbox[1] + bbox[3]))
            # cv2.rectangle(frame, p1, p2, (255,0,0), 2, 1)
            #blank = np.zeros((1, 1))

            new_frame_time = time.time()

            # Calculating the fps
  
            # fps will be number of frames processed in given time frame
            # since there will be at most a time error of 0.001 seconds
            # we will be subtracting it to get a more accurate result
            fps = 1/(new_frame_time-prev_frame_time)
            prev_frame_time = new_frame_time

            ###IF YOU WANT TO DRAW COLOURED MARKERS ON A B/W IMAGE
            ###YOU HAVE TO FIRST CONVERT IT TO A THREE CHANNEL 
            ### "FAKE" COLOURED IMAGE
            #RGB_frame = cv2.merge([frame_roi, frame_roi, frame_roi]) 
            
            #Calculate centroid
            cv2.circle(frame,(int(x), int(y)), 5, (0,0,255), -1 )
            # cv2.circle(frame,(int(x1), int(y1)), 5, (0,255,255), -1 )
            # cv2.circle(frame,(int(x2), int(y2)), 5, (255,0,255), -1 )

            cv2.ellipse(frame, ((x, y), (a_min, a_max), angle), (0,255,0),2 )
        
        else :
            # Tracking failure
            cv2.putText(frame, "Tracking failure detected", (100,80), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.75,(0,0,255), 2)
 
        # Display tracker type on frame
        cv2.putText(frame, tracker_type + " Tracker", (100,20), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.75, (50,170,50), 2)
     
        # Display FPS on frame
        cv2.putText(frame, "FPS : " + str(int(fps)), (100,50), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.75, (50,170,50), 2)
        
        # Display Frame Number on frame
        cv2.putText(frame, "Tracked : " + str(int(Frame_Number)), (100,80), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.75, (50,170,50), 2)
        
 
        # # Display result
        # #cv2.imshow('A Novel Thresh', blobs)
        # cv2.imshow("Tracking", frame)
        # ######LIVE PLOT DATA##########################
        # # call 'plot' method for realtime plot
        # p.plot(EllipseData_angle[Frame_Number]/2)
        # ##############################################

    ####THIS IS TO CONTROL TRACKING ON/OFF AT END OF SCRIPT        
        STOP_START = cv2.getTrackbarPos("STOP/START", "Controls")
        print(fps)
        
        if(STOP_START == 1):
            pass
        else:
            cv2.imshow("Fly Tracker", frame)
            #p.plot(EllipseData_angle[Frame_Number]/2)
    #######################################################

    #####THIS IS PSYCHOPY STUFF TO GENERATE THE DOT KINETOGRAM
    #####IN CLOSED LOOP WITH THE DIRECTION OF THE DOTS BEING CONTROLLED
    #####BY THE INSTANTANEOUS ORIENTATION OF THE FLY
        trialClock =core.Clock()
        if(EllipseData_angle[Frame_Number] > 90):
            dotPatch_1.dir = 0
            dotPatch_2.dir = 180
        else:
            dotPatch_1.dir = 180
            dotPatch_2.dir = 0
        dotPatch_1.draw()
        dotPatch_2.draw()
        #message.draw()
        win.flip()  # make the drawn things visible
        #event.clearEvents('mouse')  # only really needed for pygame windows
        
    #####END OF THE PSYCHOPY KINETOGRAM PART#################
    #########################################################

        # Exit if ESC pressed
        k = cv2.waitKey(1) & 0xff
        if k == 27 : break

# save data and cleanup
# np.savetxt("MAZ_Data.txt", 
#            np.c_[EllipseData_x, EllipseData_y, 
#                  EllipseData_angle], fmt="%10.5f %10.5f %10.5f", delimiter=",")

data = {'Timestamps': Timestamps,
        'xCoords': EllipseData_x, 
        'yCoords': EllipseData_y, 
        'angle': EllipseData_angle}
df = pd.DataFrame(data)
df.to_csv("MAZ_Data", sep=',', index=False, encoding='utf-8')

cv2.destroyAllWindows()
fvs.stop()
win.close()
core.quit()