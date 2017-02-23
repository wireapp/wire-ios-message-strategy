//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//


import Foundation
import WireRequestStrategy

public class MockAppStateDelegate : NSObject, ZMAppStateDelegate {
    
    public var confirmationDelegate : DeliveryConfirmationDelegate {
        return self.mockConfirmationStatus
    }
    
    public var taskCancellationDelegate : ZMRequestCancellation {
        return self.mockTaskCancellationDelegate
    }
    
    public var clientRegistrationDelegate : ClientRegistrationDelegate {
        return self.mockClientRegistrationStatus
    }
    
    public let mockConfirmationStatus = MockConfirmationStatus()
    public let mockTaskCancellationDelegate = MockTaskCancellationDelegate()
    public var mockClientRegistrationStatus = MockClientRegistrationStatus()
    
    public var mockAppState = ZMAppState.unauthenticated
    
    public var appState: ZMAppState {
        return mockAppState
    }
    
    public var cancelledIdentifiers : [ZMTaskIdentifier] {
        return mockTaskCancellationDelegate.cancelledIdentifiers
    }
    
    public var deletionCalls : Int {
        return mockClientRegistrationStatus.deletionCalls
    }

    public var messagesToConfirm : Set<UUID> {
        return mockConfirmationStatus.messagesToConfirm
    }
    
    public var messagesConfirmed : Set<UUID> {
        return mockConfirmationStatus.messagesConfirmed
    }
    
}


public class MockTaskCancellationDelegate: NSObject, ZMRequestCancellation {
    public var cancelledIdentifiers = [ZMTaskIdentifier]()
    
    public func cancelTask(with identifier: ZMTaskIdentifier) {
        cancelledIdentifiers.append(identifier)
    }
}


public class MockClientRegistrationStatus: NSObject, ClientRegistrationDelegate {
    
    public var deletionCalls : Int = 0
    
    /// Notify that the current client was deleted remotely
    public func didDetectCurrentClientDeletion() {
        deletionCalls = deletionCalls+1
    }
    
    public var clientIsReadyForRequests: Bool {
        return true
    }
}


@objc public class MockConfirmationStatus : NSObject, DeliveryConfirmationDelegate {
    
    public private (set) var messagesToConfirm = Set<UUID>()
    public private (set) var messagesConfirmed = Set<UUID>()

    public static var sendDeliveryReceipts: Bool {
        return true
    }
    
    public var needsToSyncMessages: Bool {
        return true
    }
    
    public func needsToConfirmMessage(_ messageNonce: UUID) {
        messagesToConfirm.insert(messageNonce)
    }
    
    public func didConfirmMessage(_ messageNonce: UUID) {
        messagesConfirmed.insert(messageNonce)
    }
}


