//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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


/// Creates network requests to send client messages,
/// and parses received client messages
public class ClientMessageTranscoder: ZMObjectSyncStrategy {
    
    fileprivate let requestFactory: ClientMessageRequestFactory
    fileprivate weak var clientRegistrationStatus: ClientRegistrationDelegate?
    fileprivate weak var deliveryConfirmation: DeliveryConfirmationDelegate?
    private(set) fileprivate var upstreamObjectSync: ZMUpstreamInsertedObjectSync!
    fileprivate let messageExpirationTimer: MessageExpirationTimer
    fileprivate weak var localNotificationDispatcher: PushMessageHandler!
    
    public init(in moc:NSManagedObjectContext,
         localNotificationDispatcher: PushMessageHandler,
         clientRegistrationStatus: ClientRegistrationDelegate,
         apnsConfirmationStatus: DeliveryConfirmationDelegate)
    {
        self.localNotificationDispatcher = localNotificationDispatcher
        self.requestFactory = ClientMessageRequestFactory()
        self.clientRegistrationStatus = clientRegistrationStatus
        self.deliveryConfirmation = apnsConfirmationStatus
        self.messageExpirationTimer = MessageExpirationTimer(moc: moc, entityName: ZMClientMessage.entityName(), localNotificationDispatcher: localNotificationDispatcher)
        
        super.init(managedObjectContext: moc)
        self.upstreamObjectSync = ZMUpstreamInsertedObjectSync(transcoder: self, entityName: ZMClientMessage.entityName(), managedObjectContext: moc)
        self.deleteOldEphemeralMessages()
    }
    
    public override func tearDown() {
        super.tearDown()
        self.messageExpirationTimer.tearDown()
    }
    
    deinit {
        self.messageExpirationTimer.tearDown()
    }
}

extension ClientMessageTranscoder: ZMContextChangeTrackerSource {
    
    public var contextChangeTrackers: [ZMContextChangeTracker] {
        return [self.upstreamObjectSync, self.messageExpirationTimer]
    }
}

extension ClientMessageTranscoder: ZMRequestGenerator {

    public func nextRequest() -> ZMTransportRequest? {
        guard let clientRegistrationStatus = self.clientRegistrationStatus,
            clientRegistrationStatus.clientIsReadyForRequests
        else {
            return nil
        }
        return self.upstreamObjectSync.nextRequest()
    }
}

extension ClientMessageTranscoder: ZMUpstreamTranscoder {
    
    public func shouldProcessUpdatesBeforeInserts() -> Bool {
        return false
    }
    
    public func request(forUpdating managedObject: ZMManagedObject, forKeys keys: Set<String>) -> ZMUpstreamRequest? {
        return nil
    }
    
    public func request(forInserting managedObject: ZMManagedObject, forKeys keys: Set<String>?) -> ZMUpstreamRequest? {
        guard let message = managedObject as? ZMClientMessage,
            !message.isExpired else { return nil }
        let request = self.requestFactory.upstreamRequestForMessage(message, forConversationWithId: message.conversation!.remoteIdentifier!)!
        if message.genericMessage?.hasConfirmation() == true && self.deliveryConfirmation!.needsToSyncMessages {
            request.forceToVoipSession()
        }
        
        self.messageExpirationTimer.stop(for: message)
        if let expiration = message.expirationDate {
            request.expire(at: expiration)
        }
        return ZMUpstreamRequest(keys: keys, transportRequest: request)
    }
    
    public func requestExpired(for managedObject: ZMManagedObject, forKeys keys: Set<String>) {
        guard let message = managedObject as? ZMOTRMessage else { return }
        message.expire()
        self.localNotificationDispatcher.didFailToSend(message)
    }
    
    public func objectToRefetchForFailedUpdate(of managedObject: ZMManagedObject) -> ZMManagedObject? {
        guard let message = managedObject as? ZMOTRMessage else { return nil }
        return message.conversation
    }
}

extension ClientMessageTranscoder {

    var hasPendingMessages: Bool {
        return self.messageExpirationTimer.hasMessageTimersRunning || self.upstreamObjectSync.hasCurrentlyRunningRequests;
    }
    
    func message(from event: ZMUpdateEvent, prefetchResult: ZMFetchRequestBatchResult?) -> ZMMessage? {
        switch event.type {
        case .conversationClientMessageAdd:
            fallthrough
        case .conversationOtrMessageAdd:
            fallthrough
        case .conversationOtrAssetAdd:
            guard let updateResult = ZMOTRMessage.messageUpdateResult(from: event, in: self.managedObjectContext, prefetchResult: prefetchResult) else {
                 return nil
            }
            if type(of: self.deliveryConfirmation!).sendDeliveryReceipts {
                if updateResult.needsConfirmation {
                    let confirmation = updateResult.message!.confirmReception()!
                    if event.source == .pushNotification {
                        self.deliveryConfirmation?.needsToConfirmMessage(confirmation.nonce)
                    }
                }
            }
            
            if let updateMessage = updateResult.message, event.source == .pushNotification {
                if let genericMessage = ZMGenericMessage(from: event) {
                    self.localNotificationDispatcher.process(genericMessage)
                }
                self.localNotificationDispatcher.process(updateMessage)
                
            }
            
            updateResult.message?.markAsSent()
            return updateResult.message
        default:
            return nil
        }
    }
    
