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
}

extension Publisher {

    func replay2(buffer size: Int = 1) -> Publishers.Replay<Output, Failure> {
        Publishers.Replay(buffer: size, upstream: self)
    }
}

let t = PassthroughSubject<Int, Never>()
let r2 = t.replay2(buffer: 3).autoconnect()

let cc = r2
//    .print()
    .sink { _ in }

t.send(0)
t.send(1)
t.send(2)
t.send(3)
t.send(completion: .finished)

let ccc = r2
.print()
.sink { _ in }
