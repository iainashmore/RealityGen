//
//  ContentView.swift
//  RealityGen
//
//  Created by Iain Ashmore on 15/10/2024.
//

import SwiftUI
import RealityKit

class SceneContent {
  
    let customEntity = MascotEntity()

    func update(timestep: TimeInterval) {
        customEntity.updateMesh(true)
    }
}

let animationFrameDuration: TimeInterval = 1.0 / 60.0


struct ContentView : View {
    
    @ObservedObject private var imageGenerator = ImageGenerator()
    @State private var generationParameter =
        ImageGenerator.GenerationParameter(
                                           prompt: "Lego man",
                                           negativePrompt: "",
                                           guidanceScale: 8.0,
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
        }
        VStack{
            if let generatedImages = imageGenerator.generatedImages {
             
                VStack{
                    Image(uiImage: generatedImages.images[0])
                            .resizable()
                            .scaledToFit()
                }
            }
           Button("Generate Image") {
               generate()
            }
        }
    }
    
    func generate() {
        imageGenerator.generateImages(of: generationParameter, enableStableDiffusion: true)
    }
}

#Preview {
    ContentView()
}
