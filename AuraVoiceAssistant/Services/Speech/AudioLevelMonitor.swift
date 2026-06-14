import Foundation

public final class AudioLevelMonitor: @unchecked Sendable {
    public static let shared = AudioLevelMonitor()

    private let lock = NSLock()
    private var _level: Double = 0.0
    private var _diagnostic: String = ""

    public var currentLevel: Double {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _level
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _level = newValue
        }
    }

    public var diagnostic: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _diagnostic
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _diagnostic = newValue
        }
    }

    private init() {}
}
