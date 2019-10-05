import Foundation

public final class UnfairLock {

    private var _lock = os_unfair_lock_s()

    public func run<T>(task: () -> T) -> T {
        defer { os_unfair_lock_unlock(&_lock)}
        os_unfair_lock_lock(&_lock)
        return task()
    }
}

@propertyWrapper public struct Synchronized<T> {

    private let lock = UnfairLock()
    private var value: T

    public init(wrappedValue value: T) {
        self.value = value
    }

    public var wrappedValue: T {
        get {
            return lock.run { self.value }
        }
        set {
            lock.run { self.value = newValue }
        }
    }
}

@propertyWrapper public final class WeakRef<T: AnyObject> {

    private class Ref<T: AnyObject> {
        weak var ref: T?

        init(ref: T) {
            self.ref = ref
        }
    }

    @Synchronized private var reference: T?

    public init(wrappedValue: T?) {
        reference = wrappedValue
    }

    public var wrappedValue: T? {
        get { reference }
        set { reference = newValue }
    }
}

class FakeSyncTaskRunner {

    private let duration: TimeInterval
    @Synchronized private var item: DispatchWorkItem?
    private let queue = DispatchQueue(label: "FakeSyncTaskRunner")

    init(duration: TimeInterval = 0) {
        self.duration = duration
    }

    func run() {
        guard item == nil else { return }
        let id = UUID()
        print("\(Date()) FakeSyncTaskRunner Run \(id)")
        let duration = self.duration
        let item = DispatchWorkItem {
            sleep(UInt32(duration))
            print("\(Date()) FakeSyncTaskRunner Run \(id) Finished")
        }
        self.item = item
        queue.sync(execute: item)
    }

    func cancel() {
        item?.cancel()
    }
}
