//
//  ViewController.swift
//  holopointer
//
//  Created by Simo Virokannas on 12/13/20.
//

import Cocoa
import SceneKit

class ViewController: NSViewController {
    var kine : Kinect?
    var timer : Timer?
    var depthImg : CGImage?
    var colorImg : CGImage?
    @IBOutlet var depthImage : NSImageView!
    @IBOutlet var colorImage : NSImageView!
    @IBOutlet var tiltSlider : NSSlider!
    @IBOutlet var sceneView : SCNView!
    @IBOutlet var fileNameField : NSTextField!
    @IBOutlet var recButton : NSButton!
    var scene : SCNScene?
    var pointNode : SCNNode = SCNNode()
    var isRecording : Bool = false
    var frame : Int = 1

    override func viewDidLoad() {
        super.viewDidLoad()
        scene = SCNScene(named: "KinectPreview.scn")
        sceneView.scene = scene
        scene?.rootNode.addChildNode(pointNode)
        pointNode.scale = SCNVector3(3.0, 3.0, -6.0)
        pointNode.position = SCNVector3(0, 0, -64.0)
        fileNameField.stringValue = ""
    }
    
    override func viewWillDisappear() {
        self.kine = nil
        self.timer?.invalidate()
    }
    
    override func viewWillAppear() {
        self.kine = Kinect()
        self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(1.0/24.0), repeats: true, block: { (_) in
            self.refreshImage()
        })
        self.tiltSlider.isContinuous = true
        if let kine = self.kine {
            self.tiltSlider.doubleValue = kine.tilt
        }
    }
    
    @IBAction func sliderChanged(_ : Any) {
        if let kine = self.kine {
            kine.tilt = self.tiltSlider.doubleValue
        }
    }
    
    @IBAction func record(_ : Any) {
        if isRecording {
            // stop
            self.recButton.title = "⏺"
            self.isRecording = false
        } else {
            // start
            self.recButton.title = "⏹"
            self.isRecording = true
            if fileNameField.stringValue == "" {
                fileNameField.stringValue = "/tmp/out.####.usdc"
            }
        }
    }
    
    func refreshImage() {
        if let kine = self.kine {
            self.depthImg = kine.depthImage
            if let img = self.depthImg {
                depthImage.image = NSImage(cgImage: img, size: NSSize(width: 640, height: 480))
            }
            self.colorImg = kine.colorImage
            if let bimg = self.colorImg {
                colorImage.image = NSImage(cgImage: bimg, size: NSSize(width: 640, height: 480))
            }
            let points = kine.readPoints(10000)
            let src = SCNGeometrySource(vertices: points)
            let elements = SCNGeometryElement(data: nil, primitiveType: .point, primitiveCount: points.count, bytesPerIndex: 4)
            elements.pointSize = 5.0
            elements.minimumPointScreenSpaceRadius = 1.0
            elements.maximumPointScreenSpaceRadius = 5.0
            pointNode.geometry = SCNGeometry(sources: [src], elements: [elements])
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = SCNVector4(1, 1, 1, 1)
            pointNode.geometry!.materials = [mat]
            pointNode.eulerAngles = SCNVector3((self.tiltSlider.doubleValue + 4.0) * 0.0174533, 0, 0)
            if isRecording {
                let framenum = String(format: "%04d", self.frame)
                let filename = fileNameField.stringValue.replacingOccurrences(of: "####", with: framenum)
                USDSwift.writePoints(toFile:filename, points:points, npoints:Int32(points.count))
                self.recButton.title = "⏹ (\(self.frame))"
                self.frame += 1
            }
        }
    }
}

