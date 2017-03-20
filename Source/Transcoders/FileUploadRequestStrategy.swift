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

import ZMTransport
import ZMCDataModel
import WireRequestStrategy

private let reponseHeaderAssetIdKey = "Location"


@objc public final class FileUploadRequestStrategy : ZMAbstractRequestStrategy, ZMUpstreamTranscoder, ZMContextChangeTrackerSource {
    
    /// Upstream sync
    fileprivate var fullFileUpstreamSync : ZMUpstreamModifiedObjectSync!
    
    /// Preprocessor
    fileprivate var thumbnailPreprocessorTracker : ZMImagePreprocessingTracker
    fileprivate var filePreprocessor : FilePreprocessor
    
    fileprivate var requestFactory : ClientMessageRequestFactory

    fileprivate var assetAnalytics: AssetAnalytics
    
    override public var configuration: ZMStrategyConfigurationOption { return [.allowsRequestsDuringEventProcessing]}

    public override init(managedObjectContext: NSManagedObjectContext, appStateDelegate: ZMAppStateDelegate) {
        
        let thumbnailProcessingPredicate = NSPredicate { (obj, _) -> Bool in
            guard let message = obj as? ZMAssetClientMessage,
                let fileMessageData = message.fileMessageData,
                let assetData = message.genericAssetMessage?.assetData
            else { return false }
            return !assetData.hasPreview() && fileMessageData.previewData != nil
        }
        let thumbnailFetchPredicate = NSPredicate(format: "delivered == NO && version < 3")
        
        self.thumbnailPreprocessorTracker = ZMImagePreprocessingTracker(
            managedObjectContext: managedObjectContext,
            imageProcessingQueue: OperationQueue(),
            fetch: thumbnailFetchPredicate,
            needsProcessingPredicate: thumbnailProcessingPredicate,
            entityClass: ZMAssetClientMessage.self
        )

        let filter = NSPredicate(format: "version < 3")
        self.filePreprocessor = FilePreprocessor(managedObjectContext: managedObjectContext, filter: filter)
        self.requestFactory = ClientMessageRequestFactory()
        self.assetAnalytics = AssetAnalytics(managedObjectContext: managedObjectContext)
        super.init(managedObjectContext: managedObjectContext, appStateDelegate: appStateDelegate)

        
        self.fullFileUpstreamSync = ZMUpstreamModifiedObjectSync(
            transcoder: self,
            entityName: ZMAssetClientMessage.entityName(),
            update: ZMAssetClientMessage.predicateForFileToUpload,
            filter: ZMAssetClientMessage.filterForFileToUpload,
            keysToSync: [ZMAssetClientMessageUploadedStateKey],
            managedObjectContext: managedObjectContext
        )
    }
    
    public var contextChangeTrackers : [ZMContextChangeTracker] {
        return [self.fullFileUpstreamSync, self.filePreprocessor, self.thumbnailPreprocessorTracker, self]
    }
    
    public func shouldProcessUpdatesBeforeInserts() -> Bool {
        return false
    }
    
    public func dependentObjectNeedingUpdate(beforeProcessingObject dependant: ZMManagedObject) -> Any? {
        guard let message = dependant as? ZMAssetClientMessage else { return nil }
        let dependency = message.dependentObjectNeedingUpdateBeforeProcessing
        return dependency
    }
    
    public func request(forUpdating managedObject: ZMManagedObject, forKeys keys: Set<String>) -> ZMUpstreamRequest? {
        guard let message = managedObject as? ZMAssetClientMessage else { return nil }
        guard keys.contains(ZMAssetClientMessageUploadedStateKey) else { return nil }
        
        if message.uploadState == .uploadingFailed {
            cancelOutstandingUploadRequests(forMessage: message)
            return ZMUpstreamRequest(
                keys: Set(arrayLiteral: ZMAssetClientMessageUploadedStateKey),
                transportRequest: requestToUploadNotUploaded(message)
            )
        }
        if message.uploadState == .uploadingThumbnail {
            return ZMUpstreamRequest(
                keys: Set(arrayLiteral: ZMAssetClientMessageUploadedStateKey),
                transportRequest: self.requestToUploadThumbnail(message)
            )
        }
        if message.uploadState == .uploadingFullAsset {
            return ZMUpstreamRequest(
                keys: Set(arrayLiteral: ZMAssetClientMessageUploadedStateKey),
                transportRequest: self.requestToUploadFull(message)
            )
        }
        if message.uploadState == .uploadingPlaceholder {
            return ZMUpstreamRequest(keys: Set(arrayLiteral: ZMAssetClientMessageUploadedStateKey),
                transportRequest: self.requestToUploadPlaceholder(message)
            )
        }
        return nil
    }
    
