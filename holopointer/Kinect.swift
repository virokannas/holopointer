//
//  Kinect.swift
//  holopointer / libfreenect bridge
//
//  Created by Simo Virokannas on 12/13/20.
//

import Foundation
import SceneKit

extension CGFloat {
    func Lerp(_ other: CGFloat, _ factor: CGFloat) -> CGFloat {
        return self * factor + other * (1.0 - factor)
    }
}

class Kinect {
    static let MAX_POINTS : Int = 65536
    static var shared : Kinect?
    var pointBuffer : [SCNVector3] = [SCNVector3](repeating: SCNVector3(0, 0, 0), count: MAX_POINTS)
    private var randomPoints : [Int] = []
    private var context : OpaquePointer?
    private var device : OpaquePointer?
    private var thread : Thread?
    private var capturing : Bool = false
    private var depthMap : UnsafeMutableRawPointer
    private var depthLock : NSLock = NSLock()
    private var colorMap : UnsafeMutableRawPointer
    private var colorLock : NSLock = NSLock()
    var nearClip : Int = 0
    var farClip : Int = 2047
    init() {
        // initialize MAX_POINTS random points
        for _ in 0 ..< Kinect.MAX_POINTS {
            // x, y
            randomPoints.append(Int.random(in: 0..<640))
            randomPoints.append(Int.random(in: 0..<480))
        }
        self.context = freenect_init_bridged(nil)
        let numDevices = freenect_num_devices(self.context)
        print("Found \(numDevices) Kinect devices!")
        depthMap = UnsafeMutableRawPointer.allocate(byteCount: Int(FREENECT_DEPTH_11BIT_SIZE), alignment: 0)
        colorMap = UnsafeMutableRawPointer.allocate(byteCount: Int(FREENECT_VIDEO_RGB_SIZE), alignment: 0)
        if numDevices == 0 {
            self.device = nil
        } else {
            self.device = freenect_open_device_bridged(self.context, 0)
            if let device = self.device {
                print("Starting capture...")
                freenect_set_depth_format(device, FREENECT_DEPTH_11BIT)
                freenect_set_video_format(device, FREENECT_VIDEO_RGB)
                freenect_set_user(device, nil)
                freenect_set_depth_callback(device) { (device, depthData, timestamp) in
                    if let kinect = Kinect.shared {
                        kinect.depthLock.lock()
                        kinect.depthMap.copyMemory(from: depthData!, byteCount: Int(FREENECT_DEPTH_11BIT_SIZE))
                        kinect.depthLock.unlock()
                    }
                }
                freenect_set_video_callback(device) { (device, videoData, timestamp) in
                    if let kinect = Kinect.shared {
                        kinect.colorLock.lock()
                        kinect.colorMap.copyMemory(from: videoData!, byteCount: Int(FREENECT_VIDEO_RGB_SIZE))
                        kinect.colorLock.unlock()
                    }
                }
                freenect_start_depth(device)
                freenect_start_video(device)
                self.capturing = true
                DispatchQueue.global(qos: .userInteractive).async() {
                    while self.capturing {
                        self.scan()
                        Thread.sleep(forTimeInterval: 1.0 / 1000.0)
                    }
                }
            }
        }
        Kinect.shared = self
    }
    func scan() {
        if let _ = self.device, let context = self.context {
            freenect_process_events(context)
        } else {
            print("Nope")
        }
    }
    var depthImage : CGImage? {
        self.depthLock.lock()
        let info : CGBitmapInfo = CGBitmapInfo.init([CGBitmapInfo.byteOrder16Little])
        let img = CGImage(width: 640, height: 480, bitsPerComponent: 16, bitsPerPixel: 16, bytesPerRow: 1280, space: CGColorSpace(calibratedGrayWhitePoint: [1.0, 1.0, 1.0], blackPoint: [0.2, 0.2, 0.2], gamma: 0.02)!, bitmapInfo: info, provider: CGDataProvider(dataInfo: nil, data: self.depthMap, size: Int(FREENECT_DEPTH_11BIT_SIZE), releaseData: { (_, _, _) in })!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        self.depthLock.unlock()
        return img
    }
    var colorImage : CGImage? {
        self.colorLock.lock()
        let info : CGBitmapInfo = CGBitmapInfo.init([])
        let img = CGImage(width: 640, height: 480, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: 640*3, space: CGColorSpace(name: CGColorSpace.genericRGBLinear)!, bitmapInfo: info, provider: CGDataProvider(dataInfo: nil, data: colorMap, size: Int(FREENECT_VIDEO_RGB_SIZE), releaseData: { (_, _, _) in })!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        self.colorLock.unlock()
        return img
    }
    
    func readPoints(_ n: Int) -> [SCNVector3] {
        var ret : [SCNVector3] = []
        self.depthLock.lock()
        let uintptr = UnsafePointer<UInt16>(OpaquePointer(self.depthMap))
        var minval = 655536
        var maxval = 0
        var dt = 0
        let scf : Float = 1.0 / 240.0 // scale down to unit
        for _ in 0 ..< n {
            let x = self.randomPoints[dt*2]
            let y = self.randomPoints[dt*2+1]
            let ofs = y * 640 + x
            let depth = uintptr[ofs]
            if depth < minval {
                minval = Int(depth)
            }
            if depth > maxval {
                maxval = Int(depth)
            }
            var z : Float = 0.0
            if (depth < farClip && depth > nearClip) {
                z = 0.1236 * tanf(Float(depth) / 2842.5 + 1.1863)
                //z = 1.0 / (-0.00307 * Float(depth) + 3.33) - 0.037
                let zd = z - 10.0
                self.pointBuffer[dt].x = CGFloat(Float(x - 320) * scf * zd)
                self.pointBuffer[dt].y = CGFloat(Float(y - 240) * scf * zd)
                self.pointBuffer[dt].z = CGFloat(z * 10.0) //self.pointBuffer[dt].z.Lerp(CGFloat(z), 0.5)
                ret.append(self.pointBuffer[dt])
            }
            dt += 1
        }
        self.depthLock.unlock()
        return ret
    }
    
    var tilt : Double  = 0.0{
        didSet {
            if let device = self.device {
                freenect_set_tilt_degs(device, tilt)
            }
        }
    }

    deinit {
        self.capturing = false
        if let device = self.device {
            print("Stopping capture...")
            freenect_stop_depth(device)
            freenect_stop_video(device)
            freenect_close_device(device)
            print("Capture stopped.")
        }
        depthMap.deallocate()
        colorMap.deallocate()
        freenect_shutdown(self.context)
    }
}
