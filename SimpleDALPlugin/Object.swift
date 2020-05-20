//
//  Object.swift
//  SimpleDALPlugin
//
//  Created by 池上涼平 on 2020/04/25.
//  Copyright © 2020 com.seanchas116. All rights reserved.
//

import Foundation

protocol Object: class {
    var objectID: CMIOObjectID { get }
    var properties: [Int: Property] { get }
}

extension Object {
    private func property(for address: CMIOObjectPropertyAddress) -> Property? {
        properties[Int(address.mSelector)]
    }
    func hasProperty(address: CMIOObjectPropertyAddress) -> Bool {
        property(for: address) != nil
    }

    func isPropertySettable(address: CMIOObjectPropertyAddress) -> Bool {
        property(for: address)?.isSettable ?? false
    }

    func getPropertyDataSize(address: CMIOObjectPropertyAddress) -> UInt32 {
        property(for: address)?.dataSize ?? 0
    }

    func getPropertyData(address: CMIOObjectPropertyAddress, dataSize: inout UInt32, data: UnsafeMutableRawPointer) {
        guard let property = property(for: address) else {
            return
        }
        dataSize = property.dataSize
        property.getData(data: data)
    }

    func setPropertyData(address: CMIOObjectPropertyAddress, data: UnsafeRawPointer) {
        property(for: address)?.setData(data: data)
    }
}

var objects = [CMIOObjectID: Object]()

func addObject(object: Object) {
    objects[object.objectID] = object
}
