//
//  CustomGeometry.swift
//  RealityMascot
//
//  Created by Iain Ashmore on 23/08/2024.
//

import RealityKit
import RealityMascotKit
import Foundation
import UIKit
import CoreML

enum CellPosition{
    case above
    case below
    case left
    case right
}

class MascotEntity: Entity{
    
    var y : Float = 0
    var lowLevelMesh : LowLevelMesh?
    var points = [MyPoint]()

    let semaphore = DispatchSemaphore(value: 1)
    let queue = DispatchQueue(label: "com.3d.queue", attributes: .concurrent)

    
    var maxVertexCount : Int{
        return (kImageLength * kImageLength * 6 * 6)
    }
    
    var maxPointCount : Int{
        return (kImageLength * kImageLength)
    }
    
    required init() {
        
        super.init()
            
        points = Array.init(repeating: MyPoint(), count: kImageLength * kImageLength)
        
        updatePoints()
        let vertexData = makeVertexData(points: points)
        makeGeometryModel(vertexData: vertexData)

       // makeNewGeometry()
        
    }
    
    func makeGeometryModel(vertexData: VertexData){
        
        semaphore.wait()
    
        //if hasMadeGeometry { return }
        print("make new geometry")
        do{
           // self.lowLevelMesh = try triangleMesh()
    
          //  let cube = MeshResource.generateBox(size: 1.0)
           
            self.lowLevelMesh = try makeMesh(vertexData)
    
            let resource = try MeshResource(from: self.lowLevelMesh!)
            
            let modelComponent = ModelComponent(mesh: resource, materials: [UnlitMaterial()])
        
            self.components.set(modelComponent)
             
            Task{
                await addMaterial()
            }
               
        }catch{
            print("no mesh")
        }
       // hasMadeGeometry = true
        
 
        semaphore.signal()
        
    }
    
    func updateGeometryModel(vertexData: VertexData){
        semaphore.wait()
        updateMesh(vertexData)
        semaphore.signal()
    }
    
    func addMaterial() async{
        
        do{
            let material = try await ShaderGraphMaterial(named: "/Root/material",
                                                         from: "Material/MaterialScene",
                                                         in: realityMascotKitBundle)
            
            self.components[ModelComponent.self]?.materials = [material]
        }catch{
            print("material error")
        }
    }
    var hasUpdates = false
    
    
    func updateWithArray(_ result:[MLMultiArray], _ final:Bool){
              
        if let r = result.first{
            mapImage(r)
            assignPointSides()
            
            let vertexData = makeVertexData(points: self.points)
            
            if !final{
                self.updateGeometryModel(vertexData: vertexData)
            }else{
                //self.makeGeometryModel(vertexData: vertexData)
            }
        }
   
    }
    
    
    func mapImage(_ inputArray:MLMultiArray){
        
       for i in 0..<kImageLength * kImageLength{
            
           
           let coord = getCoord(i)
           let x = coord.x
           let y = kImageLength - coord.y - 1
           let rIndex = (0 * (kImageLength*kImageLength)) + (y * kImageLength) + x
           let gIndex = (1 * (kImageLength*kImageLength)) + (y * kImageLength) + x
           let bIndex = (2 * (kImageLength*kImageLength)) + (y * kImageLength) + x
           
           var r = inputArray[rIndex].floatValue
           var g = inputArray[gIndex].floatValue
           var b = inputArray[bIndex].floatValue
          
           r += 0.485 * 0.226
           g += 0.456 * 0.226
           b += 0.406 * 0.226
           
           r += 1.0 * 0.5
           g += 1.0 * 0.5
           b += 1.0 * 0.5
//           scale = 1.0 / (255.0 * 0.226)
//           red_bias = -0.485 / 0.226
//           green_bias = -0.456 / 0.226
//           blue_bias = -0.406 / 0.226
           
           self.points[i].isOccupied = true
           self.points[i].color = simd_float3(r, g, b)
            
        }
      
    }
    
    
    func updateWithImage(_ image:CGImage, _ final:Bool){
        print("updateWithImage",image.width,image.height)
        
        DispatchQueue.main.async {
            
        guard let data = image.dataProvider?.data else {return}
       
        let firstColor = image.getPixelColor(0, 0,data)
        
        for i in 0..<kImageLength * kImageLength{
        
            let coord = self.getCoord(i)
            
            let color = image.getPixelColor(coord.x, kImageLength - coord.y,data)
            self.points[i].isOccupied = true
            
            if final{
                if color.x.compare(with: firstColor.x, precision: kPrecision){
                    if color.y.compare(with: firstColor.y, precision: kPrecision){
                        if color.z.compare(with: firstColor.z, precision: kPrecision){
                            self.points[i].isOccupied = false
                        }
                    }
                }
            }
            
            self.points[i].color = color
            
        }
            self.updatePoints()
          
    
            
            
            
            let vertexData = makeVertexData(points: self.points)
            
            if !final{
                self.updateGeometryModel(vertexData: vertexData)
            }else{
                self.makeGeometryModel(vertexData: vertexData)
            }
            
        }
       
    }
    
  
    func updateWithSparkle(){
        
        return
        
        updatePoints()
        
        sparklePoints()
        
        DispatchQueue.main.async {
            
            let vertexData = makeVertexData(points: self.points)
 
            self.updateGeometryModel(vertexData: vertexData)
        }
    }
    
