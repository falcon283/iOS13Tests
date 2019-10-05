import Combine
import Foundation
import PlaygroundSupport

extension Publishers {
    struct CustomMap<Upstream: Publisher, T>: Publisher {
        typealias Output = T
        typealias Failure = Upstream.Failure
        
        private let upstream: Upstream
        private let map: (Upstream.Output) -> T
        
        // Source publisher in input
        init(upstream: Upstream, map: @escaping (Upstream.Output) -> T) {
            self.upstream = upstream
            self.map = map
        }
        
        // A subcriber of CustomMap coming...
        func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
            let proxySubscriber = Subscribers.CustomMapSubscriber(upstream: upstream, downstream: subscriber, map: map)
            /*
             * Subscribers.CustomMapSubscriber subscribe to the original publisher.
             * Its job is to forward elements to the new arrived subscriber of type S
             */
            upstream.subscribe(proxySubscriber)
        }
    }
}

extension Subscribers {
    final class CustomMapSubscriber<Upstream: Publisher, Downstream: Subscriber>: Subscriber where Downstream.Failure == Upstream.Failure {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        private let downstream: Downstream
        private let map: (Upstream.Output) -> Downstream.Input
        
        init(upstream: Upstream, downstream: Downstream, map: @escaping (Upstream.Output) -> Downstream.Input) {
            self.downstream = downstream
            self.map = map
        }
    
        func receive(subscription: Subscription) {
            // forward the subscription received by the original publisher
            downstream.receive(subscription: subscription)
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            // forward the mapped input do the downstream subscriber
            downstream.receive(map(input))
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            // forward the completion from the original publisher
            downstream.receive(completion: completion)
        }
        
        deinit {
            print("deinit CustomMapSubscriber")
        }
    }
}

extension Publisher {
    func customMap<T>(_ map: @escaping (Output) -> T) -> Publishers.CustomMap<Self, T> {
        Publishers.CustomMap(upstream: self, map: map)
    }
}

[1,2,3,5].publisher
    .delay(for: 1, scheduler: RunLoop.main)
    .customMap { Array(repeating: "1", count: $0).joined() }
    .sink(receiveCompletion: { print($0) }, receiveValue: { print($0) })
