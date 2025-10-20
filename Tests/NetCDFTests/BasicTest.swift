import Testing
import Foundation
@testable import NetCDF

@Suite("Basic NetCDF Operations")
struct BasicNetCDFTests {

    @Test("Simple file creation")
    func simpleCreate() throws {
        let testFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("simple_test.nc")

        print("Test file path: \(testFile.path)")

        // Remove if exists
        if FileManager.default.fileExists(atPath: testFile.path) {
            try FileManager.default.removeItem(at: testFile)
            print("Removed existing file")
        }

        print("Creating NetCDF file...")
        let file = try NetCDFFile(creating: testFile)
        print("File created successfully, isOpen: \(file.isOpen)")

        print("Closing file...")
        try file.close()
        print("File closed successfully")

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: testFile.path))

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
        print("Test completed")
    }
}
