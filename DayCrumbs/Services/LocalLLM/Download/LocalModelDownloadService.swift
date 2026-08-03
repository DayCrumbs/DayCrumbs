import Foundation

nonisolated enum LocalModelDownloadError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case httpStatus(Int)
    case invalidResumeResponse
    case responseExceedsExpectedSize
    case incompleteDownload(expected: Int64, actual: Int64)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The model download server returned an invalid response."
        case .httpStatus:
            "The model download could not be completed."
        case .invalidResumeResponse:
            "The partial model download could not be resumed safely."
        case .responseExceedsExpectedSize:
            "The model download exceeded its expected size."
        case .incompleteDownload:
            "The model download ended before the file was complete."
        }
    }
}

typealias LocalModelDownloadProgressHandler =
    @MainActor @Sendable (_ completed: Int64, _ expected: Int64) -> Void

nonisolated protocol LocalModelDownloading: Sendable {
    func download(
        _ descriptor: LocalModelDescriptor,
        progress: @escaping LocalModelDownloadProgressHandler
    ) async throws -> LocalModelFileValidation
}

/// Streams directly to a partial file and resumes with a validated HTTP range.
nonisolated struct URLSessionLocalModelDownloadService:
    LocalModelDownloading,
    @unchecked Sendable
{
    private let storage: any LocalModelStoring
    private let sessionConfiguration: URLSessionConfiguration
    private let progressUpdateByteInterval: Int64

    init(
        storage: any LocalModelStoring = LocalModelStorage(),
        session: URLSession = .shared,
        progressUpdateByteInterval: Int64 = 4 * 1_024 * 1_024
    ) {
        self.storage = storage
        sessionConfiguration = session.configuration
        self.progressUpdateByteInterval = progressUpdateByteInterval
    }

    func download(
        _ descriptor: LocalModelDescriptor,
        progress: @escaping LocalModelDownloadProgressHandler
    ) async throws -> LocalModelFileValidation {
        try Task.checkCancellation()
        try storage.prepareDirectory(for: descriptor)

        var existingByteCount = try storage.partialByteCount(for: descriptor)
        if existingByteCount > descriptor.expectedByteCount {
            try storage.resetPartialFile(for: descriptor)
            existingByteCount = 0
        }

        let availableCapacity = try storage.availableCapacity()
        let safetyMargin: Int64 = 512 * 1_024 * 1_024
        let remainingByteCount = max(
            0,
            descriptor.expectedByteCount - existingByteCount
        )
        guard availableCapacity >= remainingByteCount + safetyMargin else {
            throw LocalModelStorageError.insufficientStorage(
                required: remainingByteCount + safetyMargin,
                available: availableCapacity
            )
        }

        if existingByteCount == descriptor.expectedByteCount {
            return try await finalizeOrDiscardInvalidPartial(descriptor)
        }

        var request = URLRequest(url: descriptor.downloadURL)
        request.timeoutInterval = 60 * 60
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        if existingByteCount > 0 {
            request.setValue(
                "bytes=\(existingByteCount)-",
                forHTTPHeaderField: "Range"
            )
        }

        let runner = LocalModelChunkDownloadRunner(
            storage: storage,
            descriptor: descriptor,
            existingByteCount: existingByteCount,
            progressUpdateByteInterval: progressUpdateByteInterval,
            progress: progress
        )
        try await runner.run(
            request: request,
            configuration: sessionConfiguration
        )
        return try await finalizeOrDiscardInvalidPartial(descriptor)
    }

    private func finalizeOrDiscardInvalidPartial(
        _ descriptor: LocalModelDescriptor
    ) async throws -> LocalModelFileValidation {
        do {
            return try await storage.finalizePartialFile(for: descriptor)
        } catch {
            // A complete payload that fails integrity can never be resumed.
            // Reset it so a user retry performs a clean download.
            try? storage.resetPartialFile(for: descriptor)
            throw error
        }
    }
}

