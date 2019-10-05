//: [Previous](@previous)

import Foundation
import Combine

// Replay

public extension Publishers {

    final class Replay<Output, Failure: Error>: ConnectablePublisher {


        // ***************** Do not use directly this variables ************************ /
        // Workaround for Fucking issue with Property Wrappers.
        // Seems they does not to accept a Generic Concrete Type as input
        // Compiler crash with no error message.
        @Synchronized private var _buffer: [Any] = []
        @Synchronized private var _replay: Any = PassthroughSubject<Output, Failure>()
        // ***************************************************************************** /

        private var buffer: [Output] {
            get { _buffer as! [Output] }
            set { _buffer = newValue }
        }
        private var replay: PassthroughSubject<Output, Failure> { _replay as! PassthroughSubject<Output, Failure> }

        @Synchronized private var bag: [AnyCancellable] = []

        private let bufferSize: Int
        private let upstream: MakeConnectable<AnyPublisher<Output, Failure>>

        public init<P: Publisher>(buffer size: Int, upstream: P) where P.Output == Output, P.Failure == Failure {
            self.bufferSize = Swift.max(0, size)
            self.upstream = MakeConnectable(upstream: upstream.eraseToAnyPublisher())

            self.upstream.sink(receiveCompletion: { _ in }, receiveValue: { [weak self] value in
                guard let self = self else { return }
                self.updateValues(with: value)
            }).store(in: &bag)
        }

        private func updateValues(with value: Output) {
            var newValues = buffer + [value]
            if newValues.count > bufferSize {
                let n = newValues.count - bufferSize
                newValues = Array(newValues.dropFirst(n))
            }
            buffer = newValues
            replay.send(value)
        }

        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            replay.receive(subscriber: subscriber)
            buffer.forEach { _ = subscriber.receive($0) }
        }

        @WeakRef private var connectCancellable: AnyCancellable?

        public func connect() -> Cancellable {
            if let cancellable = connectCancellable {
                return cancellable
            } else {
                let connection = upstream.connect()
                let cancellable = AnyCancellable { connection.cancel() }
                self.connectCancellable = cancellable
                return cancellable
            }
        }
    }
}

extension Publisher {

    func replay(buffer size: Int = 1) -> Publishers.Replay<Output, Failure> {
        Publishers.Replay(buffer: size, upstream: eraseToAnyPublisher())
    }
}
let p = PassthroughSubject<Int, Never>()
let r = p.replay(buffer: 5)

let c1 = r.connect()

p.send(5)
p.send(6)
p.send(7)
p.send(8)
//p.send(completion: .finished)
p.send(9)
p.send(10)
p.send(11)

let c2 = r
    .print()
    .sink { print("1: \($0)") }

p.send(12)


let c3 = r
    .print()
    .sink { print("2: \($0)") }
