import UIKit
import SceneKit
import ARKit

import Vision

class ViewController: UIViewController, ARSCNViewDelegate {
    

    @IBOutlet var sceneView: ARSCNView!
    let bubbleDepth : Float = 0.01
    var latestPrediction : String = "…"

    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml")
    @IBOutlet weak var debugTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
 
        sceneView.delegate = self
 
        sceneView.showsStatistics = true

        let scene = SCNScene()

        sceneView.scene = scene

        sceneView.autoenablesDefaultLighting = true

        // Tap Gesture Recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)

        guard let selectedModel = try? VNCoreMLModel(for: Food101().model) else {
            fatalError("Could not load model")
        }
        

        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        visionRequests = [classificationRequest]

        loopCoreMLUpdate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()

        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
 
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
 
        }
    }

    override var prefersStatusBarHidden : Bool {
        return false
    }

    
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {

        let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
        
        let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint])
        
        if let closestResult = arHitTestResults.first {

            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

            let node : SCNNode = createNewBubbleParentNode(latestPrediction)
            sceneView.scene.rootNode.addChildNode(node)
            node.position = worldCoord
        }
    }
    
    func createNewBubbleParentNode(_ text : String) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.

        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y

        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        //var font = UIFont(name: "Futura", size: 0.15)
        
        var font = UIFont(name: "Optima", size: 0.15)
        font = font?.withTraits(traits: .traitBold)
        bubble.font = font
        bubble.alignmentMode = kCAAlignmentCenter
        bubble.firstMaterial?.diffuse.contents = UIColor.green
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
     
        bubble.chamferRadius = CGFloat(bubbleDepth)
        
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)

        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)

        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
   
        let sphere = SCNSphere(radius: 0.05)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)
        
   
        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(bubbleNode)
        bubbleNodeParent.addChildNode(sphereNode)
        bubbleNodeParent.constraints = [billboardConstraint]
        
        return bubbleNodeParent
    }
    

    
    func loopCoreMLUpdate() {
     
        
        dispatchQueueML.async {
            self.updateCoreML()
            self.loopCoreMLUpdate()
        }
        
    }
    
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }
        
        // Get Classifications
        let classifications = observations[0...1] // top 2 results
            .flatMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:"- %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        
        DispatchQueue.main.async {
    
            print(classifications)
            print("--")
            
        
            var debugText:String = ""
            debugText += classifications
            self.debugTextView.text = debugText
        
            var objectName:String = "…"
            objectName = classifications.components(separatedBy: "-")[0]
            objectName = objectName.components(separatedBy: ",")[0]
            self.latestPrediction = objectName
            
        }
    }
    
    func updateCoreML() {

        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)

        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
        
    }
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}
