import Combine

public typealias CancelClosure = () -> Void

public extension Publishers {
    struct BlockPublisher<Output, Failure: Error>: Publisher {
        private let creationClosure: (BlockSubscription) -> CancelClosure
        
        public init(_ creationClosure: @escaping (BlockSubscription) -> CancelClosure) {
            self.creationClosure = creationClosure
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            let subscription = BlockSubscription(subscriber: AnySubscriber(subscriber), creationClosure: creationClosure)
            subscriber.receive(subscription: subscription)
        }
    }
}

// MARK: Subscription

public extension Publishers.BlockPublisher {
    class BlockSubscription: Subscription, Subscriber {
        public typealias Input = Output
        
        private var subscriber: AnySubscriber<Output, Failure>?
        private var demand: Subscribers.Demand = .none
        private let creationClosure: (BlockSubscription) -> CancelClosure
        internal var cancelAction: CancelClosure?
        
        init(subscriber: AnySubscriber<Output, Failure>, creationClosure: @escaping (BlockSubscription) -> CancelClosure) {
            self.subscriber = subscriber
            self.creationClosure = creationClosure
        }
        
        // MARK: Subscription protocol
        
        public func request(_ demand: Subscribers.Demand) {
            self.demand = demand
            self.cancelAction = creationClosure(self)
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