    fileprivate func deleteOldEphemeralMessages() {
        ZMMessage.deleteOldEphemeralMessages(self.managedObjectContext)
        self.managedObjectContext.saveOrRollback()
    }

    public func updateInsertedObject(_ managedObject: ZMManagedObject, request upstreamRequest: ZMUpstreamRequest, response: ZMTransportResponse) {
        
        guard let message = managedObject as? ZMClientMessage,
            !managedObject.isZombieObject,
            let genericMessage = message.genericMessage else {
                return
        }
        
        self.update(message, from: response, keys: upstreamRequest.keys ?? Set())
        _ = message.parseMissingClientsResponse(response, clientDeletionDelegate: self.clientRegistrationStatus!)
        
        if genericMessage.hasReaction() == true {
            message.managedObjectContext?.delete(message)
        }
        if genericMessage.hasConfirmation() == true {
            self.deliveryConfirmation?.didConfirmMessage(message.nonce)
            message.managedObjectContext?.delete(message)
        }
    }
    
    private func update(_ message: ZMClientMessage, from response: ZMTransportResponse, keys: Set<String>) {
        guard !message.isZombieObject else {
            return
        }
        
        self.messageExpirationTimer.stop(for: message)
        message.removeExpirationDate()
        message.markAsSent()
        message.update(withPostPayload: response.payload?.asDictionary() ?? [:], updatedKeys: keys)
        _ = message.parseMissingClientsResponse(response, clientDeletionDelegate: self.clientRegistrationStatus!)

    }

    public func updateUpdatedObject(_ managedObject: ZMManagedObject, requestUserInfo: [AnyHashable : Any]? = nil, response: ZMTransportResponse, keysToParse: Set<String>) -> Bool {
        guard let message = managedObject as? ZMClientMessage,
            !managedObject.isZombieObject else {
                return false
        }
        self.update(message, from: response, keys: keysToParse)
        _ = message.parseMissingClientsResponse(response, clientDeletionDelegate: self.clientRegistrationStatus!)
        return false
    }

    public func shouldRetryToSyncAfterFailed(toUpdate managedObject: ZMManagedObject, request upstreamRequest: ZMUpstreamRequest, response: ZMTransportResponse, keysToParse keys: Set<String>) -> Bool {
        guard let message = managedObject as? ZMOTRMessage,
            !managedObject.isZombieObject else {
                return false
        }
        return message.parseMissingClientsResponse(response, clientDeletionDelegate: self.clientRegistrationStatus!)
    }
    
    public func shouldCreateRequest(toSyncObject managedObject: ZMManagedObject, forKeys keys: Set<String>, withSync sync: Any) -> Bool {
        guard let message = managedObject as? ZMClientMessage,
            !managedObject.isZombieObject,
            let genericMessage = message.genericMessage else {
                return false
        }
        if genericMessage.hasConfirmation() == true {
            let messageNonce = UUID(uuidString: genericMessage.confirmation.messageId)
            let sentMessage = ZMMessage.fetch(withNonce: messageNonce, for: message.conversation!, in: message.managedObjectContext!)
            return (sentMessage?.sender != nil)
                || (message.conversation?.connectedUser != nil)
                || (message.conversation?.otherActiveParticipants.count > 0)
        }
        return true
    }
    
    public func dependentObjectNeedingUpdate(beforeProcessingObject dependant: ZMManagedObject) -> Any? {
        guard let message = dependant as? ZMClientMessage,
            !dependant.isZombieObject else {
                return false
        }
        return message.dependentObjectNeedingUpdateBeforeProcessing
    }
}

// MARK: - Update events
extension ClientMessageTranscoder {
    
    public func processEvents(_ events: [ZMUpdateEvent], liveEvents: Bool, prefetchResult: ZMFetchRequestBatchResult?) {
        let messages = events.flatMap { self.message(from: $0, prefetchResult: prefetchResult) }
        if (liveEvents) {
            messages.forEach { $0.conversation?.resortMessages(withUpdatedMessage: $0) }
        }
    }    
    
    public func messageNoncesToPrefetch(toProcessEvents events: [ZMUpdateEvent]) -> Set<UUID> {
        return Set(events.flatMap {
            switch $0.type {
            case .conversationClientMessageAdd:
                fallthrough
            case .conversationOtrAssetAdd:
                fallthrough
            case .conversationClientMessageAdd:
                return $0.messageNonce()
            default:
                return nil
            }
        })
    }
    
    private func nonces(for updateEvents: [ZMUpdateEvent]) -> [UpdateEventWithNonce] {
        return updateEvents.flatMap {
            switch $0.type {
            case .conversationClientMessageAdd:
                fallthrough
            case .conversationOtrAssetAdd:
                fallthrough
            case .conversationClientMessageAdd:
                if let nonce = $0.messageNonce() {
                    return UpdateEventWithNonce(event: $0, nonce: nonce)
                }
                return nil
            default:
                return nil
            }
        }
    }
}

// MARK: - Helpers
private struct UpdateEventWithNonce {
    let event: ZMUpdateEvent
    let nonce: UUID
}
