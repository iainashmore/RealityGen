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
    func didGenerateImages( images: [MLMultiArray],final:Bool)
    func didProgress( progress: Float)
    func didChangeState(state: GenerationState)
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
        let images: [MLMultiArray]
    }



    var delegate: PixelGeneratorDelegate?
    
    var generationState: GenerationState = .idle
    var generatedImages: GeneratedImages?
    var progressStep: (step: Int, stepCount: Int) = (0, 0) // (step, stepCount)

    private var sdPipeline: StableDiffusionPipeline?
    private var savingImageCount = 0
    private var savedImageCount = 0

    private func setState(_ state: GenerationState) { // for actor isolation
        generationState = state
        self.delegate?.didChangeState(state: state)
    }

    func setPipeline(_ pipeline: StableDiffusionPipeline) { // for actor isolation
        sdPipeline = pipeline
       // sdPipeline?.prewarmResources()
    }

    private func setGeneratedImages(_ images: GeneratedImages,final:Bool) { // for actor isolation
        print("images count",images.images.count)
        self.delegate?.didGenerateImages(images: images.images,final: final)
        generatedImages = images
        if final{
            self.delegate?.didProgress(progress: 0.0)
        }
    }

    private func setProgressStep(step: Int, stepCount: Int) {
        progressStep = (step, stepCount)
        self.delegate?.didProgress(progress: Float(step + 1)/Float(stepCount))
    }
    var shouldStop = false{
        didSet {
            if shouldStop{
                self.setState(.cancelling)
            }else{
                self.setState(.idle)
            }
        }
    }
}

// MARK: - Stable Diffusion

extension PixelGenerator {

    func reset(){
        shouldStop = true
    }
    
    
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
                
                        self.setProgressStep(step: 0, stepCount: param.stepCount)
                        var configuration = StableDiffusionPipeline.Configuration(prompt: param.prompt)
                        configuration.negativePrompt = param.negativePrompt
                        configuration.imageCount = param.imageCount
                        configuration.stepCount = param.stepCount
                        configuration.seed = UInt32(param.seed)
                        configuration.guidanceScale = param.guidanceScale
                        configuration.disableSafety = param.disableSafety

                      //  if self.progressStep.step % 2 == 0 {
                            print("process step \(self.progressStep.step)")
                            //let cgImages = try sdPipeline.generateImages(configuration: configuration, progressHandler: self.progressHandler)
                        if let images = try sdPipeline.generateImages2(configuration: configuration, progressHandler: self.progressHandler){
                            
                            self.setGeneratedImages(GeneratedImages(parameter: param, images: images), final: true)
                        }
                     //   }
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
        
        if shouldStop{
            shouldStop = false
            return false
        }
        if progress.step < progress.stepCount - 1{
            
           // if progress.step % 1 == 0 {
                //if ProcessInfo.processInfo.isiOSAppOnMac {
            
            if let images = progress.currentImagesArray {
                
                
                let generatedImages = GeneratedImages(parameter: GenerationParameter(prompt: progress.prompt,
                                                                                     negativePrompt: "", // progress does not provide this now
                                                                                     guidanceScale: 0.0, // progress does not provide this now
                                                                                     seed: 0,
                                                                                     stepCount: progress.stepCount,
                                                                                     imageCount: images.count,
                                                                                     disableSafety: progress.isSafetyEnabled),
                                                      images: images
                )
                DispatchQueue.main.async {
                    self.setGeneratedImages(generatedImages,final: false)
                    self.setProgressStep(step: progress.step, stepCount: progress.stepCount)
                }
            }
           // }else{
            //    DispatchQueue.main.async {
            //        self.setProgressStep(step: progress.step, stepCount: progress.stepCount)
            //    }
            //}
            
           
           
     
        }
        
        return true
    }
}


extension UIImage {
    func resizeCI(size:CGSize) -> UIImage? {
        let scale = (Double)(size.width) / (Double)(self.size.width)
        let image = UIKit.CIImage(cgImage:self.cgImage!)
            
            let filter = CIFilter(name: "CILanczosScaleTransform")!
            filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value:scale), forKey: kCIInputScaleKey)
            filter.setValue(1.0, forKey:kCIInputAspectRatioKey)
        let outputImage = filter.value(forKey: kCIOutputImageKey) as! UIKit.CIImage
            
        let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        let resizedImage = UIImage(cgImage: context.createCGImage(outputImage, from: outputImage.extent)!)
            return resizedImage
    }
    

}

extension CGImage {
    
    func resizeAsCG(toSize:CGSize,fromSize:CGSize) -> CGImage? {
        let scale = (Double)(toSize.width) / (Double)(fromSize.width)
        let image = UIKit.CIImage(cgImage:self)
            
            let filter = CIFilter(name: "CILanczosScaleTransform")!
            filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value:scale), forKey: kCIInputScaleKey)
            filter.setValue(1.0, forKey:kCIInputAspectRatioKey)
        let outputImage = filter.value(forKey: kCIOutputImageKey) as! UIKit.CIImage
            
        let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        return context.createCGImage(outputImage, from: outputImage.extent)
    }
    
    func getPixelColor2(_ x: Int,_ y:Int,_ length:Int) -> SIMD3<Float>{

        let pixelData = self.dataProvider?.data
           
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)

        let pixelInfo: Int = (length * y) + (x * 4)

        var r = Float(data[pixelInfo]) / Float(255.0)
        var g = Float(data[pixelInfo+1]) / Float(255.0)
        var b = Float(data[pixelInfo+2]) / Float(255.0)

        if x > 16 && y > 16{
            r = 0
            g = 0
            b = 0
        }
        return [r,g,b]
    }
    
    func getPixelColor(_ x:Int,_ y:Int, _ data: CFData)-> SIMD3<Float>{
       
       
        guard let bytes = CFDataGetBytePtr(data) else {return .zero}
        let bytesPerPixel = self.bitsPerPixel / self.bitsPerComponent
        let offset = (y * self.bytesPerRow) + (x * bytesPerPixel)
        let r = Float(bytes[offset]) / 255.0
        let g = Float(bytes[offset + 1]) / 255.0
        let b = Float(bytes[offset + 2]) / 255.0
        return [r,g,b]
    }
}

func getIndex(_ x:Int,_ y:Int)->Int{
    let i =  x + (kImageLength * y)
    return i
}
