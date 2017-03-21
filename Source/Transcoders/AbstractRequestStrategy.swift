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

open class AbstractRequestStrategy : NSObject, ZMRequestGenerator {
    
    weak var applicationStatus : ApplicationStatus?
    
    public let managedObjectContext : NSManagedObjectContext
    public var configuration : ZMStrategyConfigurationOption = [.allowsRequestsDuringEventProcessing]
    
    public init(withManagedObjectContext managedObjectContext: NSManagedObjectContext, applicationStatus: ApplicationStatus) {
        self.managedObjectContext = managedObjectContext
        self.applicationStatus = applicationStatus
        
        super.init()
    }
    
    /// Subclasses should override this method. 
    open func nextRequestIfAllowed() -> ZMTransportRequest? {
        return nil
    }
    
    open func nextRequest() -> ZMTransportRequest? {
        guard let applicationStatus = self.applicationStatus else { return nil }
        
        if AbstractRequestStrategy.prerequisites(forApplicationStatus: applicationStatus).isSubset(of: configuration) {
            return nextRequestIfAllowed()
        }
        
        return nil
    }
    
    public class func prerequisites(forApplicationStatus applicationStatus: ApplicationStatus) -> ZMStrategyConfigurationOption {
        var prerequisites : ZMStrategyConfigurationOption = []
        
        if applicationStatus.synchronizationState == .unauthenticated {
            prerequisites.insert(.allowsRequestsWhileUnauthenticated)
        }
        
        if applicationStatus.synchronizationState == .synchronizing {
            prerequisites.insert(.allowsRequestsDuringSync)
        }
        
        if applicationStatus.synchronizationState == .eventProcessing {
            prerequisites.insert(.allowsRequestsDuringEventProcessing)
        }
        
        if applicationStatus.operationState == .background {
            prerequisites.insert(.allowsRequestsWhileInBackground)
        }
        
        return prerequisites
    }

}
