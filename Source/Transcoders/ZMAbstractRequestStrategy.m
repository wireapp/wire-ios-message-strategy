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

#import "ZMAbstractRequestStrategy.h"

@interface ZMAbstractRequestStrategy()
@property (nonatomic) NSManagedObjectContext *managedObjectContext;
@property (nonatomic) id<ZMAppStateDelegate> appStateDelegate;
@end

@implementation ZMAbstractRequestStrategy

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext*)moc appStateDelegate:(id<ZMAppStateDelegate>)appStateDelegate
{
    self = [super init];
    if (self != nil) {
        self.appStateDelegate = appStateDelegate;
        self.managedObjectContext = moc;
    }
    return self;
}

- (ZMStrategyConfigurationOption)configuration
{
    return ZMStrategyConfigurationOptionDoesNotAllowRequests;
}

- (ZMTransportRequest *)nextRequest
{
    if (self.appStateDelegate.appState == ZMAppStateUnauthenticated &&
        (self.configuration & ZMStrategyConfigurationOptionAllowsRequestsWhileUnauthenticated) ==ZMStrategyConfigurationOptionAllowsRequestsWhileUnauthenticated)
    {
        return [self nextRequestIfAllowed];
    }
    if (self.appStateDelegate.appState == ZMAppStateSyncing &&
        (self.configuration & ZMStrategyConfigurationOptionAllowsRequestsDuringSync) ==ZMStrategyConfigurationOptionAllowsRequestsDuringSync)
    {
        return [self nextRequestIfAllowed];
    }
    if (self.appStateDelegate.appState == ZMAppStateEventProcessing &&
        (self.configuration & ZMStrategyConfigurationOptionAllowsRequestsDuringEventProcessing) ==ZMStrategyConfigurationOptionAllowsRequestsDuringEventProcessing)
    {
        return [self nextRequestIfAllowed];
    }
    return nil;
 }
 
- (ZMTransportRequest *)nextRequestIfAllowed
{
    NSAssert(FALSE, @"Subclasses should override this method: [%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
    return nil;
}
 
- (void)tearDown
{
    // NO-OP
}

@end
