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

@import WireRequestStrategy;

typedef NS_ENUM(NSInteger, ZMAppState){
    ZMAppStateUnauthenticated,
    ZMAppStateSyncing,
    ZMAppStateEventProcessing
};

typedef NS_OPTIONS(NSInteger, ZMStrategyConfigurationOption) {
    ZMStrategyConfigurationOptionDoesNotAllowRequests = 0,
    ZMStrategyConfigurationOptionAllowsRequestsWhileUnauthenticated = 1 << 0,
    ZMStrategyConfigurationOptionAllowsRequestsDuringSync = 1 << 1,
    ZMStrategyConfigurationOptionAllowsRequestsDuringEventProcessing = 1 << 2,
};


@protocol ClientDeletionDelegate <NSObject>
- (void)didDetectCurrentClientDeletion;
@end


@protocol ZMAppStateDelegate <DeliveryConfirmationDelegate, ClientDeletionDelegate, ZMRequestCancellation>
@property (nonatomic, readonly) ZMAppState appState;
@end



@interface ZMAbstractRequestStrategy : NSObject <ZMRequestGenerator>

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext*)moc
                            appStateDelegate:(id<ZMAppStateDelegate>)appStateDelegate;

/// Subclasses must override this method;
- (ZMTransportRequest *)nextRequestIfAllowed;

- (void)tearDown;

@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, weak, readonly) id<ZMAppStateDelegate> appStateDelegate;
@property (nonatomic, readonly) ZMStrategyConfigurationOption configuration;

@end