    var hasMadeGeometry = false
    
    func highlightPoints(){
        
        for i in 0..<points.count{
            let coord = getCoord(i)
        
              
            if coord.x == 0 || coord.y == 0 || coord.x == kImageLength - 1 || coord.y == kImageLength - 1{
                points[i].color = [1,1,0]
                points[i].isOccupied = true
            }
        }
        
    }
    
    func sparklePoints(){
        for _ in 0..<5{
            let x = Int.random(in: 1..<kImageLength-1)
            let y = Int.random(in: 1..<kImageLength-1)
            let i = getIndex(x, y)
            points[i].color = SIMD3(Float.random(in: 0...1), Float.random(in: 0...1),Float.random(in: 0...1))
            points[i].isOccupied = true
        }
    }
    
    func clearPointSides(){
        for i in 0..<maxPointCount{
            points[i].sides.removeAll()
        }
    }
    
    func assignPointSides(){
        
        clearPointSides()
        
        for i in 0..<maxPointCount{
            
            let coord = getCoord(i)
            
            if points[i].isOccupied{
                
                if let index = getNeighbourIndex(i, .above){
                    if !points[index].isOccupied{
                        points[i].sides.append(.top)
                    }
                }else{
                    points[i].sides.append(.top)
                }
                
                if let index = getNeighbourIndex(i, .left){
                    if !points[index].isOccupied{
                        points[i].sides.append(.left)
                    }
                }else{
                    points[i].sides.append(.left)
                }
                
                if let index = getNeighbourIndex(i, .right){
                    if !points[index].isOccupied{
                        points[i].sides.append(.right)
                    }
                }else{
                    points[i].sides.append(.right)
                }
                
                if let index = getNeighbourIndex(i, .below){
                    if !points[index].isOccupied{
                        points[i].sides.append(.bottom)
                    }
                }else{
                    points[i].sides.append(.bottom)
                }
                
                if points[i].isOccupied{
                    points[i].sides.append(.front)
                    points[i].sides.append(.back)
                }
            }
            
            let scale = Float(1.0) / Float(kImageLength)
            points[i].scale = scale// * 0.5
            let halfLength : Float = Float(kImageLength) / Float(2.0)
            
            let pos = SIMD3<Float>(Float(coord.x) - halfLength,(Float(coord.y) - halfLength),0) * scale
            points[i].position = pos
        }
    }
    

    


    
    func getCoord(_ i:Int)->(x:Int,y:Int){
        let x = i % kImageLength
        let y = i / kImageLength
        return (x,y)
    }
    

    
    func randomUpdates(){
        
        let randomIndex = Int.random(in: 0..<kImageLength * kImageLength)
        let randomBoolean = Bool.random()
        let randomColor = SIMD3<Float>.random(in: 0..<1)
        
        points[randomIndex].isOccupied = randomBoolean
        points[randomIndex].color = randomColor
    }
    
    func getNeighbourIndex(_ i:Int,_ cellPosition:CellPosition)->Int?{
       
    
        switch cellPosition {
        case .above:
            let coord = getCoord(i)
            if coord.y == kImageLength - 1{
                return nil
            }else{
                return getIndex(coord.x, coord.y + 1)
            }
        case .below:
            let coord = getCoord(i)
            if coord.y == 0{
                return nil
            }else{
                return getIndex(coord.x, coord.y - 1)
            }
        case .left:
            let coord = getCoord(i)
            if coord.x == 0{
                return nil
            }else{
                return getIndex(coord.x - 1, coord.y)
            }
        case .right:
            let coord = getCoord(i)
            if coord.x == kImageLength - 1{
                return nil
            }else{
                return getIndex(coord.x + 1, coord.y)
            }
            
        }
   
    }

    
    
