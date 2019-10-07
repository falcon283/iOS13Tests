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
    private let receiveClosure: (Input) -> Void
    private let receiveCompletionClosure: (Subscribers.Completion<Failure>) -> Void

    init(receive: @escaping (Input) -> Void, receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void) {
        receiveClosure = receive
        receiveCompletionClosure = receiveCompletion
    }

    public func receive(_ input: Input) -> Void {
        guard isCancelled == false else { return }
        receiveClosure(input)
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
    public let start: () -> Void

    static let empty = Orchestrator(stop: {}, start: {})
}

public protocol DemandLogic {
    func request(_ demand: Subscribers.Demand)
    func receiveIfAllowed(_ receive: () -> Subscribers.Demand)
}

public class DefaultDemand: DemandLogic {

    @Synchronized private var residualDemand: Subscribers.Demand = .unlimited

    public func request(_ demand: Subscribers.Demand) {
        self.residualDemand = demand
    }

    public func receiveIfAllowed(_ receive: () -> Subscribers.Demand) {
        guard residualDemand > .max(0) else { return }
        residualDemand -= .max(1)
        residualDemand += receive()
    }
}

public typealias AsyncTask<Input, Failure: Error> = (Observer<Input, Failure>) -> Orchestrator

public struct Async<Output, Failure: Error>: Publisher {

    private let task: AsyncTask<Output, Failure>

    public init(task: @escaping AsyncTask<Output, Failure>) {
        self.task = task
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        subscriber.receive(subscription: AsyncSubscription(publisher: self, subscriber: AnySubscriber(subscriber)))
    }

    private class AsyncSubscription<Input, Failure: Error>: Subscription {

        @Synchronized private var subscriber: AnySubscriber<Input, Failure>?
        @Synchronized private var orchestrator: Orchestrator?
        @Synchronized private var observer: Observer<Input, Failure>?

        private let publisher: Async<Input, Failure>
        private let demandTracker = DefaultDemand()

        init(publisher: Async<Input, Failure>, subscriber: AnySubscriber<Input, Failure>) {
            self.publisher = publisher
            self.subscriber = subscriber
        }

        func request(_ demand: Subscribers.Demand) {
            demandTracker.request(demand)

            let observer = Observer<Input, Failure>(
                receive: { [weak self] input in
                    self?.demandTracker.receiveIfAllowed { self?.subscriber?.receive(input) ?? .none }
                },
                receiveCompletion: { [weak self] completion in
                    self?.subscriber?.receive(completion: completion)
            })

            self.observer = observer
            orchestrator = publisher.task(observer)
            orchestrator?.start()
        }

        func cancel() {
            observer?.cancel()
            subscriber = nil
            orchestrator?.stop()
        }
    }
}

extension DispatchQueue {

    func publisher<Output, Failure: Error>(_ task: @escaping AsyncTask<Output, Failure>) -> AnyPublisher<Output, Failure> {
        return Async(task: task).subscribe(on: self).eraseToAnyPublisher()
    }
}

//let c = Async<Int, Never> { observer in
//
//    let item = DispatchWorkItem {
//
//        for i in 0..<10 {
//            observer.receive(i)
//        }
//
//        observer.receive(completion: .finished)
//    }
//
//    return Orchestrator(stop: { item.cancel() },
//                        start: { DispatchQueue.global().async(execute: item) })
//}
//.print()
//.sink {
//    print("Value: \($0)")
//}
//c.cancel()

let c = DispatchQueue.global().publisher { (observer: Observer<Int, Never>) in

    observer.receive(5)
    observer.receive(15)
    observer.receive(25)

    observer.receive(completion: .finished)

    return .empty
}
.print()
    .sink { _ in }
