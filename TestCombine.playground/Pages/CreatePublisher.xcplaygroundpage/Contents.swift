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

//let p = createPublisher
//    .subscribe(on: DispatchQueue(label: "Subscription Queue"))
//    .receive(on: DispatchQueue(label: "Receive Queue"))
//    .print()
////    .eraseToAnyPublisher()
//
//var c1: AnyCancellable? = p.sink { print("\(Thread.current) - \(Date()) 1: \($0)") }
//c1?.cancel()
//c1 = nil

//var subscriptions = [AnyCancellable]()
//
//let c = p.sink { _ in
//    let task = FakeSyncTaskRunner(duration: 1)
//    task.run()
//}
//
//print(c)

public class Observer<Input, Failure: Error> {

    @Synchronized private var isCancelled: Bool = false
    private let receiveClosure: (Input) -> Subscribers.Demand
    private let receiveCompletionClosure: (Subscribers.Completion<Failure>) -> Void

    init(receive: @escaping (Input) -> Subscribers.Demand, receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void) {
        receiveClosure = receive
        receiveCompletionClosure = receiveCompletion
    }

    public func receive(_ input: Input) -> Subscribers.Demand {
        guard isCancelled == false else { return .none }
        return receiveClosure(input)
    }

    public func receive(completion: Subscribers.Completion<Failure>) -> Void {
        guard isCancelled == false else { return }
        return receiveCompletionClosure(completion)
    }

    fileprivate func cancel() {
        isCancelled = true
    }
}

public struct Orchestrator {
    public let stop: () -> Void
    public let start: (Subscribers.Demand) -> Void
}

public typealias CreationTask<Input, Failure: Error> = (Observer<Input, Failure>, Subscribers.Demand) -> Orchestrator

public struct Create<Output, Failure: Error>: Publisher {

    private let task: CreationTask<Output, Failure>
    private let demand: Subscribers.Demand

    public init(maxValues: Subscribers.Demand = .unlimited, task: @escaping CreationTask<Output, Failure>) {
        self.demand = maxValues
        self.task = task
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        subscriber.receive(subscription: CreateSubscription(publisher: self, subscriber: AnySubscriber(subscriber), maxValues: demand))
    }

    private class CreateSubscription<Input, Failure: Error>: Subscription {

        @Synchronized private var subscriber: AnySubscriber<Input, Failure>?
        private var orchestrator: Orchestrator?

        init(publisher: Create<Input, Failure>, subscriber: AnySubscriber<Input, Failure>, maxValues: Subscribers.Demand) {
            self.subscriber = subscriber

            let observer = Observer<Input, Failure>(
                receive: { [weak self] input in
                    self?.subscriber?.receive(input) ?? .none
                },
                receiveCompletion: { [weak self] completion in
                    self?.subscriber?.receive(completion: completion)
            })

            orchestrator = publisher.task(observer, maxValues)
        }

        func request(_ demand: Subscribers.Demand) {
            orchestrator?.start(demand)
        }

        func cancel() {
            subscriber = nil
            orchestrator?.stop()
        }
    }
}

let c = Create<Int, Never>(maxValues: .max(10)) { observer, maxValues in

    var currenctRequest: Subscribers.Demand!
    let item = DispatchWorkItem {

        let values = [0, 1, 2, 3, 4]
        var requested = min(currenctRequest, maxValues)
        for value in values {
            guard requested > .max(0) else { break }
            requested -= .max(1)
            requested = min(requested + observer.receive(value), maxValues)
        }

        observer.receive(completion: .finished)
    }
    
    return Orchestrator(stop: { item.cancel() },
                        start: { request in currenctRequest = request; DispatchQueue.global().async(execute: item) })
}
.print()
.sink {
    print("Value: \($0)")
}
//c.cancel()
