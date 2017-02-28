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

import XCTest
@testable import WireMessageStrategy
import ZMUtilities
import ZMTesting
import ZMCMockTransport
import ZMCDataModel
import WireRequestStrategy

class MissingClientsRequestStrategyTests: MessagingTestBase {

    var sut: MissingClientsRequestStrategy!
    var clientRegistrationStatus: MockClientRegistrationStatus!
    var confirmationStatus : MockConfirmationStatus!
    
    var validPrekey: String {
        return try! self.selfClient.keysStore.lastPreKey()
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        clientRegistrationStatus = MockClientRegistrationStatus()
        confirmationStatus = MockConfirmationStatus()
        sut = MissingClientsRequestStrategy(clientRegistrationStatus: clientRegistrationStatus, apnsConfirmationStatus: confirmationStatus, managedObjectContext: self.syncMOC)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        clientRegistrationStatus = nil
        confirmationStatus = nil
        sut.tearDown()
        sut = nil
        super.tearDown()
    }
    
    func testThatItCreatesMissingClientsRequest() {
        
        // given
        let missingUser = self.createUser()
        
        let firstMissingClient = self.createClient(user: self.otherUser)
        let secondMissingClient = self.createClient(user: self.otherUser)
        
        // when
        self.selfClient.missesClient(firstMissingClient)
        self.selfClient.missesClient(secondMissingClient)
        
        let request = sut.requestsFactory.fetchMissingClientKeysRequest(self.selfClient.missingClients!)
        _ = [missingUser.remoteIdentifier!.transportString(): [firstMissingClient.remoteIdentifier, secondMissingClient.remoteIdentifier]]
        
        // then
        AssertOptionalNotNil(request, "Should create request to fetch clients' keys") { request in
            XCTAssertEqual(request.transportRequest.method, ZMTransportRequestMethod.methodPOST)
            XCTAssertEqual(request.transportRequest.path, "/users/prekeys")
            let userPayload = request.transportRequest.payload?.asDictionary()?[missingUser.remoteIdentifier!.transportString()] as? NSArray
            AssertOptionalNotNil(userPayload, "Clients map should contain missid user id") {userPayload in
                XCTAssertTrue(userPayload.contains(firstMissingClient.remoteIdentifier!), "Clients map should contain all missed clients id for each user")
                XCTAssertTrue(userPayload.contains(secondMissingClient.remoteIdentifier!), "Clients map should contain all missed clients id for each user")
            }
        }
    }

    func testThatItCreatesARequestToFetchMissedKeysIfClientHasMissingClientsAndMissingKeyIsModified() {
        // given
        
        self.selfClient.missesClient(self.otherClient)
        sut.notifyChangeTrackers(self.selfClient)
        
        // when
        let request = self.sut.nextRequest()
        
        // then
        assertRequestEqualsExpectedRequest(request)
    }

    func testThatItDoesNotCreateARequestToFetchMissedKeysIfClientHasMissingClientsAndMissingKeyIsNotModified() {
        // given
        self.selfClient.mutableSetValue(forKey: ZMUserClientMissingKey).add(self.otherClient)
        sut.notifyChangeTrackers(self.selfClient)
        
        // when
        let request = self.sut.nextRequest()
        
        // then
        XCTAssertNil(request, "Should not fetch missing clients keys if missing key is not modified")
    }

    func testThatItDoesNotCreateARequestToFetchMissedKeysIfClientDoesNotHaveMissingClientsAndMissingKeyIsNotModified() {
        // given
        self.selfClient.missingClients = nil
        sut.notifyChangeTrackers(self.selfClient)
        
        // when
        let request = self.sut.nextRequest()
        
        // then
        XCTAssertNil(request, "Should not fetch missing clients keys if missing key is not modified")
    }

    func testThatItDoesNotCreateARequestToFetchMissedKeysIfClientDoesNotHaveMissingClientsAndMissingKeyIsModified() {
        // given
        self.selfClient.missingClients = nil
        self.selfClient.setLocallyModifiedKeys(Set(arrayLiteral: ZMUserClientMissingKey))
        sut.notifyChangeTrackers(self.selfClient)
        
        // when
        let request = self.sut.nextRequest()
        
        // then
        XCTAssertNil(request, "Should not fetch missing clients keys if missing key is not modified")
    }

