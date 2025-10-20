import CNetCDF
import Foundation

// MARK: - File Modes

/// File access mode for opening existing NetCDF files
public struct AccessMode: Sendable {
    internal let rawValue: Int32

    /// Open file for reading only
    public static let read = AccessMode(rawValue: NC_NOWRITE)

    /// Open file for reading and writing
    public static let write = AccessMode(rawValue: NC_WRITE)
}

/// File creation mode for creating new NetCDF files
public struct CreationMode: Sendable {
    internal let rawValue: Int32

    /// Create a new file, overwriting if it exists
    public static let overwrite = CreationMode(rawValue: NC_CLOBBER)

    /// Create a new file, fail if it already exists
    public static let exclusive = CreationMode(rawValue: NC_NOCLOBBER)
}

/// NetCDF error
public enum NetCDFError: Error, CustomStringConvertible, Equatable {
    /// File not found or cannot be opened
    case fileNotFound(path: String)

    /// File already exists (when using createExclusive)
    case fileAlreadyExists(path: String)

    /// Permission denied
    case permissionDenied(path: String)

    /// Invalid NetCDF file format
    case invalidFormat(path: String)

    /// Invalid dimension ID
    case invalidDimension(id: Int)

    /// Invalid variable ID
    case invalidVariable(id: Int)

    /// Invalid attribute
    case invalidAttribute(name: String)

    /// File is not open
    case fileNotOpen

    /// Underlying NetCDF error with description
    case netcdfError(code: Int32, message: String)

    public var description: String {
        switch self {
        case .fileNotFound(let path):
            return "NetCDF file not found: \(path)"
        case .fileAlreadyExists(let path):
            return "NetCDF file already exists: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .invalidFormat(let path):
            return "Invalid NetCDF format: \(path)"
        case .invalidDimension(let id):
            return "Invalid dimension ID: \(id)"
        case .invalidVariable(let id):
            return "Invalid variable ID: \(id)"
        case .invalidAttribute(let name):
            return "Invalid attribute: \(name)"
        case .fileNotOpen:
            return "NetCDF file is not open"
        case .netcdfError(let code, let message):
            return "NetCDF error (\(code)): \(message)"
        }
    }

    internal init?(code: Int32, context: String? = nil) {
        guard code != NC_NOERR else { return nil }

        let message = String(cString: nc_strerror(code))

        // Map common error codes to specific cases
        // NetCDF returns positive errno values for system errors
        if let path = context {
            // Check if it's a file-not-found error (message contains common phrases)
            let lowerMessage = message.lowercased()
            if lowerMessage.contains("no such file") || lowerMessage.contains("not found") {
                self = .fileNotFound(path: path)
                return
            } else if lowerMessage.contains("exists") || lowerMessage.contains("file exists") {
                self = .fileAlreadyExists(path: path)
                return
            } else if lowerMessage.contains("permission") || lowerMessage.contains("denied") {
                self = .permissionDenied(path: path)
                return
            }
        }

        self = .netcdfError(code: code, message: message)
    }
}

/// NetCDF File
///
/// A type-safe wrapper around NetCDF C library for reading and writing NetCDF files.
///
/// Example:
/// ```swift
/// // Create a new file
/// let file = try NetCDFFile(creating: fileURL)
///
/// // Open an existing file for reading
/// let file = try NetCDFFile(reading: fileURL)
///
/// // Open an existing file for writing
/// let file = try NetCDFFile(writing: fileURL)
///
/// // Open with explicit mode
/// let file = try NetCDFFile(opening: fileURL, mode: .write)
///
/// // Query file information
/// print("Dimensions: \(try file.dimensionCount)")
/// print("Variables: \(try file.variableCount)")
/// ```
public final class NetCDFFile {
    private var ncid: Int32
    private(set) public var isOpen: Bool

    // MARK: - Initialization