    public func request(forInserting managedObject: ZMManagedObject,
        forKeys keys: Set<String>?) -> ZMUpstreamRequest?
    {
        return nil
    }
    
    public func updateInsertedObject(_ managedObject: ZMManagedObject,request upstreamRequest: ZMUpstreamRequest,response: ZMTransportResponse) {
        guard let message = managedObject as? ZMAssetClientMessage, let payload = response.payload?.asDictionary() else { return }
        message.update(withPostPayload: payload, updatedKeys: Set())
        if let delegate = appStateDelegate?.clientRegistrationDelegate {
            _ = message.parseUploadResponse(response, clientRegistrationDelegate: delegate)
        }
    }
    
    public func updateUpdatedObject(_ managedObject: ZMManagedObject, requestUserInfo: [AnyHashable : Any]? = nil, response: ZMTransportResponse, keysToParse: Set<String>) -> Bool {
        guard let message = managedObject as? ZMAssetClientMessage else { return false	 }
        if let payload = response.payload?.asDictionary() {
            message.update(withPostPayload: payload, updatedKeys: keysToParse)
        }
        if let delegate = appStateDelegate?.clientRegistrationDelegate {
            _ = message.parseUploadResponse(response, clientRegistrationDelegate: delegate)
        }
        guard keysToParse.contains(ZMAssetClientMessageUploadedStateKey) else { return false }
        
        switch message.uploadState {
        case .uploadingPlaceholder:
            if message.fileMessageData?.previewData != nil {
                message.uploadState =  .uploadingThumbnail
            } else {
                message.uploadState =  .uploadingFullAsset
            }
            return true
        case .uploadingThumbnail:
            message.uploadState = .uploadingFullAsset
            return true
        case .uploadingFullAsset:
            message.transferState = .downloaded
            message.uploadState = .done
            message.delivered = true
            let assetIDTransportString = response.headers?[reponseHeaderAssetIdKey] as? String
            if let assetID = assetIDTransportString.flatMap({ UUID(uuidString: $0) }) {
                message.assetId = assetID
            }
            self.deleteRequestData(forMessage: message, includingEncryptedAssetData: true)
            assetAnalytics.trackUploadFinished(for: message, with: response)
            
        case .uploadingFailed, .done: break
        }
        
        return false
    }
    
    public func objectToRefetchForFailedUpdate(of managedObject: ZMManagedObject) -> ZMManagedObject? {
        return nil
    }
    
    public func shouldRetryToSyncAfterFailed(toUpdate managedObject: ZMManagedObject,
        request upstreamRequest: ZMUpstreamRequest,
        response: ZMTransportResponse,
        keysToParse keys: Set<String>)-> Bool {
        guard let message = managedObject as? ZMAssetClientMessage else { return false }
        var failedBecauseOfMissingClients = false
        if let delegate = appStateDelegate?.clientRegistrationDelegate {
            failedBecauseOfMissingClients = message.parseUploadResponse(response, clientRegistrationDelegate: delegate)
        }
        if !failedBecauseOfMissingClients {
            let shouldUploadFailed = [ZMAssetUploadState.uploadingFullAsset, .uploadingThumbnail].contains(message.uploadState)
            failMessageUpload(message, keys: keys, request: upstreamRequest.transportRequest)
            return shouldUploadFailed
        }
        
        return failedBecauseOfMissingClients
    }
    
    
    /// marks the upload as failed
    fileprivate func failMessageUpload(_ message: ZMAssetClientMessage, keys: Set<String>, request: ZMTransportRequest?) {
        
        if message.transferState != .cancelledUpload {
            message.transferState = .failedUpload
            message.expire()
        }
        
        if keys.contains(ZMAssetClientMessageUploadedStateKey) {
            
            switch message.uploadState {
            case .uploadingPlaceholder:
                deleteRequestData(forMessage: message, includingEncryptedAssetData: true)
                
            case .uploadingFullAsset, .uploadingThumbnail:
                message.didFailToUploadFileData()
                deleteRequestData(forMessage: message, includingEncryptedAssetData: false)
                
            case .uploadingFailed: return
            case .done: break
            }
            
            message.uploadState = .uploadingFailed
        }
        
        
        // Tracking
        assetAnalytics.trackUploadFailed(for: message, with: request)
    }
    
