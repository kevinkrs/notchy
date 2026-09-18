import Foundation
import os

/// Logs to the unified log and, when `NOTCHY_DEBUG` is set, mirrors to stderr and
/// `~/Library/Logs/Notchy/debug.log`.
/// Shell: `NOTCHY_DEBUG=1 Notchy.app/Contents/MacOS/Notchy`
/// Bundle: `open --env NOTCHY_DEBUG=1 Notchy.app`
enum Diagnostics {
    private static let fileLock = NSLock()
    private static let mirrorToStderr = ProcessInfo.processInfo.environment["NOTCHY_DEBUG"] != nil

    private static let debugFile: FileHandle? = {
        guard mirrorToStderr else { return nil }
        let dir = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/Notchy")
        let url = dir.appending(path: "debug.log")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try? FileHandle(forWritingTo: url)
        handle?.seekToEndOfFile()
        return handle
    }()

    static func log(_ category: String, _ message: @autoclosure () -> String) {
        let text = message()
        // Logger is cheap to create and Sendable; callers may be on any thread (e.g. NSWorkspace completion).
        let logger = Logger(subsystem: "com.krauskevin.notchy", category: category)
        logger.debug("\(text, privacy: .public)")
        if mirrorToStderr {
            let line = Data("\(Date().formatted(.iso8601)) [\(category)] \(text)\n".utf8)
            fileLock.withLock {
                FileHandle.standardError.write(line)
                debugFile?.write(line)
            }
        }
    }
}