    /// Internal initializer
    private init(ncid: Int32) {
        self.ncid = ncid
        self.isOpen = true
    }

    /// Opens an existing NetCDF file for reading
    ///
    /// - Parameter url: The file URL to open
    /// - Throws: `NetCDFError` if the file cannot be opened
    public convenience init(reading url: URL) throws {
        try self.init(opening: url, mode: .read)
    }

    /// Opens an existing NetCDF file for writing
    ///
    /// - Parameter url: The file URL to open
    /// - Throws: `NetCDFError` if the file cannot be opened
    public convenience init(writing url: URL) throws {
        try self.init(opening: url, mode: .write)
    }

    /// Opens an existing NetCDF file with the specified access mode
    ///
    /// - Parameters:
    ///   - url: The file URL to open
    ///   - mode: The access mode (read or write)
    /// - Throws: `NetCDFError` if the file cannot be opened
    public convenience init(opening url: URL, mode: AccessMode) throws {
        let path = url.path
        var ncid: Int32 = -1
        let status = nc_open(path, mode.rawValue, &ncid)

        if let error = NetCDFError(code: status, context: path) {
            throw error
        }

        self.init(ncid: ncid)
    }

    /// Creates a new NetCDF file, overwriting if it exists
    ///
    /// - Parameter url: The file URL to create
    /// - Throws: `NetCDFError` if the file cannot be created
    public convenience init(creating url: URL) throws {
        try self.init(creating: url, mode: .overwrite)
    }

    /// Creates a new NetCDF file with the specified creation mode
    ///
    /// - Parameters:
    ///   - url: The file URL to create
    ///   - mode: The creation mode (overwrite or exclusive)
    /// - Throws: `NetCDFError` if the file cannot be created
    public convenience init(creating url: URL, mode: CreationMode) throws {
        let path = url.path
        var ncid: Int32 = -1
        let status = nc_create(path, mode.rawValue, &ncid)

        if let error = NetCDFError(code: status, context: path) {
            throw error
        }

        self.init(ncid: ncid)
    }

    // MARK: - String-based Convenience

    /// Opens an existing NetCDF file for reading
    ///
    /// - Parameter path: The file path to open
    /// - Throws: `NetCDFError` if the file cannot be opened
    public convenience init(reading path: String) throws {
        try self.init(reading: URL(fileURLWithPath: path))
    }

    /// Creates a new NetCDF file
    ///
    /// - Parameter path: The file path to create
    /// - Throws: `NetCDFError` if the file cannot be created
    public convenience init(creating path: String) throws {
        try self.init(creating: URL(fileURLWithPath: path))
    }

    // MARK: - Scoped Resource Management

    /// Opens an existing NetCDF file for reading and automatically closes it after the closure completes.
    ///
    /// This method provides automatic resource cleanup. The file will be closed when the closure
    /// returns, whether it completes normally or throws an error.
    ///
    /// - Parameters:
    ///   - url: The file URL to open
    ///   - body: A closure that receives the opened file and returns a result
    /// - Returns: The value returned by the closure
    /// - Throws: `NetCDFError` if the file cannot be opened or closed, or any error thrown by the closure
    ///
    /// Example:
    /// ```swift
    /// let dimCount = try NetCDFFile.withFile(reading: fileURL) { file in
    ///     try file.dimensionCount
    /// }
    /// ```
    public static func withFile<T>(
        reading url: URL,
        perform body: (NetCDFFile) throws -> T
    ) throws -> T {
        let file = try NetCDFFile(reading: url)
        var bodyError: Error?
        var result: T?

        do {
            result = try body(file)
        } catch {
            bodyError = error
        }

        // Always try to close
        do {
            try file.close()
        } catch {
            // If body succeeded, throw close error
            // If body failed, ignore close error and rethrow body error
            if bodyError == nil {
                throw error
            }
        }

        // If body threw, rethrow that
        if let error = bodyError {
            throw error
        }

        return result!
    }

