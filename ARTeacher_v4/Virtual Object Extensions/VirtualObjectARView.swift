//
//  VirtualObjectARView.swift
//  ARTeacher_v3
//
//  Created by Marian Stanciulica on 28/02/2018.
//  Copyright © 2018 Marian Stanciulica. All rights reserved.
//

import Foundation
import ARKit

extension ARSCNView {
    
    // MARK: - Position Testing
    
    /// Hit tests against the sceneView to find an object at the provided point.
    func virtualObject(at point: CGPoint) -> VirtualObject? {
        let hitTestOptions: [SCNHitTestOption: Any] = [.boundingBoxOnly: true]
        let hitTestResults = hitTest(point, options: hitTestOptions)
        
        return hitTestResults.lazy.compactMap({ (result) in
            return VirtualObject.existingObjectContainingNode(result.node)
        }).first
    }
    
    func smartHitTest(_ point: CGPoint, infinitePlane: Bool = false, objectPosition: float3? = nil, allowedAlignments: [ARPlaneAnchor.Alignment] = [.horizontal, .vertical]) -> ARHitTestResult? {
        
        // Perform the hit test.
        let results = self.hitTest(point, types: [.existingPlaneUsingGeometry, .estimatedVerticalPlane, .estimatedHorizontalPlane])
        
        // 1. Check for a result on an existing plane using geometry.
        if let existingPlaneUsingGeometryResult = results.first(where: { $0.type == .existingPlaneUsingGeometry }),
            let planeAnchor = existingPlaneUsingGeometryResult.anchor as?ARPlaneAnchor,
            allowedAlignments.contains(planeAnchor.alignment) {
            return existingPlaneUsingGeometryResult
        }

        
        if infinitePlane {
            // 2. Check for a result on an existing plane, assuming its dimensions are infinite.
            // Loop through all hits against infinite existing planes and either  return the
            // nearest one (vertical planes) or return the nearest one which is within 5 cm
            // of the objects's position.
            let infinitePlaneResults = hitTest(point, types: .existingPlane)
            
            for infinitePlaneResult in infinitePlaneResults {
                if let planeAnchor = infinitePlaneResult.anchor as? ARPlaneAnchor,
                    allowedAlignments.contains(planeAnchor.alignment) {
                    
                    if planeAnchor.alignment == .vertical {
                        // Return the first vertical plane hit test result.
                        return infinitePlaneResult
                    } else {
                        // For horizontal plane we only want to return a hit test result
                        // if it is close to the current object's position.
                        if let objectY = objectPosition?.y {
                            let planeY = infinitePlaneResult.worldTransform.translation.y
                            
                            if objectY > planeY - 0.05 && objectY < planeY + 0.05 {
                                return infinitePlaneResult
                            }
                        } else {
                            return infinitePlaneResult
                        }
                    }
                }
            }
        }
        
        // 3. As a final fallback, check for a result on estimated planes.
        let vResult = results.first(where: { $0.type == .estimatedVerticalPlane })
        let hResult = results.first(where: { $0.type == .estimatedHorizontalPlane })
        
        switch (allowedAlignments.contains(.horizontal), allowedAlignments.contains(.vertical)) {
        case (true, false):
            return hResult
        case (false, true):
            // Allow fallback to horizontal because we assume that objects meant for vertical placement
            // (like a picture) cam always be placed on a horizontal surface, too.
            return vResult ?? hResult
        case (true, true):
            if hResult != nil && vResult != nil {
                return hResult!.distance < vResult!.distance ? hResult! : vResult!
            } else {
                return hResult ?? vResult
            }
        default:
            return nil
        }
        
    }
    
    // MARK: - Object Anchors
    func addOrUpdateAnchor(for object: VirtualObject) {
        
        // If the anchor is not nil, remove it from the session
        if let anchor = object.anchor {
            session.remove(anchor: anchor)
        }
        
        // Create a new anchor with the object's current transoform and add it to the session
        let newAnchor = ARAnchor(transform: object.simdWorldTransform)
        object.anchor = newAnchor
        session.add(anchor: newAnchor)
    }
    
}
