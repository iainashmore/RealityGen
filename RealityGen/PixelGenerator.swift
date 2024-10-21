//
//  ImageGenerator.swift
//  ardiffusionmuseum
//
//  Created by Yasuhito Nagatomo on 2022/12/08.
//

import UIKit
import StableDiffusion
import CoreML


protocol PixelGeneratorDelegate : AnyObject {
    func didGenerateImages( images: [UIImage])
}



class PixelGenerator: NSObject, ObservableObject {
    
    struct GenerationParameter {
        let prompt: String
        let negativePrompt: String
        let guidanceScale: Float
        let seed: Int
        let stepCount: Int
        let imageCount: Int
        let disableSafety: Bool
    }

    struct GeneratedImages {
        let parameter: GenerationParameter
        let images: [UIImage]
    }

    enum GenerationState {
        case idle       // idling
        case generating // generating images
        case saving     // saving images into Photo Library
    }

    var delegate: PixelGeneratorDelegate?
    
    var generationState: GenerationState = .idle
    var generatedImages: GeneratedImages?
    var progressStep: (step: Int, stepCount: Int) = (0, 0) // (step, stepCount)

    private var sdPipeline: StableDiffusionPipeline?
    private var savingImageCount = 0
    private var savedImageCount = 0

   
    //    func removeSDPipeline() {
    //        sdPipeline = nil    // to reduce memory consumption :(
    //    }

    private func setState(_ state: GenerationState) { // for actor isolation
        generationState = state
    }

    func setPipeline(_ pipeline: StableDiffusionPipeline) { // for actor isolation
        sdPipeline = pipeline
    }

    private func setGeneratedImages(_ images: GeneratedImages) { // for actor isolation
        print("images count",images.images.count)
        self.delegate?.didGenerateImages(images: images.images)
        generatedImages = images
    }

    private func setProgressStep(step: Int, stepCount: Int) {
        progressStep = (step, stepCount)
    }
}

// MARK: - Stable Diffusion

extension PixelGenerator {

    func generateImages(of param: GenerationParameter, enableStableDiffusion: Bool) {
       
        guard generationState == .idle else { return }

        if enableStableDiffusion {
            
            if param.prompt == "" { return }

            Task.detached(priority: .high) {
                self.setState(.generating)

                if self.sdPipeline == nil {

                    let bundleURL = Bundle.main.bundleURL
                 
                    let resourceURL = bundleURL//.appending(path: "Resources2")
                  
                    let config = MLModelConfiguration()
                    if !ProcessInfo.processInfo.isiOSAppOnMac {
                        config.computeUnits = .cpuAndGPU
                    }
                    print("creating StableDiffusionPipeline object... resosurceURL = \(resourceURL)")

                    // reduceMemory option was added at v0.1.0
                    // On iOS, the reduceMemory option should be set to true
                    let reduceMemory = ProcessInfo.processInfo.isiOSAppOnMac ? false : true
               
                    if let pipeline = try? StableDiffusionPipeline( resourcesAt: resourceURL,
                                                                    controlNet: [],
                                                                    configuration: config, reduceMemory: reduceMemory) {
                        self.setPipeline(pipeline)
                    } else {
                        fatalError("Fatal error: failed to create the Stable-Diffusion-Pipeline.")
                    }
                }

                if let sdPipeline = await self.sdPipeline {

                    // Generate images

                    do {
                       // debugLog("IG: generating images...")
                        self.setProgressStep(step: 0, stepCount: param.stepCount)
                        // [v1.3.0]
                        // apple/ml-stable-diffusion v0.2.0 changed the generateImages() API
                        // to generateImages(configuration:progressHandler:)
                        //
                        //    let cgImages = try sdPipeline.generateImages(prompt: param.prompt,
                        //                                                 negativePrompt: param.negativePrompt,
                        //                                                 imageCount: param.imageCount,
                        //                                                 stepCount: param.stepCount,
                        //                                                 seed: UInt32(param.seed),
                        //                                                 guidanceScale: param.guidanceScale,
                        //                                                 disableSafety: param.disableSafety,
                        //                                                 progressHandler: self.progressHandler)

                        // [Note] Mode: textToImage or imageToImage
                        //        when startingImage != nil AND strength < 1.0, imageToImage mode is selected
                        var configuration = StableDiffusionPipeline.Configuration(prompt: param.prompt)
                        configuration.negativePrompt = param.negativePrompt
                        configuration.imageCount = param.imageCount
                        configuration.stepCount = param.stepCount
                        configuration.seed = UInt32(param.seed)
                        configuration.guidanceScale = param.guidanceScale
                        configuration.disableSafety = param.disableSafety
                        let cgImages = try sdPipeline.generateImages(configuration: configuration,
                                                                     progressHandler: self.progressHandler)

                        //debugLog("IG: images were generated.")
                        let uiImages = cgImages.compactMap { image in
                            if let cgImage = image { return UIImage(cgImage: cgImage)
                            } else { return nil }
                        }
                        self.setGeneratedImages(GeneratedImages(parameter: param, images: uiImages))
                    } catch {
                        print("failed to generate images.")
                    }
                }

                self.setState(.idle)
            }
        } 
    }

    nonisolated func progressHandler(progress: StableDiffusionPipeline.Progress) -> Bool {
        print("Progress: step / stepCount = \(progress.step) / \(progress.stepCount)")

        //if ProcessInfo.processInfo.isiOSAppOnMac {
            let generatedImages = GeneratedImages(parameter: GenerationParameter(prompt: progress.prompt,
                                                                                 negativePrompt: "", // progress does not provide this now
                                                 guidanceScale: 0.0, // progress does not provide this now
                                                 seed: 0,
                                                 stepCount: progress.stepCount,
                                                 imageCount: progress.currentImages.count,
                                                 disableSafety: progress.isSafetyEnabled),
                                                 images: progress.currentImages.compactMap {
                if let cgImage = $0 {
                    print("image size",cgImage.width,cgImage.height)
                    return UIImage(cgImage: cgImage)
                } else {
                    return nil
                }
            })

            DispatchQueue.main.async {
                self.setGeneratedImages(generatedImages)
                self.setProgressStep(step: progress.step, stepCount: progress.stepCount)
            }
       // } else {
       //     DispatchQueue.main.async {
       //         self.setProgressStep(step: progress.step, stepCount: progress.stepCount)
       //     }
       // }

        return true // continue
    }
}


