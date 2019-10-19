//
//  UIControlSubscription.swift
//  UIControlPublisher
//
//  Created by Alfonso on 05/10/2019.
//  Copyright © 2019 Alfonso. All rights reserved.
//

import Combine
import UIKit

extension UIControlPublisher {
    class UIControlSubscription<Downstream: Subscriber>: Subscription where Downstream.Input == Output {
        private var subscriber: Downstream?
        private let control: Control
        private let event: UIControl.Event
        private var demand: Subscribers.Demand = .none
        
        init(subscriber: Downstream, control: Control, event: UIControl.Event) {
            self.subscriber = subscriber
            self.control = control
            self.event = event
        }
        
        // before the sequence begins, the subscriber specifies its initial demand
        func request(_ demand: Subscribers.Demand) {
            self.demand = demand
            control.addTarget(self, action: #selector(action(sender:)), for: event)
        }
        
        func cancel() {
            control.removeTarget(self, action: #selector(action(sender:)), for: event)
            subscriber = nil
        }
        
        @objc private func action(sender: UIControl) {
            if demand > 0 {
                demand -= 1
                demand += (subscriber?.receive(control) ?? .none)
            }
        }
        
        deinit {
            Swift.print("deinit UIControlSubscription")
        }
    }
}
