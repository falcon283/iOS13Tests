//: [Previous](@previous)

import Foundation
import Combine

// Replay

extension Publishers {

    public class Replay<Output, Failure: Error>: ConnectablePublisher {

        private let subject = CurrentValueSubject<[Output], Failure>([])
        private let upstream: AnyPublisher<Output, Failure>
        private let multicast: Publishers.Multicast<AnyPublisher<[Output], Failure>, CurrentValueSubject<[Output], Failure>>

        public init<P: Publisher>(buffer size: Int, upstream: P) where P.Output == Output, P.Failure == Failure {
            let shared = upstream.share().eraseToAnyPublisher()
            self.upstream = shared
            self.multicast = shared
                .map { [$0] }
                .scan([Output]()) {
                    var result = $0 + $1
                    if result.count > size {
                        let toDrop = result.count - size
                        result = Array(result.dropFirst(toDrop))
                    }
                    return result
            }
            .eraseToAnyPublisher()
            .multicast(subject: subject)
        }

        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            let buffer = subject.value
                .publisher
                .setFailureType(to: Failure.self)
            upstream
                .prepend(buffer)
                .receive(subscriber: subscriber)
        }

        public func connect() -> Cancellable {
            return multicast.connect()
        }
    }

    public class ShareReplay<Output, Failure: Error>: Publisher {

        let upstream: Replay<Output, Failure>

        public init<P: Publisher>(buffer size: Int, upstream: P) where P.Output == Output, P.Failure == Failure {
            self.upstream = upstream.replay(buffer: size)
        }

        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            upstream
                .autoconnect()
                .receive(subscriber: subscriber)
        }
    }
}

extension Publisher {

    func replay(buffer size: Int = 1) -> Publishers.Replay<Output, Failure> {
        Publishers.Replay(buffer: size, upstream: self)
    }

    func shareReplay(buffer size: Int = 1) -> Publishers.ShareReplay<Output, Failure> {
        Publishers.ShareReplay(buffer: size, upstream: self)
    }
}

// Replay Test

//let t1 = PassthroughSubject<Int, Never>()
//let r1 = t1.replay(buffer: 3).autoconnect()
//
//let c1 = r1
//    .sink { _ in }
//
//t1.send(0)
//t1.send(1)
//t1.send(2)
//t1.send(3)
//t1.send(completion: .finished)
//
//let c2 = r1
//    .print()
//    .sink { _ in }

// Share Replay Test

let t2 = PassthroughSubject<Int, Never>()
let r2 = t2.shareReplay(buffer: 3)

let c3 = r2
//    .print()
    .sink { _ in }

t2.send(0)
t2.send(1)
t2.send(2)
t2.send(3)
t2.send(completion: .finished)

let c4 = r2
    .print()
    .sink { _ in }

