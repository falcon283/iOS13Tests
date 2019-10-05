//: [Previous](@previous)

import Foundation
import Combine

// Subscriber Custom

class CustomSubscriber<Input, Failure: Error>: Subscriber {

    var sub: Subscription?

    func receive(subscription: Subscription) {
        print("Custom Subscriber Receive Subscription")
        sub = subscription
        subscription.request(.max(5))
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        print("Custom Subscriber Value: \(input)")
        return .max(1)
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        print("Custom Subscriber Finished: \(completion)")
        return
    }

    deinit {
        print("Custom Subscriber Deinit")
        sub?.cancel()
    }
}

