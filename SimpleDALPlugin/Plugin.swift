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
    var objectID: CMIOObjectID = 0
    var owningObjectID: CMIOObjectID { CMIOObjectID(kCMIOObjectSystemObject) }
    let name = "RTP Plugin"
    let queue: DispatchQueue = .init(label: "\(Plugin.self)")
    
    lazy var properties: [Int : Property] = [
        kCMIOObjectPropertyName: Property(name),
    ]
    
    
    let autoConnector = AutoConnector()
    private var availableDevices: Set<Browser.Sender> = []
    private var requestedConnectionCount: [Browser.Sender: Int] = [:]
    private var devices: [Browser.Sender: Device] = [:]
    let ref: CMIOHardwarePlugInRef?
    init(ref: CMIOHardwarePlugInRef?) {
        self.ref = ref
        autoConnector.didChangeSender = { [weak self] availableSender, connected in
            guard let self = self else { return }
            self.queue.async { [weak self] in
                guard let self = self else { return }
                log("didChangeSender \(availableSender)")
                let availableDevices = Set(availableSender).union(connected.keys)
                defer { self.availableDevices = availableDevices }
                let diff = self.availableDevices.difference(from: availableDevices)
                for removedSender in diff.removed {
                    self.removeDevice(sender: removedSender)
                }
                for availableDevice in availableDevices {
                    self.addOrUpdateDevice(sender: availableDevice, reciever: connected[availableDevice])
                }
                // TODO: remvoe me
                self.updateAutoConnector()
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
            //requestedConnectionCount[sender, default: 0] -= 1
            self.updateAutoConnector()
        }
    }
    
    private func updateAutoConnector() {
        let senderToAutoConnect = Set(autoConnector.sender)
//        let senderToAutoConnect = Set(requestedConnectionCount.filter({ $0.value >= 0 }).keys)
        log("auto connect to \(senderToAutoConnect)")
        autoConnector.updateAutoConnect(senderToAutoConnect)
    }
    
    private func removeDevice(sender: Browser.Sender) {
        // TODO: remove device
    }
    
    private func addOrUpdateDevice(sender: Browser.Sender, reciever: RTPH264Reciever?) {
        guard let device = { () -> Device? in
            if let device = devices[sender] {
                return device
            }
            guard let newDevice = makeDevice(for: sender) else { return nil }
            devices[sender] = newDevice
            return newDevice
        }() else { return }
        log(device.name)
        log(reciever)
        var myClassDumped = String()
        dump(autoConnector, to: &myClassDumped)
        log("AutoConnector \(myClassDumped)")
        if let reciever = reciever {
            device.stream.start(with: reciever)
        }
    }
    
    private func makeDevice(for sender: Browser.Sender) -> Device? {
        let device = Device(sender: sender, plugin: self)
        
        let deviceError = CMIOObjectCreate(ref, CMIOObjectID(kCMIOObjectSystemObject), CMIOClassID(kCMIODeviceClassID), &device.objectID)
        guard deviceError == noErr else {
            log("device create error: \(deviceError)")
            return nil
        }
        
        
        let streamError = CMIOObjectCreate(ref, device.objectID, CMIOClassID(kCMIOStreamClassID), &device.stream.objectID)
        guard streamError == noErr else {
            log("stream create error: \(streamError)")
            return nil
        }
        
        device.streamID = device.stream.objectID
        device.stream.owningObjectID = device.objectID
        
        addObject(object: device)
        addObject(object: device.stream)
        
        
        
        let devicePublishError = CMIOObjectsPublishedAndDied(ref, CMIOObjectID(kCMIOObjectSystemObject), 1, &device.objectID, 0, nil)
        guard devicePublishError == noErr else {
            log("devicePublishError: \(devicePublishError)")
            return nil
        }
        
        let streamPublishError = CMIOObjectsPublishedAndDied(ref, device.objectID, 1, &device.stream.objectID, 0, nil)
        guard streamPublishError == noErr else {
            log("streamPublishError: \(streamPublishError)")
            return nil
        }
        return device
    }
}
