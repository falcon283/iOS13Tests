import Combine
import Foundation

public typealias CancelAction = () -> Void
public typealias TaskAction<Input, Failure: Error> = (Subscription & AnyObject, AnySubscriber<Input, Failure>) -> CancelAction?

public struct BlockPublisher<Output, Failure: Error>: Publisher {
    private let creationClosure: TaskAction<Output, Failure>
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        subscriber.receive(subscription: BlockSubscription(task: creationClosure, subscriber: AnySubscriber(subscriber)))
    }
    
    public init(_ creationClosure: @escaping TaskAction<Output, Failure>) {
        self.creationClosure = creationClosure
    }
}

private final  class BlockSubscription<Input, Failure: Error>: Subscription {
    private var cancelAction: CancelAction?

    init(task: TaskAction<Input, Failure>, subscriber: AnySubscriber<Input, Failure>) {
        self.cancelAction = task(self, subscriber)
    }
    
    func request(_ demand: Subscribers.Demand) { }
    
    func cancel() {
        cancelAction?()
    }
}

// usage

let pub = BlockPublisher<Int, Never> { subscription, subscriber in
    let item = DispatchWorkItem { [weak subscription] in
        guard subscription != nil else { return }
        subscriber.receive(0)
        subscriber.receive(1)
        subscriber.receive(2)
        subscriber.receive(completion: .finished)
    }
    
    DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: item)

    return { item.cancel() }
}

let a = pub
    .print()
    .sink {
        value in print(value)
    }
    .cancel()