    func testThatItPaginatesMissedClientsRequest() {
        
        self.sut.requestsFactory = MissingClientsRequestFactory(pageSize: 1)
        
        // given
        self.selfClient.missesClient(self.otherClient)
        let client2 = self.createClient(user: self.otherUser)
        self.selfClient.missesClient(client2)
        
        sut.notifyChangeTrackers(selfClient)
        
        // when
        let firstRequest = self.sut.nextRequest()
        
        // then
        assertRequestEqualsExpectedRequest(firstRequest)
        firstRequest?.complete(with: ZMTransportResponse(payload: NSDictionary(), httpStatus: 200, transportSessionError: nil))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // and when
        let secondRequest = self.sut.nextRequest()
        
        // then
        assertRequestEqualsExpectedRequest(secondRequest)
        secondRequest?.complete(with: ZMTransportResponse(payload: NSDictionary(), httpStatus: 200, transportSessionError: nil))
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // and when
        let thirdRequest = self.sut.nextRequest()
        
        // then
        XCTAssertNil(thirdRequest, "Should not request clients keys any more")
    }

    func testThatItRemovesMissingClientWhenResponseContainsItsKey() {
        //given
        let request = missingClientsRequest(missingClients: [self.otherClient])
        
        //when
        let _ = self.sut.updateUpdatedObject(selfClient,
                                             requestUserInfo: request.userInfo,
                                             response: self.response(forMissing: [self.otherClient]),
                                             keysToParse: request.keys)
        
        //then
        XCTAssertEqual(selfClient.missingClients!.count, 0)
    }

    func testThatItRemovesMissingClientWhenResponseDoesNotContainItsKey() {
        //given
        let request = self.missingClientsRequest(missingClients: [otherClient])
        
        //when
        let _ = self.sut.updateUpdatedObject(self.selfClient,
                                             requestUserInfo: request.userInfo,
                                             response: ZMTransportResponse(payload: [String: [String: AnyObject]]() as NSDictionary, httpStatus: 200, transportSessionError: nil),
                                             keysToParse: request.keys)
        
        //then
        XCTAssertEqual(selfClient.missingClients!.count, 0)
    }

    func testThatItRemovesOtherMissingClientsEvenIfOneOfThemHasANilValue() {
        //given
        let payload : [ String : [String : Any]] = [
            otherClient.user!.remoteIdentifier!.transportString() :
                [
                    otherClient.remoteIdentifier!: [
                        "id": 3, "key": self.validPrekey
                    ],
                    "2360fe0d2adc69e8" : NSNull()
            ]
        ]
        let request = missingClientsRequest(missingClients: [otherClient])
        
        //when
        let _ = self.sut.updateUpdatedObject(selfClient,
                                             requestUserInfo: request.userInfo,
                                             response: ZMTransportResponse(payload: payload as NSDictionary, httpStatus: 200, transportSessionError: nil),
                                             keysToParse: request.keys)
        
        //then
        XCTAssertEqual(selfClient.missingClients!.count, 0)
    }
    
    func testThatItRemovesMissingClientsIfTheRequestForThoseClientsDidNotGiveUsAnyPrekey() {
        
        //given
        let payload : [ String : [String : AnyObject]] = [
            self.otherUser.remoteIdentifier!.transportString() : [:]
        ]
        let otherClient2 = self.createClient(user: self.otherUser)
        let request = missingClientsRequest(missingClients: [self.otherClient, otherClient2])
        
        //when
        let _ = self.sut.updateUpdatedObject(selfClient,
                                             requestUserInfo: request.userInfo,
                                             response: ZMTransportResponse(payload: payload as NSDictionary, httpStatus: 200, transportSessionError: nil),
                                             keysToParse: request.keys)
        
        //then
        XCTAssertEqual(selfClient.missingClients!.count, 0)
    }

    func testThatItAddsMissingClientToCurroptedClientsStoreIfTheRequestForTheClientDidNotGiveUsAnyPrekey() {
        
        //given
        let payload = [self.otherUser.remoteIdentifier!.transportString() : [self.otherClient.remoteIdentifier!: ""]] as [String: [String : Any]]
        let request = missingClientsRequest(missingClients: [self.otherClient])
        
        //when
        _ = self.sut.updateUpdatedObject(selfClient,
                                         requestUserInfo: request.userInfo,
                                         response: ZMTransportResponse(payload: payload as NSDictionary, httpStatus: 200, transportSessionError: nil),
                                         keysToParse: request.keys)
        
        //then
        XCTAssertEqual(selfClient.missingClients!.count, 0)
        XCTAssertTrue(self.otherClient.failedToEstablishSession)
    }
    

    func testThatItDoesNotRemovesMissingClientsIfTheRequestForThoseClientsGivesUsAtLeastOneNewPrekey() {
        
        //given
        let response = self.response(forMissing: [self.otherClient])
        let otherClient2 = self.createClient(user: self.otherUser)
        let request = missingClientsRequest(missingClients: [self.otherClient, otherClient2])
        
        //when
        
        let _ = self.sut.updateUpdatedObject(selfClient,
                                             requestUserInfo: request.userInfo,
                                             response: response,
                                             keysToParse: request.keys)
        
        //then
        XCTAssertEqual(selfClient.missingClients, Set([otherClient2]))
        
    }