    public override func nextRequestIfAllowed() -> ZMTransportRequest? {
        return self.fullFileUpstreamSync.nextRequest()
    }
    
    /// Returns a request to upload original
    fileprivate func requestToUploadPlaceholder(_ message: ZMAssetClientMessage) -> ZMTransportRequest? {
        guard let conversationId = message.conversation?.remoteIdentifier else { return nil }
        let request = requestFactory.upstreamRequestForEncryptedFileMessage(.placeholder, message: message, forConversationWithId: conversationId)
        
        request?.add(ZMTaskCreatedHandler(on: managedObjectContext) { taskIdentifier in
            message.associatedTaskIdentifier = taskIdentifier
        })
        
        request?.add(ZMCompletionHandler(on: managedObjectContext) { [weak request] response in
            message.associatedTaskIdentifier = nil
            
            let keys = Set(arrayLiteral: ZMAssetClientMessageUploadedStateKey)
            
            if response.result == .expired || response.result == .temporaryError || response.result == .tryAgainLater {
                self.failMessageUpload(message, keys: keys, request: request)
                // When we fail to upload the placeholder we do not want to send a notUploaded (UploadingFailed) message
                message.resetLocallyModifiedKeys(keys)
            }
        })
        return request
    }
    
    /// Returns a request to upload the thumbnail
    fileprivate func requestToUploadThumbnail(_ message: ZMAssetClientMessage) -> ZMTransportRequest? {
        guard let conversationId = message.conversation?.remoteIdentifier else { return nil }
        let request = requestFactory.upstreamRequestForEncryptedFileMessage(.thumbnail, message: message, forConversationWithId: conversationId)
        request?.add(ZMTaskCreatedHandler(on: managedObjectContext) { taskIdentifier in
            message.associatedTaskIdentifier = taskIdentifier
        })
        
        request?.add(ZMCompletionHandler(on: managedObjectContext) { [weak request] response in
            message.associatedTaskIdentifier = nil
            
            if response.result == .expired || response.result == .temporaryError || response.result == .tryAgainLater {
                self.failMessageUpload(message, keys: Set(arrayLiteral: ZMAssetClientMessageUploadedStateKey), request: request)
            }
        })
        
        return request
    }
    
    /// Returns a request to upload full file
    fileprivate func requestToUploadFull(_ message: ZMAssetClientMessage) -> ZMTransportRequest? {
        guard let conversationId = message.conversation?.remoteIdentifier else { return nil }
        let request = requestFactory.upstreamRequestForEncryptedFileMessage(.fullAsset, message: message, forConversationWithId: conversationId)
        
        request?.add(ZMTaskCreatedHandler(on: managedObjectContext) { taskIdentifier in
          message.associatedTaskIdentifier = taskIdentifier
        })
        
        request?.add(ZMCompletionHandler(on: managedObjectContext) { [weak request] response in
            message.associatedTaskIdentifier = nil
            
            if response.result == .expired || response.result == .temporaryError || response.result == .tryAgainLater {
                self.failMessageUpload(message, keys: Set(arrayLiteral: ZMAssetClientMessageUploadedStateKey), request: request)
            }
        })
        request?.add(ZMTaskProgressHandler(on: self.managedObjectContext) { progress in
            message.progress = progress
            self.managedObjectContext.enqueueDelayedSave()
        })
        return request
    }
    
