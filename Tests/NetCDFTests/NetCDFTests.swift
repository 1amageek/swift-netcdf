import Testing
import Foundation
@testable import NetCDF

@Suite("NetCDF File Operations")
struct NetCDFTests {

    @Test("Create NetCDF file with URL")
    func createFileWithURL() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        // Create a new NetCDF file using URL
        let file = try NetCDFFile(creating: testFile)
        #expect(file.isOpen)

        // Close the file
        try file.close()
        #expect(!file.isOpen)

        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: testFile.path))

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("Create NetCDF file with String path")
    func createFileWithString() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_string.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        // Create using String path
        let file = try NetCDFFile(creating: testFile.path)
        #expect(file.isOpen)

        try file.close()

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("Open NetCDF file for reading")
    func openFileForReading() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_open.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        // Create and close a file
        let createFile = try NetCDFFile(creating: testFile)
        try createFile.close()

        // Open the existing file for reading using URL
        let readFile = try NetCDFFile(reading: testFile)
        #expect(readFile.isOpen)

        try readFile.close()

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("Open NetCDF file for writing")
    func openFileForWriting() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_write.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        // Create and close a file
        let createFile = try NetCDFFile(creating: testFile)
        try createFile.close()

        // Open the existing file for writing
        let writeFile = try NetCDFFile(writing: testFile)
        #expect(writeFile.isOpen)

        try writeFile.close()

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("Query NetCDF file information")
    func queryFileInformation() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_inquiry.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        // Create a new file
        let file = try NetCDFFile(creating: testFile)

        // Query file properties using computed properties
        let dimCount = try file.dimensionCount
        let varCount = try file.variableCount
        let attrCount = try file.attributeCount

        // New file should have no dimensions, variables, or attributes
        #expect(dimCount == 0)
        #expect(varCount == 0)
        #expect(attrCount == 0)

        try file.close()

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("Handle NetCDF errors correctly")
    func handleErrors() throws {
        // Try to open a non-existent file
        #expect(throws: NetCDFError.self) {
            try NetCDFFile(reading: "/nonexistent/path/file.nc")
        }
    }

    @Test("Access computed properties and handle file not open error")
    func computedPropertiesAfterClose() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_props.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        let file = try NetCDFFile(creating: testFile)

        // Test that properties can be accessed multiple times
        _ = try file.dimensionCount
        _ = try file.variableCount
        _ = try file.attributeCount

        try file.close()

        // After closing, accessing properties should throw
        #expect(throws: NetCDFError.self) {
            try file.dimensionCount
        }

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("Create file with exclusive mode")
    func createWithExclusiveMode() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_exclusive.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        // Create file with exclusive mode
        let file1 = try NetCDFFile(creating: testFile, mode: .exclusive)
        try file1.close()

        // Try to create again with exclusive mode - should fail
        #expect(throws: NetCDFError.self) {
            try NetCDFFile(creating: testFile, mode: .exclusive)
        }

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("Use withFile for reading with automatic cleanup")
    func withFileReading() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_with_read.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        // Create a file first
        let createFile = try NetCDFFile(creating: testFile)
        try createFile.close()

        // Use withFile to read
        let dimCount = try NetCDFFile.withFile(reading: testFile) { file in
            #expect(file.isOpen)
            return try file.dimensionCount
        }

        #expect(dimCount == 0)

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("Use withFile for writing with automatic cleanup")
    func withFileWriting() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_with_write.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        // Create a file first
        let createFile = try NetCDFFile(creating: testFile)
        try createFile.close()

        // Use withFile to write
        try NetCDFFile.withFile(writing: testFile) { file in
            #expect(file.isOpen)
            _ = try file.variableCount
        }

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("Use withFile for creating with automatic cleanup")
    func withFileCreating() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_with_create.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        // Use withFile to create
        let attrCount = try NetCDFFile.withFile(creating: testFile) { file in
            #expect(file.isOpen)
            return try file.attributeCount
        }

        #expect(attrCount == 0)
        #expect(FileManager.default.fileExists(atPath: testFile.path))

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("withFile propagates body errors")
    func withFileBodyError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_with_error.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        // Create a file first
        let createFile = try NetCDFFile(creating: testFile)
        try createFile.close()

        // Verify that errors from body are propagated
        #expect(throws: NetCDFError.self) {
            try NetCDFFile.withFile(reading: testFile) { file in
                // Close the file inside the body
                try file.close()
                // This should throw fileNotOpen
                _ = try file.dimensionCount
            }
        }

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    @Test("withFile returns value from body")
    func withFileReturnValue() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_with_return.nc")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)

        // Create a file and get all counts
        let (dimCount, varCount, attrCount) = try NetCDFFile.withFile(creating: testFile) { file in
            let dims = try file.dimensionCount
            let vars = try file.variableCount
            let attrs = try file.attributeCount
            return (dims, vars, attrs)
        }

        #expect(dimCount == 0)
        #expect(varCount == 0)
        #expect(attrCount == 0)

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }
}
