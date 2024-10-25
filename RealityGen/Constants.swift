//
//  constants.swift
//  RealityGen
//
//  Created by Iain Ashmore on 22/10/2024.
//

let kImageLength : Int = 64
let kStepCount : Int = 24
let kPrecision : Float = 0.2
let kPromptPrefix : String = "a lonely "
let kPromptSuffix : String = ", full body game asset, in pixelsprite style"
let kNegativePrompt : String = "scenery, spritesheet, many, multiple, sheet"

enum GenerationState : String{
    case idle = "Ready"     // idling
    case generating = "Generating..." // generating images
    case saving = "Saving"   // saving images into Photo Library
    case cancelling = "Cancelling"
}
