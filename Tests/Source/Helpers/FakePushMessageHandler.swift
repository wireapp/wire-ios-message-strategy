//
//  File.swift
//  WireMessageStrategy
//
//  Created by Marco Conti on 16/02/2017.
//  Copyright © 2017 Wire Swiss GmbH. All rights reserved.
//

import Foundation

class FakePushMessageHandler: PushMessageHandler {
    
    public func didFailToSend(_ message: ZMMessage) {
        failedToSend.append(message)
    }

    public func process(_ message: ZMMessage) {
        processedMessages.append(message)
    }

    public func process(_ genericMessage: ZMGenericMessage) {
        processedGenericMessages.append(genericMessage)
    }

    fileprivate(set) var failedToSend: [ZMMessage] = []
    fileprivate(set) var processedMessages: [ZMMessage] = []
    fileprivate(set) var processedGenericMessages: [ZMGenericMessage] = []
}
