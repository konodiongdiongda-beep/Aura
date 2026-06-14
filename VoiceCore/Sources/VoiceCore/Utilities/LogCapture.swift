import Foundation
import os

public class LogCapture {
    public static let shared = LogCapture()

    private var fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.aura.logcapture")
    private var logBuffer: [String] = []
    private let bufferFlushInterval: TimeInterval = 0.5
    private var flushTimer: Timer?

    private init() {
        setupFileLogging()
    }

    private func setupFileLogging() {
        queue.async { [weak self] in
            guard let self else { return }

            let fileManager = FileManager.default
            let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let logDir = docDir.appendingPathComponent("VoiceLogs")

            try? fileManager.createDirectory(at: logDir, withIntermediateDirectories: true)

            let dateFormatter = ISO8601DateFormatter()
            let timestamp = dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let logFile = logDir.appendingPathComponent("voice_\(timestamp).log")

            fileManager.createFile(atPath: logFile.path, contents: nil)
            self.fileHandle = FileHandle(forWritingAtPath: logFile.path)

            self.log("=== Voice Log Session Started ===")

            self.flushTimer = Timer.scheduledTimer(withTimeInterval: self.bufferFlushInterval, repeats: true) { [weak self] _ in
                self?.flushBuffer()
            }
        }
    }

    public func log(_ message: String, level: String = "INFO") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formatted = "[\(timestamp)] [\(level)] \(message)"

        queue.async { [weak self] in
            self?.logBuffer.append(formatted)
            if self?.logBuffer.count ?? 0 > 100 {
                self?.flushBuffer()
            }
        }
    }

    private func flushBuffer() {
        guard !logBuffer.isEmpty else { return }

        let content = (logBuffer + [""]).joined(separator: "\n")
        if let data = content.data(using: .utf8) {
            fileHandle?.seekToEndOfFile()
            fileHandle?.write(data)
        }
        logBuffer.removeAll()
    }

    public func getLogDirectoryPath() -> String? {
        let fileManager = FileManager.default
        let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logDir = docDir.appendingPathComponent("VoiceLogs")
        return logDir.path
    }

    deinit {
        flushTimer?.invalidate()
        flushBuffer()
        fileHandle?.closeFile()
    }
}
