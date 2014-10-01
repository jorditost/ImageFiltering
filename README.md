Image Filtering
=================

This repository will contain a set of examples and tests to filter and calibrate a video source using [Processing](http://processing.org) and [OpenCV](http://opencv.org/).

This code uses the [OpenCV library for Processing](https://github.com/atduskgreg/opencv-processing) by Greg Borenstein.


##Filtering the image for blob detection

The following sketch should help us to filter the source image for blob detection. It requires the [controlP5](http://www.sojamo.de/libraries/controlP5/) library.

Code: [ImageFiltering.pde](ImageFiltering/ImageFiltering.pde)

The sketch is doing the following:

- __Adjust contrast:__ highlight blobs
- __Thresholding:__ (Basic OR adaptive)
- __Noise reduction:__ (with dilation and erosion)
- __Blur filter:__ to remove remaining background noise
- __Set minimal blob size:__ to eliminate small blobs (spots, etc) that may be in the background.

#### Using basic thresholding

Thresholding is one of the most important filtering operations.
![](ImageFiltering/screenshots/objects_basic_threshold.png)

### Using adaptive thresholding
Adaptive thresholding is a more advanced option to filter your image. For environments with changing illumination or if you simply get a source image with shadows or irregular illumination, try better this. You can see an example in the next image, where the 

![](ImageFiltering/screenshots/touch_adaptive_threshold.png)

Just open the sketch and do some tests ;)

##Future Work
In the future this repository will contain more sketches for color tracking, camera calibration, etc.


##More
For more info about OpenCV and more examples, visit the library's github repository:
[https://github.com/atduskgreg/opencv-processing](https://github.com/atduskgreg/opencv-processing)

The plugin's author, Greg Borenstein, is also working on a book. You can check some more examples and doc pages in its repository:
[https://github.com/atduskgreg/opencv-processing-book](https://github.com/atduskgreg/opencv-processing-book)
