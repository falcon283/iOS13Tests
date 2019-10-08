import Combine
import Foundation

var subscriptions: Set<AnyCancellable> = []

public extension Publishers {
    final class Replay<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        
        private var subscription: AnyCancellable?
        private let upstream: AnyPublisher<Upstream.Output, Upstream.Failure>
        private var output: [Upstream.Output] = []
        private var completion: Subscribers.Completion<Upstream.Failure>?
        
        init(upstream: Upstream) {
            self.upstream = upstream.share().eraseToAnyPublisher()
            subscription = self.upstream.sink(
                receiveCompletion: { [weak self] completion in self?.completion = completion },
                receiveValue: { [weak self] value in self?.output.append(value) })
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            let subscription = ReplaySubscription(subscriber: subscriber, upstream: upstream, output: output, completion: completion)
            subscriber.receive(subscription: subscription)
        }
        
        deinit {
            subscription = nil
        }
    }
}

private extension Publishers.Replay {
    private class ReplaySubscription<S: Subscriber>: Subscriber, Subscription where S.Failure == Upstream.Failure, S.Input == Upstream.Output {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        private let subscriber: S
        private var demand: Subscribers.Demand = .none
        private var output: [Upstream.Output] = []
        private var completion: Subscribers.Completion<Upstream.Failure>?
        private var upstream: AnyPublisher<Upstream.Output, Upstream.Failure>
        private var upstreamSubscription: Subscription?
        
        init(subscriber: S, upstream: AnyPublisher<Upstream.Output, Upstream.Failure>, output: [Upstream.Output], completion: Subscribers.Completion<Upstream.Failure>?) {
            self.subscriber = subscriber
            self.upstream = upstream
            self.output = output
            self.completion = completion
        }
        
        // Subscription
        
        func request(_ demand: Subscribers.Demand) {
            self.demand = demand
            
            // Handle demand
            for item in output {
                if self.demand > 0 {
                    self.demand -= 1
                    self.demand += subscriber.receive(item)
                } else {
                    break
                }
            }
            
            if let completion = completion {
                subscriber.receive(completion: completion)
            }
            
            upstream.subscribe(self)
        }
        
        func cancel() {
            self.upstreamSubscription?.cancel()
            self.upstreamSubscription = nil
        }
        
        // Subscriber
        
        func receive(subscription: Subscription) { // upstream subscription
            self.upstreamSubscription = subscription
            upstreamSubscription?.request(demand)
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            return subscriber.receive(input)
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            subscriber.receive(completion: completion)
        }
        
        deinit {
            Swift.print("Deinit ReplaySubscription")
        }
    }
}

extension Publisher {
    func replay() -> Publishers.Replay<Self> {
        Publishers.Replay(upstream: self)
    }
}

let timerPublisher = Timer.publish(every: 2, on: .main, in: .default).autoconnect().replay()

timerPublisher
    .print("pub 1")
    .sink(receiveValue: { print($0) } )
    .store(in: &subscriptions)

DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    timerPublisher
        .print("pub 2")
        .sink(receiveValue: { print($0) } )
        .store(in: &subscriptions)
}
