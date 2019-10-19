//
//  UIControlSubscriber.swift
//  UIControlPublisher
//
//  Created by Alfonso on 05/10/2019.
//  Copyright © 2019 Alfonso. All rights reserved.
//

import Combine
import UIKit

// Subscribers should be Cancellable in order to clean up the owned subscription
public class UIControlSubscriber<Control: UIControl>: Subscriber, Cancellable {
    public typealias Input = Control
    public typealias Failure = Never
    private var subscription: Subscription?
    
    public func receive(subscription: Subscription) {
        self.subscription = subscription // Important: is a responsibility of the subscriber to hold the subscription
        subscription.request(.max(5)) // the subscriber specifies the intial demand
    }
    
    public func receive(_ input: Control) -> Subscribers.Demand {
        print("Input: \(input)")
        return .none // the subscriber specifies the additional demand
    }
    
    public func receive(completion: Subscribers.Completion<Never>) {
        print(completion)
    }
    
    public func cancel() {
        subscription?.cancel()
        subscription = nil
    }
    
    public init() { }
    
    deinit {
        print("deinit UIControlSubscriber")
    }
}
