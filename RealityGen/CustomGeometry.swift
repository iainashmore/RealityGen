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

enum CellPosition{
    case above
    case below
    case left
    case right
}

class MascotEntity: Entity{
    
    var y : Float = 0
    var lowLevelMesh : LowLevelMesh?
    
    required init() {
        
        super.init()
            
        
        do{
           // self.lowLevelMesh = try triangleMesh()
    
            let cube = MeshResource.generateBox(size: 1.0)
            self.lowLevelMesh = try triangleMesh()
    
            let resource = try MeshResource(from: self.lowLevelMesh!)
            
            let modelComponent = ModelComponent(mesh: resource, materials: [UnlitMaterial()])
        
            self.components.set(modelComponent)
             
            Task{
                await addMaterial()
            }
               
        }catch{
            print("no mesh")
        }
        
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
    
    func updateMesh(){
     
        return
       
    }
    

    let length = 12
    
    func getCoord(_ i:Int)->(x:Int,y:Int){
        let x = i % length
        let y = i / length
        print(i,x,y)
        return (x,y)
    }
    
    func getIndex(_ x:Int,_ y:Int)->Int{
        let i =  x + (length * y)
        print(i)
        return i
    }
    
    func getNeighbourIndex(_ i:Int,_ cellPosition:CellPosition)->Int?{
        
        if i == 5{
            //print(i)
        }
        print(cellPosition)
    
        switch cellPosition {
        case .above:
            let coord = getCoord(i)
            if coord.y == length - 1{
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
            if coord.x == length - 1{
                return nil
            }else{
                return getIndex(coord.x + 1, coord.y)
            }
            
        }
   
    }
    
    func getIndex(_ x:Int,_ y:Int)->Int?{
        return (y * length) + x
    }
    
  
    func triangleMesh() throws -> LowLevelMesh {
        
        var desc = MyVertex.descriptor
        desc.vertexCapacity = 100000
        desc.indexCapacity = 100000
       
        let mesh = try LowLevelMesh(descriptor: desc)
        
        var counts: [UInt8]? = []
        
        var points = Array.init(repeating: MyPoint(), count: length * length)
        
        
        for i in 0..<points.count{
            let coord = getCoord(i)
            print(coord)
            points[i].color = [0,1,0]
            if coord.x == 0 || coord.y == 0 || coord.x == length - 1 || coord.y == length - 1{
                      points[i].color = [0,1,0]
                points[i].isOccupied = true
            }
        }
        
        points[29].isOccupied = true
        points[29].color = [0,1,0]
        for i in 0..<points.count{
            let coord = getCoord(i)
            print(coord)
            points[i].color = [0,1,0]
            if coord.x == 0 || coord.y == 0 || coord.x == length - 1 || coord.y == length - 1{
            
                points[i].color = [0,1,0]

            }
            
            
            if points[i].isOccupied{
                
                print(i, "at",coord)

                
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
          
            
           
            
            //points[i].sides.append(.top)
            
            let scale = Float(1.0) / Float(length)
            points[i].scale = scale// * 0.5
            let halfLength : Float = Float(length) / Float(2.0)
            
            let pos = SIMD3<Float>(Float(coord.x) - halfLength,(Float(coord.y) - halfLength),0) * scale
            points[i].position = pos
            
        }
        
        //points.append(MyPoint(position: .zero,color: [0,1,0]))
   
        let vertexData = buildMesh(points: points, counts: &counts)
        
          
        // let results = skeleton.generateMesh()
        var index : Int = 0
            
        
            //  let c = results.vertices.count
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            let vertices = rawBytes.bindMemory(to: MyVertex.self)
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

func buildMesh(points:[MyPoint],counts: inout [UInt8]?) -> (
        positions: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        texcoords: [SIMD2<Float>]?,
        indices: [UInt32],
        materialIndices: [UInt32],
        colors: [SIMD3<Float>]
    ) {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var colors: [SIMD3<Float>] = []
        var indices = [UInt32]()
        var texcoords = [SIMD2<Float>]()
        var materialIndices = [UInt32]()
        
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
                
//                //bottom right
//                Vector(0.0, 0.0, 0.0),
//                Vector(0.0, 0.0, 0.5),
//                Vector(0.5, 0.0, 0.5),
//                
//                //top left
//                Vector(0.0, 0.0, -0.5),
//                Vector(-0.5, 0.0, -0.5),
//                Vector(-0.0, 0.0, 0.0),
//                
//                //top right
//                Vector(0.0, 0.0, -0.5),
//                Vector(-0.0, 0.0, 0.0),
//                Vector(0.5, 0.0, -0.5),
//                
//                //mid bottom left
//                Vector(0.0, 0.0, 0.0),
//                Vector(-0.5, 0.0, 0.0),
//                Vector(-0.5, 0.0, 0.5),
//                
//                //mid bottom left
//                Vector(0.0, 0.0, 0.0),
//                Vector(0.5, 0.0, 0.5),
//                Vector(0.5, 0.0, 0.0),
//                
//                //mid top left
//                Vector(0.0, 0.0, 0.0),
//                Vector(-0.5, 0.0, -0.5),
//                Vector(-0.5, 0.0, 0.0),
//
//                //mid top right
//                Vector(0.0, 0.0, 0.0),
//                Vector(0.5, 0.0, 0.0),
//                Vector(0.5, 0.0, -0.5)
//             
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
                positions.append(vertex.position.asSIMD())
                normals.append(vertex.normal.asSIMD())
                colors.append(vertex.color.asSIMD())
                indices.append(UInt32(positions.count-1))
            }
        }
        
        return (
            positions: positions,
            normals: normals,
            texcoords: texcoords,
            indices: indices,
            materialIndices: materialIndices,
            colors: colors
        )
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
