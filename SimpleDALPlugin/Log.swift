//
//  Log.swift
//  SimpleDALPlugin
//
//  Created by 池上涼平 on 2020/04/25.
//  Copyright © 2020 com.seanchas116. All rights reserved.
//

import Foundation
import OSLog

func log(_ message: Any = "", function: String = #function) {
    //NSLog("SimpleDALPlugin: \(function): \(message)")
    os_log("SimpleDALPlugin - %{public}@: %{public}@", function, String(describing: message))
}
