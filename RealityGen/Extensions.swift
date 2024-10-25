//
//  extensions.swift
//  RealityGen
//
//  Created by Iain Ashmore on 23/10/2024.
//

import Accelerate
import CoreGraphics
import CoreML
import Foundation
import NaturalLanguage
import StableDiffusion

extension StableDiffusionPipeline{
    
    public func generateImages2(
        configuration config: Configuration,
        progressHandler: (Progress) -> Bool = { _ in true }
    ) throws -> [MLMultiArray]? {
        
        // Encode the input prompt and negative prompt
        let promptEmbedding = try textEncoder.encode(config.prompt)
        let negativePromptEmbedding = try textEncoder.encode(config.negativePrompt)
        
        if reduceMemory {
            textEncoder.unloadResources()
        }
        
        // Convert to Unet hidden state representation
        // Concatenate the prompt and negative prompt embeddings
        let concatEmbedding = MLShapedArray<Float32>(
            concatenating: [negativePromptEmbedding, promptEmbedding],
            alongAxis: 0
        )
        
        let hiddenStates = useMultilingualTextEncoder ? concatEmbedding : toHiddenStates(concatEmbedding)
        
        /// Setup schedulers
        let scheduler: [Scheduler] = (0..<config.imageCount).map { _ in
            switch config.schedulerType {
            case .pndmScheduler: return PNDMScheduler(stepCount: config.stepCount)
            case .dpmSolverMultistepScheduler: return DPMSolverMultistepScheduler(stepCount: config.stepCount, timeStepSpacing: config.schedulerTimestepSpacing)
            }
        }
        
        // Generate random latent samples from specified seed
        var latents: [MLShapedArray<Float32>] = try generateLatentSamples(configuration: config, scheduler: scheduler[0])
        
        // Store denoised latents from scheduler to pass into decoder
        var denoisedLatents: [MLShapedArray<Float32>] = latents.map { MLShapedArray(converting: $0) }
        
        if reduceMemory {
            encoder?.unloadResources()
        }
        let timestepStrength: Float? = config.mode == .imageToImage ? config.strength : nil
        
        // Convert cgImage for ControlNet into MLShapedArray
        let controlNetConds = try config.controlNetInputs.map { cgImage in
            let shapedArray = try cgImage.planarRGBShapedArray(minValue: 0.0, maxValue: 1.0)
            return MLShapedArray(
                concatenating: [shapedArray, shapedArray],
                alongAxis: 0
            )
        }
        
        // De-noising loop
        let timeSteps: [Int] = scheduler[0].calculateTimesteps(strength: timestepStrength)
        for (step,t) in timeSteps.enumerated() {
            
            // Expand the latents for classifier-free guidance
            // and input to the Unet noise prediction model
            let latentUnetInput = latents.map {
                MLShapedArray<Float32>(concatenating: [$0, $0], alongAxis: 0)
            }
            
            // Before Unet, execute controlNet and add the output into Unet inputs
            let additionalResiduals = try controlNet?.execute(
                latents: latentUnetInput,
                timeStep: t,
                hiddenStates: hiddenStates,
                images: controlNetConds
            )
            
            // Predict noise residuals from latent samples
            // and current time step conditioned on hidden states
            var noise = try unet.predictNoise(
                latents: latentUnetInput,
                timeStep: t,
                hiddenStates: hiddenStates,
                additionalResiduals: additionalResiduals
            )
            
            noise = performGuidance(noise, config.guidanceScale)
            
            // Have the scheduler compute the previous (t-1) latent
            // sample given the predicted noise and current sample
            for i in 0..<config.imageCount {
                latents[i] = scheduler[i].step(
                    output: noise[i],
                    timeStep: t,
                    sample: latents[i]
                )
                
                denoisedLatents[i] = scheduler[i].modelOutputs.last ?? latents[i]
            }
            
            let currentLatentSamples = config.useDenoisedIntermediates ? denoisedLatents : latents
            
            // Report progress
            let progress = Progress(
                pipeline: self,
                prompt: config.prompt,
                step: step,
                stepCount: timeSteps.count,
                currentLatentSamples: currentLatentSamples,
                configuration: config
            )
            if !progressHandler(progress) {
                // Stop if requested by handler
                return []
            }
        }
        
        if reduceMemory {
            controlNet?.unloadResources()
            unet.unloadResources()
        }
        
        // Decode the latent samples to images
        return try decodeToImages2(denoisedLatents, configuration: config)
    }
    
    public func decodeToImages2(_ latents: [MLShapedArray<Float32>], configuration config: Configuration) throws -> [MLMultiArray]? {
        let images = try decoder.decode2(latents, scaleFactor: config.decoderScaleFactor)
        if reduceMemory {
            decoder.unloadResources()
        }


        return images
    }
    
}

extension StableDiffusionXLPipeline{
    public func decodeToImages2(_ latents: [MLShapedArray<Float32>], configuration config: Configuration) throws -> [MLMultiArray?] {
        let images = try decoder.decode2(latents, scaleFactor: config.decoderScaleFactor)
        if reduceMemory {
            decoder.unloadResources()
        }
        
        return images
    }
    
}

extension StableDecoder{
    public func decode2(
        _ latents: [MLShapedArray<Float32>],
        scaleFactor: Float32
    ) throws -> [MLMultiArray] {

        // Form batch inputs for model
        let inputs: [MLFeatureProvider] = try latents.map { sample in
            // Reference pipeline scales the latent samples before decoding
            let sampleScaled = MLShapedArray<Float32>(
                scalars: sample.scalars.map { $0 / scaleFactor },
                shape: sample.shape)

          
            let dict = [inputName: MLMultiArray(sampleScaled)]
            return try MLDictionaryFeatureProvider(dictionary: dict)
        }
        let batch = MLArrayBatchProvider(array: inputs)

        // Batch predict with model
        let results = try model.perform { model in
            try model.predictions(fromBatch: batch)
        }

        // Transform the outputs to CGImages
//        let images: [CGImage] = try (0..<results.count).map { i in
//            let result = results.features(at: i)
//            let outputName = result.featureNames.first!
//            let output = result.featureValue(for: outputName)!.multiArrayValue!
//            return try CGImage.fromShapedArray(MLShapedArray<Float32>(converting: output))
//        }

        let images: [MLMultiArray] = try (0..<results.count).map { i in
            let result = results.features(at: i)
            let outputName = result.featureNames.first!
            let output = result.featureValue(for: outputName)!.multiArrayValue!
            return output
        }

        
        return images
    }

}