    func testThatItDoesNotRemovesMissingClientsThatWereNotInTheOriginalRequestWhenThePayloadDoesNotContainAnyPrekey() {
        
        //given
        let payload : [ String : [String : AnyObject]] = [
            self.otherUser.remoteIdentifier!.transportString() : [:]
        ]
        let otherClient2 = self.createClient(user: self.otherUser)
        let request = missingClientsRequest(missingClients: [self.otherClient])
        
        //when
        selfClient.missesClient(otherClient2)
        let _ = self.sut.updateUpdatedObject(selfClient,
                                             requestUserInfo: request.userInfo,
                                             response: ZMTransportResponse(payload: payload as NSDictionary, httpStatus: 200, transportSessionError: nil),
                                             keysToParse: request.keys)
        
        //then
        XCTAssertEqual(selfClient.missingClients, Set(arrayLiteral: otherClient2))
    }
    

    func testThatItRemovesMessagesMissingClientWhenEstablishedSessionWithClient() {
        //given
        let message = self.message(missingRecipient: self.otherClient)
        let request = missingClientsRequest(missingClients: [self.otherClient])
        
        //when
        let _ = self.sut.updateUpdatedObject(selfClient,
                                             requestUserInfo: request.userInfo,
                                             response: self.response(forMissing: [self.otherClient]),
                                             keysToParse: request.keys)
        
        //then
        XCTAssertEqual(message.missingRecipients.count, 0)
        XCTAssertFalse(message.isExpired)
    }

    func testThatItDoesNotExpireMessageWhenEstablishedSessionWithClient() {
        //given
        let message = self.message(missingRecipient: self.otherClient)
        let request = missingClientsRequest(missingClients: [self.otherClient])
        
        //when
        let _ = self.sut.updateUpdatedObject(selfClient,
                                             requestUserInfo: request.userInfo,
                                             response:  self.response(forMissing: [self.otherClient]),
                                             keysToParse: request.keys)
        
        //then
        XCTAssertFalse(message.isExpired)
    }

    func testThatItSetsFailedToEstablishSessionOnAMessagesWhenFailedtoEstablishSessionWithClient() {
        //given
        let message = self.message(missingRecipient: otherClient)
        
        let payload: [String: [String: Any]] = [self.otherUser.remoteIdentifier!.transportString(): [self.otherClient.remoteIdentifier!: ["key": "a2V5"]]]
        let request = missingClientsRequest(missingClients: [otherClient])
        
        //when
        self.performIgnoringZMLogError {
            let _ = self.sut.updateUpdatedObject(self.selfClient,
                                                 requestUserInfo: request.userInfo,
                                                 response: ZMTransportResponse(payload: payload as NSDictionary, httpStatus: 200, transportSessionError: nil),
                                                 keysToParse: request.keys)
        }
        //then
        XCTAssertFalse(message.isExpired)
        XCTAssertTrue(otherClient.failedToEstablishSession)
    }
    
    func testThatItRemovesMessagesMissingClientWhenFailedToEstablishSessionWithClient() {
        //given
        let message = self.message(missingRecipient: otherClient)
        
        let payload: [String: [String: Any]] = [otherClient.user!.remoteIdentifier!.transportString(): [otherClient.remoteIdentifier!: ["key": "a2V5"]]]
        let request = missingClientsRequest(missingClients: [self.otherClient])
        
        //when
        self.performIgnoringZMLogError {
            let _ = self.sut.updateUpdatedObject(self.selfClient,
                                                 requestUserInfo: request.userInfo,
                                                 response: ZMTransportResponse(payload: payload as NSDictionary, httpStatus: 200, transportSessionError: nil),
                                                 keysToParse: request.keys)
        }
        
        //then
        XCTAssertEqual(message.missingRecipients.count, 0)
    }

    func testThatItRemovesMessagesMissingClientWhenClientHasNoKey() {
        //given
        let payload = [String: [String: AnyObject]]()
        let message = self.message(missingRecipient: otherClient)
        let request = missingClientsRequest(missingClients: [otherClient])
        
        //when
        let _ = self.sut.updateUpdatedObject(selfClient,
                                             requestUserInfo: request.userInfo,
                                             response: ZMTransportResponse(payload: payload as NSDictionary, httpStatus: 200, transportSessionError: nil),
                                             keysToParse: request.keys)
        
        //then
        XCTAssertEqual(message.missingRecipients.count, 0)
    }
    
