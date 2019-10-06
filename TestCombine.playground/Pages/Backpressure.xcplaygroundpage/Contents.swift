//: [Previous](@previous)

import Foundation
import Combine

private class BackpressureSubscriber<Input, Failure: Error>: Subscriber {

    private let demand: Subscribers.Demand
    @Synchronized private var subscription: Subscription?

    private var receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)?
    @Synchronized private var receiveValue: ((Input) -> Subscribers.Demand)?

    init(demand: Subscribers.Demand, receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)?, receiveValue: @escaping ((Input) -> Subscribers.Demand)) {
        self.demand = demand
        self.receiveCompletion = receiveCompletion
        self.receiveValue = receiveValue
    }

    func receive(subscription: Subscription) {
        self.subscription = subscription
        subscription.request(demand)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        return receiveValue?(input) ?? .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        receiveCompletion?(completion)
        receiveCompletion = nil
        receiveValue = nil
    }

    fileprivate func free() {
        guard subscription != nil else { return }
        subscription?.cancel()
        subscription = nil
    }
}

extension Publisher {

    public func sink(_ maxDemand: Subscribers.Demand,
                     receiveCompletion: ((Subscribers.Completion<Self.Failure>) -> Void)? = nil,
                     receiveValue: @escaping ((Output) -> Subscribers.Demand)) -> AnyCancellable {
        let subscriber = BackpressureSubscriber(demand: maxDemand, receiveCompletion: receiveCompletion, receiveValue: receiveValue)
        let cancellable = AnyCancellable(subscriber.free)
        subscribe(subscriber)
        return cancellable
    }
}


//extension Publisher {
//
//    func backPressured(maxPublishers: Subscribers.Demand) -> AnyPublisher<Self.Output, Self.Failure> {
//        flatMap(maxPublishers: maxPublishers) { CurrentValueSubject<Self.Output, Self.Failure>($0) }
//            .eraseToAnyPublisher()
//    }
//}

let receiveQueue = OperationQueue()
receiveQueue.name = "Receive Queue"
receiveQueue.maxConcurrentOperationCount = 10
receiveQueue.isSuspended = false

let c = (0..<100)
    .publisher
    .subscribe(on: DispatchQueue(label: ""))
    .receive(on: receiveQueue)
//    .backPressured(maxPublishers: .max(5))
    .print()
//    .sink {
//        print("\(Date().timeIntervalSinceReferenceDate) - Value: \($0)")
//    }
    .sink(.max(5)) {
        usleep(useconds_t(0.1 * 1000000.0))
        print("\(Date().timeIntervalSinceReferenceDate) - Value: \($0)")
        return .max(3)
}

//c.cancel()
