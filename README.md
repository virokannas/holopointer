# holopointer
A quick and easy kinect-to-pointcloud converter for MacOS/Swift/Cocoa

![preview](images/pointcloud_preview.png)

## Why?

It's cool I guess.

## Contents

Under holopointer/libusb-1.0 is a version of libusb that happens to work with the Kinects. This is included as a precompiled library for convenience. It's probably veeeeery old. Also, under holopointer/kinect is a slightly modified version of libfreenect's kinect component. There's a couple of new methods to make alloc/dealloc possible through Swift. Both of these are pulled almost as-is from the cocoaKinect project.