    func testThatItDoesSetFailedToEstablishSessionOnAMessageWhenClientHasNoKey() {
        //given
        let message = self.message(missingRecipient: otherClient)
        let payload = [String: [String: AnyObject]]()
        let request = missingClientsRequest(missingClients: [otherClient])
        
        //when
        let _ = self.sut.updateUpdatedObject(selfClient,
                                             requestUserInfo: request.userInfo,
                                             response: ZMTransportResponse(payload: payload as NSDictionary, httpStatus: 200, transportSessionError: nil),
                                             keysToParse: request.keys)
        
        //then
        XCTAssertFalse(message.isExpired)
        XCTAssertTrue(otherClient.failedToEstablishSession)
    }
    

    
    func testThatItCreatesMissingClientsRequestAfterRemoteSelfClientIsFetched() {
        
        // given
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        syncMOC.saveOrRollback()
        sut.notifyChangeTrackers(selfClient)
        
        // when
        let request = self.sut.nextRequest()
        
        // then
        AssertOptionalNotNil(request, "Should create request to fetch clients' keys") {request in
            XCTAssertEqual(request.method, ZMTransportRequestMethod.methodPOST)
            XCTAssertEqual(request.path, "/users/prekeys")
            let payloadDictionary = request.payload!.asDictionary()!
            let userPayload = payloadDictionary[payloadDictionary.keys.first!] as? NSArray
            AssertOptionalNotNil(userPayload, "Clients map should contain missid user id") {userPayload in
                XCTAssertTrue(userPayload.contains(self.selfClient.remoteIdentifier!), "Clients map should contain all missed clients id for each user")
            }
        }
    }
    
    func testThatItResetsKeyForMissingClientIfThereIsNoMissingClient(){
        // given
        self.selfClient.setLocallyModifiedKeys(Set(arrayLiteral: ZMUserClientMissingKey))
        XCTAssertTrue(self.selfClient.keysThatHaveLocalModifications.contains(ZMUserClientMissingKey))
        
        // when
        let shouldCreateRequest = sut.shouldCreateRequest(toSyncObject: selfClient,
                                                          forKeys: Set(arrayLiteral: ZMUserClientMissingKey),
                                                          withSync: sut.modifiedSync)
        
        // then
        XCTAssertFalse(shouldCreateRequest)
        XCTAssertFalse(self.selfClient.keysThatHaveLocalModifications.contains(ZMUserClientMissingKey))
        
    }

    func testThatItDoesNotResetKeyForMissingClientIfThereIsAMissingClient(){
        // given
        self.selfClient.missesClient(self.otherClient)
        self.selfClient.setLocallyModifiedKeys(Set(arrayLiteral: ZMUserClientMissingKey))
        XCTAssertTrue(self.selfClient.keysThatHaveLocalModifications.contains(ZMUserClientMissingKey))
        
        // when
        let shouldCreateRequest = sut.shouldCreateRequest(toSyncObject: self.selfClient,
                                                          forKeys: Set(arrayLiteral: ZMUserClientMissingKey),
                                                          withSync: sut.modifiedSync)
        
        // then
        XCTAssertTrue(shouldCreateRequest)
        XCTAssertTrue(self.selfClient.keysThatHaveLocalModifications.contains(ZMUserClientMissingKey))
    }
}

extension MissingClientsRequestStrategyTests {
    
    func assertRequestEqualsExpectedRequest(_ request: ZMTransportRequest?) {
        let expectedRequest = sut.requestsFactory.fetchMissingClientKeysRequest(self.selfClient!.missingClients!).transportRequest!
        
        AssertOptionalNotNil(request, "Should return request if there is inserted UserClient object") { request in
            XCTAssertNotNil(request.payload, "Request should contain payload")
            XCTAssertEqual(request.method, expectedRequest.method)
            XCTAssertEqual(request.path, expectedRequest.path)
            XCTAssertTrue(request.payload!.isEqual(expectedRequest.payload))
        }
    }
    
    /// Returns response for missing clients
    func response(forMissing clients: [UserClient]) -> ZMTransportResponse {
        var payload : [String: [String: Any]] = [:]
        for missingClient in clients {
            let key = missingClient.user!.remoteIdentifier!.transportString()
            var prevValue = payload[key] ?? [:]
            prevValue[missingClient.remoteIdentifier!] = [
                "id" : 12,
                "key" : self.validPrekey
            ]
            payload[key] = prevValue
        }
        return ZMTransportResponse(payload: payload as NSDictionary, httpStatus: 200, transportSessionError: nil)
    }
    
    /// Returns missing client request
    func missingClientsRequest(missingClients: [UserClient]) -> ZMUpstreamRequest
    {
        // make sure that we are missing those clients
        for missingClient in missingClients {
            self.selfClient.missesClient(missingClient)
        }
        return sut.requestsFactory.fetchMissingClientKeysRequest(selfClient.missingClients!)
    }
    
    /// Creates a message missing a client
    func message(missingRecipient: UserClient) -> ZMClientMessage {
        let message = self.groupConversation.appendMessage(withText: "Test message with missing") as! ZMClientMessage
        message.missesRecipient(missingRecipient)
        return message
    }
}
