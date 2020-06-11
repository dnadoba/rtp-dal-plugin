//
//  Plugin.swift
//  SimpleDALPlugin
//
//  Created by 池上涼平 on 2020/04/25.
//  Copyright © 2020 com.seanchas116. All rights reserved.
//

import Foundation
import VideoConnectivity
import RTPAVKit

class Plugin: Object {
    var objectClass: CMIOClassID { CMIOClassID(kCMIOPlugInClassID) }
    var objectID: CMIOObjectID = 0
    var owningObjectID: CMIOObjectID { CMIOObjectID(kCMIOObjectSystemObject) }
    let name = "RTP Plugin"
    let queue: DispatchQueue = .init(label: "\(Plugin.self)")
    
    lazy var properties: [Int : Property] = [
        kCMIOObjectPropertyName: Property(name),
    ]
    
    
    let autoConnector = AutoConnector()
    private var availableDevices: Set<Browser.Sender> = []
    private var requestedConnectionCount: [Browser.Sender: Int] = [:] {
        didSet {
            log(requestedConnectionCount)
        }
    }
    private var devices: [Browser.Sender: Device] = [:]
    let ref: CMIOHardwarePlugInRef?
    init(ref: CMIOHardwarePlugInRef?) {
        self.ref = ref
        autoConnector.didChangeSender = { [weak self] availableSender, connected in
            guard let strongSelf1 = self else { return }
            strongSelf1.queue.async { [weak strongSelf1] in
                guard let strongSelf2 = strongSelf1 else { return }
                log("didChangeSender availableSender: \(availableSender)")
                log("didChangeSender conntected: \(connected.keys)")
                let availableDevices = Set(availableSender).union(connected.keys)
                defer { strongSelf2.availableDevices = availableDevices }
                let diff = availableDevices.difference(from: strongSelf2.availableDevices)
                for removedSender in diff.removed {
                    strongSelf2.removeDevice(sender: removedSender)
                }
                for availableDevice in availableDevices {
                    strongSelf2.addOrUpdateDevice(sender: availableDevice, reciever: connected[availableDevice])
                }
            }
        }
        queue.async {
            self.autoConnector.startBrowsing()
        }
    }
    deinit {
        log("plugin deinit")
    }
    
    public func start() {
        queue.sync {
            //autoConnector.startBrowsing()
        }
    }
    
    public func incrementConnection(to sender: Browser.Sender) {
        queue.sync {
            self.requestedConnectionCount[sender, default: 0] += 1
            self.updateAutoConnector()
        }
    }
    
    public func decrementConnection(to sender: Browser.Sender) {
        queue.sync {
            requestedConnectionCount[sender, default: 0] -= 1
            requestedConnectionCount = requestedConnectionCount.filter({ $0.value > 0 })
            self.updateAutoConnector()
        }
    }
    
    private func updateAutoConnector() {
        //let senderToAutoConnect = Set(autoConnector.sender)
        let senderToAutoConnect = Set(requestedConnectionCount.filter({ $0.value > 0 }).keys)
        log("auto connect to \(senderToAutoConnect)")
        autoConnector.updateAutoConnect(senderToAutoConnect)
    }
    
    private func removeDevice(sender: Browser.Sender) {
        log(sender)
        guard let device = devices[sender] else { return }
        requestedConnectionCount[sender] = nil
        devices[sender] = nil
        try? killObject(device.stream)
        try? killObject(device)
        removeObject(object: device.stream)
        removeObject(object: device)
    }
    
    private func addOrUpdateDevice(sender: Browser.Sender, reciever: RTPH264Reciever?) {
        guard let device = { () -> Device? in
            if let device = devices[sender] {
                return device
            }
            guard let newDevice = try? makeDevice(for: sender) else { return nil }
            devices[sender] = newDevice
            return newDevice
        }() else { return }
        log(device.name)
        log(reciever)
        //var myClassDumped = String()
        //dump(autoConnector, to: &myClassDumped)
        //log("AutoConnector \(myClassDumped)")
        if let reciever = reciever {
            device.stream.start(with: reciever)
        }
    }
    
    private func makeDevice(for sender: Browser.Sender) throws -> Device {
        log(sender)
        let device = Device(sender: sender, plugin: self)
        
        try createObject(device)
        
        device.stream.owningObjectID = device.objectID
        
        try createObject(device.stream)
        
        device.streamID = device.stream.objectID
        
        addObject(object: device)
        addObject(object: device.stream)
        
        try publishObject(device)
        try publishObject(device.stream)
        
        return device
    }
}

enum PluginError: Error {
    case objectCreateError
    case objectPublishError
    case objectKillError
}

extension Plugin {
    fileprivate func createObject(_ object: Object) throws {
        let error = CMIOObjectCreate(ref, object.owningObjectID, object.objectClass, &object.objectID)
        guard error == noErr else {
            log("object \(object) create error: \(error)")
            throw PluginError.objectCreateError
        }
    }
}

extension Plugin {
    fileprivate func publishObject(_ object: Object) throws {
        var objectId = object.objectID
        let error = CMIOObjectsPublishedAndDied(ref, object.owningObjectID, 1, &objectId, 0, nil)
        guard error == noErr else {
            log("object \(object) publish error: \(error)")
            throw PluginError.objectPublishError
        }
    }
    fileprivate func killObject(_ object: Object) throws {
        var objectId = object.objectID
        let error = CMIOObjectsPublishedAndDied(ref, object.owningObjectID,  0, nil, 1, &objectId)
        guard error == noErr else {
            log("object \(object) kill error: \(error)")
            throw PluginError.objectKillError
        }
    }
}
