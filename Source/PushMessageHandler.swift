//
//  PushMessageHandler.swift
//  WireMessageStrategy
//
//  Created by Marco Conti on 15/02/2017.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation
import ZMCDataModel

public protocol PushMessageHandler: class {
    
    /// Create a notification for the message if needed
    ///
    /// - Parameter genericMessage: generic message that was received
    func process(_ genericMessage: ZMGenericMessage)
    
    
    /// Creates a notification for the message if needed
    ///
    /// - Parameter message: message that was received
    func process(_ message: ZMMessage)
    
    
    /// Shows a notification for a failure to send
    ///
    /// - Parameter message: message that failed to send
    func didFailToSend(_ message: ZMMessage)
}
