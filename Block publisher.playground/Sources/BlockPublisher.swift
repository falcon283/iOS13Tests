import Combine

public typealias CancelClosure = () -> Void

public extension Publishers {
    struct BlockPublisher<Output, Failure: Error>: Publisher {
        private let creationClosure: (BlockSubscription) -> CancelClosure
        
        public init(_ creationClosure: @escaping (BlockSubscription) -> CancelClosure) {
            self.creationClosure = creationClosure
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            let subscription = BlockSubscription(subscriber: AnySubscriber(subscriber))
            subscriber.receive(subscription: subscription)
            let action = creationClosure(subscription)
            subscription.cancelAction = action
        }
    }
}

// MARK: Subscription

public extension Publishers.BlockPublisher {
    class BlockSubscription: Subscription, Subscriber {
        public typealias Input = Output
        
        private var subscriber: AnySubscriber<Output, Failure>?
        private var demand: Subscribers.Demand = .none
        internal var cancelAction: CancelClosure?
        
        init(subscriber: AnySubscriber<Output, Failure>) {
            self.subscriber = subscriber
        }
        
        // MARK: Subscription protocol
        
        public func request(_ demand: Subscribers.Demand) {
            self.demand = demand
        }
        
        public func cancel() {
            cancelAction?()
            subscriber = nil
        }
        
        // MARK: Subscriber protocol
        
        // Never called
        public func receive(subscription: Subscription) { }
        
        // Called in the create block
        public func receive(_ input: Output) -> Subscribers.Demand {
            guard demand > 0 else {
                return .none
            }
            demand -= 1
            let additionalDemand = subscriber?.receive(input) ?? .none
            demand += additionalDemand
            return additionalDemand
        }
        
        // Called in the create block
        public func receive(completion: Subscribers.Completion<Failure>) {
            subscriber?.receive(completion: completion)
        }
    }
}