/// Receives URLSession's native `Data` chunks so a multi-gigabyte model is not
/// processed one byte at a time or accumulated in memory.
private nonisolated final class LocalModelChunkDownloadRunner:
    NSObject,
    URLSessionDataDelegate,
    @unchecked Sendable
{
    private let storage: any LocalModelStoring
    private let descriptor: LocalModelDescriptor
    private let initialByteCount: Int64
    private let progressUpdateByteInterval: Int64
    private let progress: LocalModelDownloadProgressHandler
    private let lock = NSLock()

    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var continuation: CheckedContinuation<Void, any Error>?
    private var fileHandle: FileHandle?
    private var completedByteCount: Int64
    private var lastReportedByteCount: Int64
    private var terminalError: (any Error)?

    init(
        storage: any LocalModelStoring,
        descriptor: LocalModelDescriptor,
        existingByteCount: Int64,
        progressUpdateByteInterval: Int64,
        progress: @escaping LocalModelDownloadProgressHandler
    ) {
        self.storage = storage
        self.descriptor = descriptor
        initialByteCount = existingByteCount
        completedByteCount = existingByteCount
        lastReportedByteCount = existingByteCount
        self.progressUpdateByteInterval = progressUpdateByteInterval
        self.progress = progress
    }

    func run(
        request: URLRequest,
        configuration: URLSessionConfiguration
    ) async throws {
        try Task.checkCancellation()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: queue
        )

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                self.session = session
                self.continuation = continuation
                let task = session.dataTask(with: request)
                self.task = task
                lock.unlock()
                task.resume()
            }
        } onCancel: {
            self.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        do {
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LocalModelDownloadError.invalidResponse
            }
            let startByteCount = try prepareFile(for: httpResponse)
            reportProgress(startByteCount)
            completionHandler(.allow)
        } catch {
            setTerminalError(error)
            completionHandler(.cancel)
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        lock.lock()
        defer {
            lock.unlock()
        }
        guard terminalError == nil, let fileHandle else {
            return
        }

        do {
            try fileHandle.write(contentsOf: data)
            completedByteCount += Int64(data.count)
            guard completedByteCount <= descriptor.expectedByteCount else {
                throw LocalModelDownloadError.responseExceedsExpectedSize
            }
            if completedByteCount - lastReportedByteCount
                >= progressUpdateByteInterval {
                lastReportedByteCount = completedByteCount
                reportProgress(completedByteCount)
            }
        } catch {
            terminalError = error
            dataTask.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        lock.lock()
        var finalError = terminalError ?? error
        if finalError == nil {
            do {
                try fileHandle?.synchronize()
                guard completedByteCount == descriptor.expectedByteCount else {
                    throw LocalModelDownloadError.incompleteDownload(
                        expected: descriptor.expectedByteCount,
                        actual: completedByteCount
                    )
                }
            } catch {
                finalError = error
            }
        }

        try? fileHandle?.close()
        fileHandle = nil
        let continuation = self.continuation
        self.continuation = nil
        self.task = nil
        self.session = nil
        let finalByteCount = completedByteCount
        lock.unlock()

        session.finishTasksAndInvalidate()
        if finalError == nil {
            reportProgress(finalByteCount)
            continuation?.resume()
        } else {
            continuation?.resume(throwing: finalError!)
        }
    }

    private func prepareFile(
        for response: HTTPURLResponse
    ) throws -> Int64 {
        var byteCount = initialByteCount
        if initialByteCount > 0 {
            if response.statusCode == 200 {
                try storage.resetPartialFile(for: descriptor)
                byteCount = 0
            } else if response.statusCode == 206 {
                let expectedPrefix = "bytes \(initialByteCount)-"
                guard response.value(
                    forHTTPHeaderField: "Content-Range"
                )?.lowercased().hasPrefix(expectedPrefix) == true else {
                    throw LocalModelDownloadError.invalidResumeResponse
                }
            } else {
                throw LocalModelDownloadError.httpStatus(
                    response.statusCode
                )
            }
        } else {
            guard (200...299).contains(response.statusCode) else {
                throw LocalModelDownloadError.httpStatus(
                    response.statusCode
                )
            }
            try storage.resetPartialFile(for: descriptor)
        }

        let partialURL = try storage.partialFileURL(for: descriptor)
        let fileHandle = try FileHandle(forWritingTo: partialURL)
        try fileHandle.seekToEnd()

        lock.lock()
        self.fileHandle = fileHandle
        completedByteCount = byteCount
        lastReportedByteCount = byteCount
        lock.unlock()
        return byteCount
    }

    private func setTerminalError(_ error: any Error) {
        lock.lock()
        terminalError = error
        lock.unlock()
    }

    private func cancel() {
        lock.lock()
        if terminalError == nil {
            terminalError = CancellationError()
        }
        let task = self.task
        lock.unlock()
        task?.cancel()
    }

    private func reportProgress(_ completed: Int64) {
        let expected = descriptor.expectedByteCount
        Task { @MainActor in
            progress(completed, expected)
        }
    }
}