    func updatePoints(){
        highlightPoints()
        assignPointSides()
    }
    
  
 
  
    func makeMesh(_ vertexData:VertexData) throws -> LowLevelMesh {
        
        var desc = MyVertex.descriptor
        desc.vertexCapacity = maxVertexCount
        desc.indexCapacity = maxVertexCount
       
        let mesh = try LowLevelMesh(descriptor: desc)
        
        
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            let vertices = rawBytes.bindMemory(to: MyVertex.self)
            print("max vertex Count",maxVertexCount)
            print("actual vertices Count",vertices.count)
            print("vertexData positions Count",vertexData.positions.count)
            print("vertexData indices Count",vertexData.indices.count)
            for i in 0..<vertexData.positions.count{
                let p = vertexData.positions[i]
                let n = vertexData.normals[i]
                let c = vertexData.colors[i]
                vertices[i] = MyVertex(position: p,normal: n,color: c)
        
            }
                
        }
            
        mesh.withUnsafeMutableIndices { rawIndices in
            let indices = rawIndices.bindMemory(to: UInt32.self)
                //indices = results.indices.count
            print("indices count",vertexData.indices.count)
            for i in 0..<vertexData.indices.count{
                indices[i] = vertexData.indices[i]
            }
        }
            
        let meshBounds = BoundingBox(min: [-1, -1, -1], max: [1, 1, 1])
            
        let c = vertexData.indices.count
        mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexCount:Int(c),
                topology: .triangle,
                bounds: meshBounds
            )
        ])
        

        return mesh
    }
    
    func updateMesh(_ vertexData:VertexData){

       
        guard let mesh = self.lowLevelMesh else {return}
        
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            let vertices = rawBytes.bindMemory(to: MyVertex.self)
            print("max vertex Count",maxVertexCount)
            print("actual vertices Count",vertices.count)
            print("vertexData positions Count",vertexData.positions.count)
            print("vertexData indices Count",vertexData.indices.count)
            for i in 0..<vertexData.positions.count{
                let p = vertexData.positions[i]
                let n = vertexData.normals[i]
                let c = vertexData.colors[i]
                vertices[i] = MyVertex(position: p,normal: n,color: c)
        
            }
                
        }
            
        mesh.withUnsafeMutableIndices { rawIndices in
            let indices = rawIndices.bindMemory(to: UInt32.self)
                //indices = results.indices.count
            print("indices count",vertexData.indices.count)
            for i in 0..<vertexData.indices.count{
                indices[i] = vertexData.indices[i]
            }
        }
            
        let meshBounds = BoundingBox(min: [-1, -1, -1], max: [1, 1, 1])
            
        let c = vertexData.indices.count
        mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexCount:Int(c),
                topology: .triangle,
                bounds: meshBounds
            )
        ])
        
    }
    
}

struct MyPoint {
    var position: SIMD3<Float> = .zero
    var color: SIMD3<Float> = .zero
    var sides: [Side] = []
    var scale: Float = 1
    var isOccupied = false
}

enum Side {
    case front
    case back
    case left
    case right
    case top
    case bottom
}


struct MyVertex {
    var position: SIMD3<Float> = .zero
    var normal: SIMD3<Float> = .zero
    var color: SIMD3<Float> = .zero
}

extension MyVertex {
    static var vertexAttributes: [LowLevelMesh.Attribute] = [
        .init(semantic: .position, format: .float3, offset: MemoryLayout<Self>.offset(of: \.position)!),
        .init(semantic: .normal, format: .float3, offset: MemoryLayout<Self>.offset(of: \.normal)!),
        .init(semantic: .color, format: .float3, offset: MemoryLayout<Self>.offset(of: \.color)!)
    ]


    static var vertexLayouts: [LowLevelMesh.Layout] = [
        .init(bufferIndex: 0, bufferStride: MemoryLayout<Self>.stride)
    ]


    static var descriptor: LowLevelMesh.Descriptor {
        var desc = LowLevelMesh.Descriptor()
        desc.vertexAttributes = MyVertex.vertexAttributes
        desc.vertexLayouts = MyVertex.vertexLayouts
        desc.indexType = .uint32
        return desc
    }
}


struct VertexData{
    
    var positions = [SIMD3<Float>]()
    var normals = [SIMD3<Float>]()
    var texcoords = [SIMD2<Float>]()
    var indices = [UInt32]()
    var materialIndices = [UInt32]()
    var colors = [SIMD3<Float>]()
    
}

