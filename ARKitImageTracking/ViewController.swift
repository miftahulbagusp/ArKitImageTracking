//
//  ViewController.swift
//  ARKitImageTracking
//
//  Created by Miftahul Bagus Pranoto on 7/7/21.
//

import UIKit
import SceneKit
import ARKit

struct AnimationInfo {
    var startTime: TimeInterval
    var duration: TimeInterval
    var initialModelPosition: simd_float3
    var finalModelPosition: simd_float3
    var initialModelOrientation: simd_quatf
    var finalModelOrientation: simd_quatf
}

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var arSceneView: ARSCNView!
    private var modelNode: SCNNode?
    private var imageNode: SCNNode?
    var animationInfo: AnimationInfo?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        arSceneView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else { fatalError("Missing expected asset catalog resources")}
        configuration.detectionImages = referenceImages
        arSceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arSceneView.session.pause()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let plane = createPlane(imageAnchor: imageAnchor)
        node.addChildNode(plane)
        plane.runAction(waitRemoveAction)
        show3DModel(imageAnchor: imageAnchor, modelName: "air_jordan_1_retro_high_white_university_blue_black.usdz")
        self.imageNode = node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let imageNode = imageNode, let modelNode = modelNode else { return }
        
        guard let animationInfo = animationInfo else {
            refreshAnimationVariables(startTime: time,
                                      initialPosition: modelNode.simdWorldPosition,
                                      finalPosition: imageNode.simdWorldPosition,
                                      initialOrientation: modelNode.simdWorldOrientation,
                                      finalOrientation: imageNode.simdWorldOrientation)
            return
        }
        
        if !simd_equal(animationInfo.finalModelPosition, imageNode.simdWorldPosition) ||  animationInfo.finalModelOrientation != imageNode.simdWorldOrientation {
            refreshAnimationVariables(startTime: time, initialPosition: modelNode.simdWorldPosition, finalPosition: imageNode.simdWorldPosition, initialOrientation: modelNode.simdWorldOrientation, finalOrientation: imageNode.simdWorldOrientation)
        }
        
        let passedTime = time - animationInfo.startTime
        var t = min(Float(passedTime/animationInfo.duration), 1)
        t = sin (t * .pi * 0.5)
        let f3t = simd_make_float3(t, t, t)
        modelNode.simdWorldPosition = simd_mix(animationInfo.initialModelPosition, animationInfo.finalModelPosition, f3t)
        modelNode.simdWorldOrientation = simd_slerp(animationInfo.initialModelOrientation, animationInfo.finalModelOrientation, t)
    }
    
    func refreshAnimationVariables(startTime: TimeInterval, initialPosition: simd_float3, finalPosition: simd_float3, initialOrientation: simd_quatf, finalOrientation: simd_quatf) {
        let distance = simd_distance(initialPosition, finalPosition)
        let speed = Float(0.15)
        let animationDuration = Double(min(max(0,1, distance/speed), 2))
        animationInfo = AnimationInfo(startTime: startTime, duration: animationDuration, initialModelPosition: initialPosition, finalModelPosition: finalPosition, initialModelOrientation: initialOrientation, finalModelOrientation: finalOrientation)
    }
    
    func createPlane(imageAnchor : ARImageAnchor) -> SCNNode {
        let planeNode = SCNNode()
        let referenceImage = imageAnchor.referenceImage
        let planeGeometry = SCNPlane(width: referenceImage.physicalSize.width, height: referenceImage.physicalSize.height)
        planeGeometry.firstMaterial?.diffuse.contents = UIColor.blue
        planeNode.geometry = planeGeometry
        planeNode.eulerAngles.x = -Float.pi / 2
        planeNode.opacity = 0.5
        return planeNode
    }
    
    func show3DModel(imageAnchor : ARImageAnchor, modelName : String) {
        let modelScene = SCNScene(named: modelName)!
        let modelNode = modelScene.rootNode
        let (min, max) = modelNode.boundingBox
        let size = SCNVector3Make(max.x - min.x, max.y - min.y, max.z - min.z)
        let widthRatio = Float(imageAnchor.referenceImage.physicalSize.width) / size.x
        let heightRatio = Float(imageAnchor.referenceImage.physicalSize.height) / size.z
        let finalRatio = [widthRatio, heightRatio].min()!
        modelNode.transform = SCNMatrix4(imageAnchor.transform)
        let appearanceAction = SCNAction.scale(to: CGFloat(finalRatio), duration: 0.4)
        appearanceAction.timingMode = .easeOut
        modelNode.scale = SCNVector3Make(0.001, 0.001, 0.001)
        arSceneView.scene.rootNode.addChildNode(modelNode)
        modelNode.runAction(appearanceAction)
        self.modelNode = modelNode
        
    }
    
    var waitRemoveAction: SCNAction {
        return .sequence([.wait(duration: 1.5), .fadeOut(duration: 1.0), .removeFromParentNode()])
    }

}

