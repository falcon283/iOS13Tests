import Combine
import Foundation
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

// Usage

let publisher = Publishers.BlockPublisher<Int, Never> { subscription  in
    
    let item = DispatchWorkItem { [weak subscription] in
        (0...10).forEach { _ = subscription?.receive($0) }
        subscription?.receive(completion: .finished)
    }

    DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: item)

    return {
        print("Cancel")
        item.cancel()
    }
}

let subscriber = CustomSubscriber<Int, Never>()

publisher
    .print("custom")
    .subscribe(subscriber)


let sub = publisher
    .print("sink")
    .sink(receiveCompletion: { print($0) }, receiveValue: { print($0) })
