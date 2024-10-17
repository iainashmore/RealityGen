//
//  Entities.swift
//  RealityMascot
//
//  Created by Iain Ashmore on 29/08/2024.
//

import RealityKit



class Lighting: Entity, HasPointLight {
    
    required init() {
        super.init()
        
        self.light = PointLightComponent(color:.red,
                                     intensity: 100,
                             attenuationRadius: 2)
    }
}
