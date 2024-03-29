//
//  Device.swift
//  SimpleDALPlugin
//
//  Created by 池上涼平 on 2020/04/25.
//  Copyright © 2020 com.seanchas116. All rights reserved.
//

import Foundation
import IOKit
import VideoConnectivity

class Device: Object {
    var objectClass: CMIOClassID { CMIOClassID(kCMIODeviceClassID) }
    
    var objectID: CMIOObjectID = 0
    var owningObjectID: CMIOObjectID { CMIOObjectID(kCMIOObjectSystemObject) }
    var streamID: CMIOStreamID = 0
    var name: String { sender.name }
    let manufacturer = "Apple"
    var deviceUID: String { "\(name) Device" }
    let modelUID = "SimpleDALPlugin Model"
    var excludeNonDALAccess: Bool = false
    var deviceMaster: Int32 = -1
    let sender: Browser.Sender
    weak var plugin: Plugin?
    
    let stream: RTPStream

    lazy var properties: [Int : Property] = [
        kCMIOObjectPropertyName: Property(name),
        kCMIOObjectPropertyManufacturer: Property(manufacturer),
        kCMIODevicePropertyDeviceUID: Property(deviceUID),
        kCMIODevicePropertyModelUID: Property(modelUID),
        kCMIODevicePropertyTransportType: Property(UInt32(kIOAudioDeviceTransportTypeNetwork)),
        kCMIODevicePropertyDeviceIsAlive: Property(UInt32(1)),
        kCMIODevicePropertyDeviceIsRunning: Property(UInt32(1)),
        kCMIODevicePropertyDeviceIsRunningSomewhere: Property(UInt32(1)),
        kCMIODevicePropertyDeviceCanBeDefaultDevice: Property(UInt32(1)),
        kCMIODevicePropertyCanProcessAVCCommand: Property(UInt32(0)),
        kCMIODevicePropertyCanProcessRS422Command: Property(UInt32(0)),
        kCMIODevicePropertyHogMode: Property(Int32(-1)),
        kCMIODevicePropertyStreams: Property { [unowned self] in self.streamID },
        kCMIODevicePropertyExcludeNonDALAccess: Property(
            getter: { [unowned self] () -> UInt32 in self.excludeNonDALAccess ? 1 : 0 },
            setter: { [unowned self] (value: UInt32) -> Void in self.excludeNonDALAccess = value != 0  }
        ),
        kCMIODevicePropertyDeviceMaster: Property(
            getter: { [unowned self] () -> Int32 in self.deviceMaster },
            setter: { [unowned self] (value: Int32) -> Void in self.deviceMaster = value  }
        ),
    ]
    
    init(sender: Browser.Sender, plugin: Plugin) {
        self.sender = sender
        self.plugin = plugin
        self.stream = RTPStream(sender: sender, plugin: plugin)
    }
}