    /// Opens an existing NetCDF file for writing and automatically closes it after the closure completes.
    ///
    /// This method provides automatic resource cleanup. The file will be closed when the closure
    /// returns, whether it completes normally or throws an error.
    ///
    /// - Parameters:
    ///   - url: The file URL to open
    ///   - body: A closure that receives the opened file and returns a result
    /// - Returns: The value returned by the closure
    /// - Throws: `NetCDFError` if the file cannot be opened or closed, or any error thrown by the closure
    public static func withFile<T>(
        writing url: URL,
        perform body: (NetCDFFile) throws -> T
    ) throws -> T {
        let file = try NetCDFFile(writing: url)
        var bodyError: Error?
        var result: T?

        do {
            result = try body(file)
        } catch {
            bodyError = error
        }

        // Always try to close
        do {
            try file.close()
        } catch {
            // If body succeeded, throw close error
            // If body failed, ignore close error and rethrow body error
            if bodyError == nil {
                throw error
            }
        }

        // If body threw, rethrow that
        if let error = bodyError {
            throw error
        }

        return result!
    }

    /// Creates a new NetCDF file and automatically closes it after the closure completes.
    ///
    /// This method provides automatic resource cleanup. The file will be closed when the closure
    /// returns, whether it completes normally or throws an error.
    ///
    /// - Parameters:
    ///   - url: The file URL to create
    ///   - mode: The creation mode (overwrite or exclusive)
    ///   - body: A closure that receives the created file and returns a result
    /// - Returns: The value returned by the closure
    /// - Throws: `NetCDFError` if the file cannot be created or closed, or any error thrown by the closure
    public static func withFile<T>(
        creating url: URL,
        mode: CreationMode = .overwrite,
        perform body: (NetCDFFile) throws -> T
    ) throws -> T {
        let file = try NetCDFFile(creating: url, mode: mode)
        var bodyError: Error?
        var result: T?

        do {
            result = try body(file)
        } catch {
            bodyError = error
        }

        // Always try to close
        do {
            try file.close()
        } catch {
            // If body succeeded, throw close error
            // If body failed, ignore close error and rethrow body error
            if bodyError == nil {
                throw error
            }
        }

        // If body threw, rethrow that
        if let error = bodyError {
            throw error
        }

        return result!
    }

    // MARK: - File Operations

    /// Closes the NetCDF file
    ///
    /// After calling this method, the file cannot be used anymore.
    /// It's safe to call this method multiple times.
    ///
    /// - Throws: `NetCDFError` if the file cannot be closed
    public func close() throws {
        guard isOpen else { return }

        let status = nc_close(ncid)
        if let error = NetCDFError(code: status) {
            throw error
        }

        isOpen = false
    }

    // MARK: - File Information

    /// The number of dimensions in the file
    public var dimensionCount: Int {
        get throws {
            try checkOpen()
            var ndims: Int32 = 0
            let status = nc_inq_ndims(ncid, &ndims)

            if let error = NetCDFError(code: status) {
                throw error
            }

            return Int(ndims)
        }
    }

    /// The number of variables in the file
    public var variableCount: Int {
        get throws {
            try checkOpen()
            var nvars: Int32 = 0
            let status = nc_inq_nvars(ncid, &nvars)

            if let error = NetCDFError(code: status) {
                throw error
            }

            return Int(nvars)
        }
    }

    /// The number of global attributes in the file
    public var attributeCount: Int {
        get throws {
            try checkOpen()
            var ngatts: Int32 = 0
            let status = nc_inq_natts(ncid, &ngatts)

            if let error = NetCDFError(code: status) {
                throw error
            }

            return Int(ngatts)
        }
    }

    // MARK: - Private Helpers

    private func checkOpen() throws {
        guard isOpen else {
            throw NetCDFError.fileNotOpen
        }
    }

    deinit {
        if isOpen {
            try? close()
        }
    }
}
