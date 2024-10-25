//
//  ContentView.swift
//  RealityGen
//
//  Created by Iain Ashmore on 15/10/2024.
//

import SwiftUI
import RealityKit
import CoreML

class SceneContent : PixelGeneratorDelegate {
 
    
    init() {
        
        print("setup scene content")
        self.pixelGenerator.delegate = self
    }
  
    let customEntity = MascotEntity()
    
    var pixelGenerator = PixelGenerator()
    @Published var generatedImage : UIImage?
    @Published var sceneState : String = ""
    @Published var progress : Float = 0
    @Published var generating = false
    var frameCount = 0
    func update(timestep: TimeInterval) {
        frameCount += 1
        if generating && frameCount > 15 && progress > 0 && progress < 0.9{
           // customEntity.updateWithSparkle()
            frameCount = 0
        }
        //customEntity.updateMesh(true)
    }
    
    func didChangeState(state: GenerationState) {
        switch state {
        case .idle:
            sceneState = "Ready"
            generating = false
        case .generating:
            sceneState = "Generating..."
            generating = true
        case .cancelling:
            sceneState = "Cancelling..."
            generating = true
        default:
            sceneState = "Waiting"
            generating = true
        }
    }
    
    func resetPipeline(){
        pixelGenerator.shouldStop = true
    }
    
    func generateImage(text:String){
        
        progress = 0.05
        let generationParameter =
        PixelGenerator.GenerationParameter(
            prompt: kPromptPrefix + text + kPromptSuffix,
            negativePrompt: kNegativePrompt,
            guidanceScale: 10.0,
            seed: 1_000_000,
            stepCount: kStepCount,
            imageCount: 1,
            disableSafety: false)

        pixelGenerator.generateImages(of: generationParameter, enableStableDiffusion: true)
        
    }
    
    func didProgress(progress: Float) {
        self.progress = progress
    }
    
    func didGenerateImages(images: [MLMultiArray], final: Bool) {
        //"Float32 1 × 3 × 64 × 64 array"
        print(images.count)
        if let image = [images].first{
            let x = 0
            let y = 0
            let z = 0
            let key = [0,0,0] as [NSNumber]
            
            
            let value = image[0][0]
            print(image.count)
            customEntity.updateWithArray(image, final)
           // mapImage(image[0])
        }
       
    }
 
    
    func didGenerateImages(images:[CGImage],final:Bool) {
        print("did generate Images",images.count)
        if let image = images.first{
            
            if let cgImage = image.resizeAsCG(toSize: CGSize(width:kImageLength, height: kImageLength), fromSize: CGSize(width: 64, height: 64)){
                if let data = cgImage.dataProvider?.data{
                    customEntity.updateWithImage(cgImage, final)
                    // if let scaledImage = image.resizeCI(size: CGSize(width: kImageLength, height: kImageLength)){
                    self.generatedImage = UIImage(cgImage: cgImage)
                    //}
                }
            }
        }
    }
    
    func newImage(images:[UIImage]) {
        print("new Images")
    }
}

let animationFrameDuration: TimeInterval = 1.0 / 60.0


struct ContentView : View {
    

    @State private var generationParameter =
        ImageGenerator.GenerationParameter(
                                           prompt: "Godzilla, full body game asset, in pixelsprite style",
                                           negativePrompt: "scenery",
                                           guidanceScale: 10.0,
                                           seed: 1_000_000,
                                           stepCount: 20,
                                           imageCount: 1, disableSafety: false)

    @State private var sceneContent = SceneContent()
    @State private var frameDuration: TimeInterval = 0.0
    @State private var lastUpdateTime = CACurrentMediaTime()

    private let timer = Timer.publish(every: animationFrameDuration, on: .main, in: .common).autoconnect()
    

    let anchorEntity = AnchorEntity(world: SIMD3<Float>(0, 0, -1.5))
    
    let anchorEntity2 = AnchorEntity(world: SIMD3<Float>(2, 0, 0))
    @State private var y : Float = 0
  
    @State var messageText : String = ""
    
    @FocusState var isTextFieldFocused: Bool
    var frameCount = 0
    var body: some View {
        
       
        ZStack{
            
            RealityView { content in
                
                anchorEntity.transform.rotation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(1, 0, 0))
                anchorEntity.addChild(sceneContent.customEntity)
                anchorEntity2.addChild(Lighting())
                content.add(anchorEntity)
                content.add(anchorEntity2)
                content.cameraTarget = anchorEntity
                //content.camera = .worldTracking
                
            } update: { content in
                
              
                 sceneContent.update(timestep: frameDuration)
                
            }
            .onReceive(timer) { input in
                let currentTime = CACurrentMediaTime()
                frameDuration = currentTime - lastUpdateTime
                lastUpdateTime = currentTime
                y += 0.01
                anchorEntity.transform.rotation = simd_quatf(angle: y, axis: SIMD3<Float>(0, 1, 0))
            }
            .ignoresSafeArea()
            
            VStack{
                Spacer()
                
                if let image = sceneContent.generatedImage {
                    VStack{
                        Image(uiImage: image).frame(width: 256,height: 256)
                    }
                }
                
                VStack{
                    if !sceneContent.sceneState.isEmpty{
                        HStack{
                            Text(verbatim: sceneContent.sceneState).foregroundStyle(.black)
                            Spacer()
                        }.padding(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                    }
                   
                    if sceneContent.progress > 0 {
                        HStack{
                            ProgressView(value: sceneContent.progress)
                            Button {
                                sceneContent.progress = 0
                                messageText = ""
                                sceneContent.resetPipeline()
                            } label: {
                                Image(systemName: "x.circle.fill")
                            }
                        }.padding(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                    }
                   
                    TextField("Describe", text: $messageText, onEditingChanged: { (changed) in
                        if changed {
                            print("text edit has begun")
                        } else {
                            print("committed the change")
                            self.sceneContent.generateImage(text: messageText)
                            messageText = ""
                            
                        }
                    }).disabled(sceneContent.generating)
                        .foregroundStyle(SwiftUI.Color(sceneContent.generating ? SwiftUI.Color(.gray) : .black))
                    .onAppear(perform: {
                            UITextField.appearance().clearButtonMode = .whileEditing
                        })
                    //.frame(height: 40)
                    //.clipShape(Capsule())
                    .padding()
                    //.background(SwiftUI.Color(sceneContent.generating ? .gray : .white))
                    .submitLabel(.done)
                    .background(
                         Capsule()
                            .strokeBorder(SwiftUI.Color.gray,lineWidth: 0.8)
                            .background(SwiftUI.Color(sceneContent.generating ? SwiftUI.Color(.lightText) : .white))
                             .clipped()
                     )
                     .clipShape(Capsule())
                }.padding(12).background(.white)
            }
        }
    }
    
   
}

#Preview {
    ContentView()
}