    /// Returns a request to upload full file
    fileprivate func requestToUploadNotUploaded(_ message: ZMAssetClientMessage) -> ZMTransportRequest? {
        guard let conversationId = message.conversation?.remoteIdentifier else { return nil }
        let request = requestFactory.upstreamRequestForEncryptedFileMessage(.placeholder, message: message, forConversationWithId: conversationId)
        return request
    }
    
    fileprivate func deleteRequestData(forMessage message: ZMAssetClientMessage, includingEncryptedAssetData: Bool) {
        // delete request data
        message.managedObjectContext?.zm_fileAssetCache.deleteRequestData(message.nonce)
        
        // delete asset data
        if includingEncryptedAssetData {
            message.managedObjectContext?.zm_fileAssetCache.deleteAssetData(message.nonce, fileName: message.filename!, encrypted: true)
        }
    }
    
    fileprivate func cancelOutstandingUploadRequests(forMessage message: ZMAssetClientMessage) {
        guard let identifier = message.associatedTaskIdentifier else { return }
        appStateDelegate?.taskCancellationDelegate.cancelTask(with: identifier)
    }
}

extension FileUploadRequestStrategy: ZMContextChangeTracker {
    
    // we need to cancel the requests manually as the upstream modified object sync
    // will not pick up a change to keys which are already being synchronized (uploadState)
    // WHEN the user cancels a file upload
    public func objectsDidChange(_ object: Set<NSManagedObject>) {
        let assetClientMessages = object.flatMap { object -> ZMAssetClientMessage? in
            guard let message = object as? ZMAssetClientMessage ,
                nil != message.fileMessageData && message.transferState == .cancelledUpload
                else { return nil }
            return message
        }
        
        assetClientMessages.forEach(cancelOutstandingUploadRequests)
    }
    
    public func fetchRequestForTrackedObjects() -> NSFetchRequest<NSFetchRequestResult>? {
        return nil
    }
    
    public func addTrackedObjects(_ objects: Set<NSManagedObject>) {
        // no op
    }
}

extension ZMAssetClientMessage {
    
    static var predicateForFileToUpload : NSPredicate {
        
        let notUploadedPredicate = NSPredicate(format: "%K == %d || %K == %d",
            ZMAssetClientMessageTransferStateKey,
            ZMFileTransferState.failedUpload.rawValue,
            ZMAssetClientMessageTransferStateKey,
            ZMFileTransferState.cancelledUpload.rawValue
        )
        
        let needsUploadPredicate = NSPredicate(format: "%K != %d && %K == %d",
            ZMAssetClientMessageUploadedStateKey, ZMAssetUploadState.done.rawValue,
            ZMAssetClientMessageTransferStateKey, ZMFileTransferState.uploading.rawValue
        )

        let versionPredicate = NSPredicate(format: "version < 3")
        let notUploadedOrNeedsUploadPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [needsUploadPredicate, notUploadedPredicate])
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [versionPredicate, notUploadedOrNeedsUploadPredicate])
    }
    
    static var filterForFileToUpload : NSPredicate {
        return NSPredicate(format: "isReadyToUploadFile == YES")
    }
    
    /// We want to upload messages that represent a file where the transfer state is
    /// one of @c Uploading, @c FailedUpload or @c CancelledUpload and only if we are not done uploading.
    /// We also want to wait for the preprocessing of the file data (encryption) to finish (thus the check for an existing otrKey).
    /// If this message has a thumbnail, we additionally want to wait for the thumbnail preprocessing to finish (check for existing preview image)
    /// We check if this message has a thumbnail by checking @c hasDownloadedImage which will be true if the original or medium image exists on disk.
    var isReadyToUploadFile : Bool {
        return self.fileMessageData != nil
            && [.uploading, .failedUpload, .cancelledUpload].contains(transferState)
            && self.uploadState != .done
            && (self.genericAssetMessage?.assetData?.uploaded.otrKey.count ?? 0) > 0
            && (!self.hasDownloadedImage || (self.genericAssetMessage?.assetData?.preview.image.width ?? 0) > 0)
    }
}
