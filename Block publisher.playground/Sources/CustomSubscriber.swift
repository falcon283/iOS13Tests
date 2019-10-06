import Combine

public class CustomSubscriber<Input: CustomStringConvertible, Failure: Error>: Subscriber {
    private var subscription: Subscription?
    
    public func receive(subscription: Subscription) {
        self.subscription = subscription
        subscription.request(.max(2))
    }
    
    public func receive(_ input: Input) -> Subscribers.Demand {
        print("Receive \(input)")
        return .none
    }
    
    public func receive(completion: Subscribers.Completion<Failure>) {
        print(completion)
    }
    
    public init() { }
}