func makeVertexData(points:[MyPoint]) -> VertexData{

    var vertexData = VertexData()
      
        let a = [SIMD3<Float>(-0.5, 0.0, 0.5),
                 SIMD3<Float>(0.0, 0.0, 0.0),
                 SIMD3<Float>(-0.5, 0.0, -0.5)]
            
   
        let b = [SIMD3<Float>(0.0, 0.0, 0.0),
            SIMD3<Float>(0.0, 0.0, 0.5),
            SIMD3<Float>(0.5, 0.0, 0.0)]
            
        var polygons = [Polygon]()
        
        for i in 0..<points.count {
            
            let point = points[i]
  
            let color = point.color
            
            let vertices = [
                
                //bottom left
                Vector(0.5, 0.0, -0.5),
                Vector(-0.5, 0.0, -0.5),
                Vector(0.5, 0.0, 0.5),
                
             
                Vector(0.5, 0.0, 0.5),
                Vector(-0.5, 0.0, -0.5),
                Vector(-0.5, 0.0, 0.5)
           
            ]
            
          
            var basePolygons = [Polygon]()
            
            var j = 0
            
            
            for i in stride(from: 0, to: vertices.count, by: 3) {
                var polyVertices = [Vertex]()
   
                let c = Color(color[0], color[1], color[2])
                polyVertices.append(Vertex(vertices[i],  .unitX,c))
                polyVertices.append(Vertex(vertices[i+1],  .unitX, c))
                polyVertices.append(Vertex(vertices[i+2],  .unitX,c))
                
                let polygon = Polygon(
                    unchecked: polyVertices,
                    normal: .unitX,
                    isConvex: true,
                    sanitizeNormals: true,
                    material: nil
                )
                basePolygons.append(polygon)
                
            }
            
          
            
            for p in basePolygons{

                var newPolygons = [Polygon]()
                //top
                if point.sides.contains(.top){
                    newPolygons.append(p.translated(by: Vector(0, 0.5, 0)))
                }
               
                //bottom
                if point.sides.contains(.bottom){
                    let t0 = EuclidTransform().rotated(by: Rotation(unchecked: .unitX, angle: Angle(degrees: 180))).translated(by: Vector(0, 0.5, 0))
                    newPolygons.append(p.transformed(by: t0))
                }

                //back
                if point.sides.contains(.back){
                    let t1 = EuclidTransform().rotated(by: Rotation(unchecked: .unitX, angle: Angle(degrees: 90))).translated(by: Vector(0, 0.5, 0.0))
                    newPolygons.append(p.transformed(by: t1))
                }

                //front
                if point.sides.contains(.front){
                    let t2 = EuclidTransform().rotated(by: Rotation(unchecked: .unitX, angle: Angle(degrees: -90))).translated(by: Vector(0, 0.5, 0.0))
                    newPolygons.append(p.transformed(by: t2))
                }
                
                //left
                if point.sides.contains(.left){
                    let t3 = EuclidTransform().rotated(by: Rotation(unchecked: .unitZ, angle: Angle(degrees: -90))).translated(by: Vector(0, 0.5, 0.0))
                    newPolygons.append(p.transformed(by: t3))
                }

                //right
                if point.sides.contains(.right){
                    let t4 = EuclidTransform().rotated(by: Rotation(unchecked: .unitZ, angle: Angle(degrees: 90))).translated(by: Vector(0, 0.5, 0.0))
                    newPolygons.append(p.transformed(by: t4))
                }
                
                for k in 0..<newPolygons.count {
                    let scaled = newPolygons[k].scaled(by: point.scale)
                    let translated = scaled.translated(by: point.position.asVector())
                    newPolygons[k] = translated
                    
                }
                for newPolygon in newPolygons {
                    polygons.append(newPolygon)
                }
            }
            
        }
        
        for polygon in polygons {
            for vertex in polygon.vertices {
                vertexData.positions.append(vertex.position.asSIMD())
                vertexData.normals.append(vertex.normal.asSIMD())
                vertexData.colors.append(vertex.color.asSIMD())
                vertexData.indices.append(UInt32(vertexData.positions.count-1))
            }
        }
        

        return vertexData
    }

extension Color{
    func asSIMD()->SIMD3<Float>{
        return SIMD3(r,g,b)
    }
}

extension simd_float3{
     func asVector()->Vector{
        return Vector(x,y,z)
    }
}
extension Vector{
    func asSIMD()->SIMD3<Float>{
        return SIMD3(x,y,z)
    }
    
}
extension Float {
    func compare(with number: Float, precision: Float = 0.2) -> Bool {
        abs(self.distance(to: number)) < 0.2
    }
}
