//
//  UIControlPublisher.swift
//  UIControlPublisher
//
//  Created by Alfonso on 05/10/2019.
//  Copyright © 2019 Alfonso. All rights reserved.
//

import Combine
import UIKit

public struct UIControlPublisher<Control: UIControl>: Publisher {
    public typealias Output = Control
    public typealias Failure = Never
    
    private let control: Control
    private let event: UIControl.Event

    init(control: Control, event: UIControl.Event) {
        self.control = control
        self.event = event
    }
    
    // The Publisher only creates a new subscription and pass it to the subscriber
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = UIControlSubscription(subscriber: subscriber, control: control, event: event)
        subscriber.receive(subscription: subscription)
    }
}

// MARK: Convenience

public protocol UIControlPublisherBuilder: UIControl { }

public extension UIControlPublisherBuilder {
    func publisher(for event: UIControl.Event) -> UIControlPublisher<Self> {
        UIControlPublisher(control: self, event: event)
    }
}

extension UIControl: UIControlPublisherBuilder { }
