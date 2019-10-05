//: [Previous](@previous)

import Foundation
import Combine

public typealias CancelTask = () -> Void
public typealias Task<Input, Failure: Error> = (CreateSubscription<Input, Failure>) -> CancelTask

public struct CreatePublisher<Output, Failure: Error>: Publisher {

    private let task: Task<Output, Failure>
    private let maxDemand: Subscribers.Demand

    public init(maxRequests: Int = 1, task: @escaping Task<Output, Failure>) {
        self.maxDemand = .max(maxRequests)
        self.task = task
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        Swift.print("\(Thread.current) - \(Date()): Publisher: Receive Subscriber")
        let subscription = CreateSubscription(with: maxDemand, subscriber: AnySubscriber(subscriber), publisher: self)
        subscriber.receive(subscription: subscription)
    }

    func makeTask(for subscription: CreateSubscription<Output, Failure>) -> CancelTask {
        return task(subscription)
    }
}

public final class CreateSubscription<Input, Failure: Error>: Subscription {

    @Synchronized private var currentDemand: Subscribers.Demand
    @Synchronized private var cancelTask: CancelTask?

    private var subscriber: AnySubscriber<Input, Failure>?
    private let publisher: CreatePublisher<Input, Failure>

    init(with demand: Subscribers.Demand = .max(1), subscriber: AnySubscriber<Input, Failure>, publisher: CreatePublisher<Input, Failure>) {
        self.currentDemand = demand
        self.subscriber = subscriber
        self.publisher = publisher
    }

    public func request(_ demand: Subscribers.Demand) {
        Swift.print("\(Thread.current) - \(Date()): Subscription Request demand: \(demand)")
        cancelTask = publisher.makeTask(for: self)
    }

    public func cancel() {
        guard cancelTask != nil else { return }
        print("\(Thread.current) - \(Date()): Subscription: Cancel Requested")
        cancelTask?()
        cancelTask = nil
        subscriber = nil
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        subscriber?.receive(completion: completion)
    }

    func receive(_ input: Input) {
        guard currentDemand >= .max(1) else { return }
        currentDemand -= .max(1)
        currentDemand += (subscriber?.receive(input) ?? .none)
    }
}

// Usage test

let createPublisher = CreatePublisher<Int, Never>(maxRequests: 6) { subscription in

    Swift.print("\(Thread.current) - \(Date()): CreateClosure")

    DispatchQueue.global().async { [weak subscription] in
        subscription?.receive(Int.random(in: 0..<1000))
        subscription?.receive(Int.random(in: 0..<1000))
        subscription?.receive(Int.random(in: 0..<1000))
        subscription?.receive(Int.random(in: 0..<1000))
        subscription?.receive(Int.random(in: 0..<1000))
        subscription?.receive(Int.random(in: 0..<1000))
        subscription?.receive(Int.random(in: 0..<1000))
        subscription?.receive(Int.random(in: 0..<1000))
        subscription?.receive(Int.random(in: 0..<1000))

        subscription?.receive(completion: .finished)
    }

//        subscription.receive(Int.random(in: 0..<1000))
//        subscription.receive(Int.random(in: 0..<1000))
//        subscription.receive(Int.random(in: 0..<1000))
//        subscription.receive(Int.random(in: 0..<1000))
//        subscription.receive(Int.random(in: 0..<1000))
//        subscription.receive(Int.random(in: 0..<1000))
//        subscription.receive(Int.random(in: 0..<1000))
//        subscription.receive(Int.random(in: 0..<1000))
//        subscription.receive(Int.random(in: 0..<1000))
//
//        subscription.receive(completion: .finished)

    return { print("\(Thread.current) - \(Date()): Cancelling Task") }
}

let p = createPublisher
    .subscribe(on: DispatchQueue(label: "Subscription Queue"))
    .receive(on: DispatchQueue(label: "Receive Queue"))
    .print()
//    .eraseToAnyPublisher()

var c1: AnyCancellable? = p.sink { print("\(Thread.current) - \(Date()) 1: \($0)") }
c1?.cancel()
//c1 = nil

//var subscriptions = [AnyCancellable]()
//
//let c = p.sink { _ in
//    let task = FakeSyncTaskRunner(duration: 1)
//    task.run()
//}
//
//print(c)
