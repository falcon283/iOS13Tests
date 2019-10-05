import Combine
import UIKit
import PlaygroundSupport


// Create a view
let view = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
//view.backgroundColor = .white
let button = UIButton(frame: view.bounds)
button.setTitle("Hit Me", for: .normal)
view.addSubview(button)

// Usage
let publisher = button.publisher(for: .touchUpInside)

// Important: store inside a AnyCancellable variable to have autocancel
let subscriber = UIControlSubscriber<UIButton>()
publisher.subscribe(subscriber)

let cancellable = publisher.sink { _ in
    print("Event from sink")
}

PlaygroundPage.current.liveView = view
