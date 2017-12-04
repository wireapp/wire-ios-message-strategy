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

class AvailabilityRequestStrategy : AbstractRequestStrategy {
    
    var modifiedSync : ZMUpstreamModifiedObjectSync!
    
    override init(withManagedObjectContext managedObjectContext: NSManagedObjectContext, applicationStatus: ApplicationStatus) {
        
        super.init(withManagedObjectContext: managedObjectContext, applicationStatus: applicationStatus)
        self.modifiedSync = ZMUpstreamModifiedObjectSync(transcoder: self, entityName: ZMUser.entityName(), keysToSync: [AvailabilityKey], managedObjectContext: managedObjectContext)
    }
    
}

extension AvailabilityRequestStrategy : ZMUpstreamTranscoder {

    func request(forUpdating managedObject: ZMManagedObject, forKeys keys: Set<String>) -> ZMUpstreamRequest? {
        // needs to have a session with all connections
        
        guard let selfUser = managedObject as? ZMUser else { return nil }
        
        let availabilityBuilder = ZMAvailability.builder()
        _ = availabilityBuilder?.setType(.REMOTE)
        let availability = availabilityBuilder?.build()
        
        let messageBuilder = ZMGenericMessage.builder()
        _ = messageBuilder?.setAvailability(availability)
        let message = messageBuilder?.build()
        
        let originalPath = "/broadcast/otr/messages"
        
        guard let dataAndMissingClientStrategy = message?.encryptedMessagePayloadDataForBroadcast(context: managedObjectContext) else {
            return nil
        }
        
        let protobufContentType = "application/x-protobuf"
        let path = originalPath.pathWithMissingClientStrategy(strategy: dataAndMissingClientStrategy.strategy)
        let request = ZMTransportRequest(path: path, method: .methodPOST, binaryData: dataAndMissingClientStrategy.data, type: protobufContentType, contentDisposition: nil)
        
        return ZMUpstreamRequest(keys: keys, transportRequest: request)
    }
    
    func dependentObjectNeedingUpdate(beforeProcessingObject dependant: ZMManagedObject) -> Any? {
        return dependentObjectNeedingUpdateBeforeProcessing
    }
    
    func updateUpdatedObject(_ managedObject: ZMManagedObject, requestUserInfo: [AnyHashable : Any]? = nil, response: ZMTransportResponse, keysToParse: Set<String>) -> Bool {
        guard let clientRegistrationDelegate = applicationStatus?.clientRegistrationDelegate else { return false }
        
        _ = parseUploadResponse(response, clientRegistrationDelegate: clientRegistrationDelegate)
        
        return false
    }
    
    func shouldRetryToSyncAfterFailed(toUpdate managedObject: ZMManagedObject, request upstreamRequest: ZMUpstreamRequest, response: ZMTransportResponse, keysToParse keys: Set<String>) -> Bool {
        guard let clientRegistrationDelegate = applicationStatus?.clientRegistrationDelegate else { return false }
        
        return parseUploadResponse(response, clientRegistrationDelegate: clientRegistrationDelegate)
    }
    
    func shouldProcessUpdatesBeforeInserts() -> Bool {
        return false
    }
    
    func request(forInserting managedObject: ZMManagedObject, forKeys keys: Set<String>?) -> ZMUpstreamRequest? {
        return nil // we will never insert objects
    }
    
    func updateInsertedObject(_ managedObject: ZMManagedObject, request upstreamRequest: ZMUpstreamRequest, response: ZMTransportResponse) {
        // we will never insert objects
    }
    
    func objectToRefetchForFailedUpdate(of managedObject: ZMManagedObject) -> ZMManagedObject? {
        return nil
    }
    
}

extension AvailabilityRequestStrategy : OTREntity {
    
    var context: NSManagedObjectContext {
        return managedObjectContext
    }
    
    func missesRecipients(_ recipients: Set<UserClient>!) {
        // TODO check what to do
    }
    
    func detectedRedundantClients() {
        // TODO check what to do
    }
    
    func detectedMissingClient(for user: ZMUser) {
        // TODO check what to do
    }
    
    var dependentObjectNeedingUpdateBeforeProcessing: AnyHashable? {
        return self.dependentObjectNeedingUpdateBeforeProcessingOTREntity(recipients: ZMUser.connectionsAndTeamMembers(in: managedObjectContext))
    }
    
    var isExpired: Bool {
        return false
    }
    
    func expire() {
        // nop
    }
    
    
}
