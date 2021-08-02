/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import TSCTestSupport
import TSCBasic
import XCTest

enum SwiftPackageEditor: TSCTestSupport.Product {
    case executable

    var exec: RelativePath {
        RelativePath("swift-package-editor")
    }
}

final class IntegrationTests: XCTestCase {

    func assertFailure(args: String..., stderr: String) {
        do {
            try SwiftPackageEditor.executable.execute(args)
            XCTFail()
        } catch SwiftPMProductError.executionFailure(_, _, let stderrOutput) {
            XCTAssertEqual(stderrOutput, stderr)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func withFixture(named name: String, _ block: (AbsolutePath) throws -> Void) throws {
        let relativePath = RelativePath("Fixtures").appending(component: name)
        let fixturePath = AbsolutePath(Bundle.module.url(forResource: relativePath.pathString, withExtension: nil)!.path)
        try withTemporaryDirectory { tmpDir in
            let destPath = tmpDir.appending(component: name)
            try localFileSystem.copy(from: fixturePath, to: destPath)
            try block(destPath)
        }
    }

    func testAddDependencyArgValidation() throws {
        assertFailure(args: "add-dependency", "http://www.githost.com/repo.git", "--exact", "1.0.0", "--from", "1.0.0",
                      stderr: "error: only one requirement is allowed when specifiying a dependency\n")
        assertFailure(args: "add-dependency", "http://www.githost.com/repo.git", "--exact", "1.0.0", "--to", "2.0.0",
                      stderr: "error: '--to' and '--through' may only be used with '--from' to specify a range requirement\n")
        assertFailure(args: "add-dependency", "http://www.githost.com/repo.git", "--from", "1.0.0", "--to", "2.0.0", "--through", "3.0.0",
                      stderr: "error: '--to' and '--through' may not be used in the same requirement\n")
    }

    func testAddTargetArgValidation() throws {
        assertFailure(args: "add-target", "MyLibrary", "--type", "binary",
                      stderr: "error: binary targets must specify either a path or both a URL and a checksum\n")
        assertFailure(args: "add-target", "MyLibrary", "--checksum", "checksum",
                      stderr: "error: option '--checksum' is only supported for binary targets\n")
        assertFailure(args: "add-target", "MyLibrary", "--type", "binary", "--dependencies", "MyLibrary",
                      stderr: "error: option '--dependencies' is not supported for binary targets\n")
        assertFailure(args: "add-target", "MyLibrary", "--type", "unsupported",
                      stderr: "error: unsupported target type 'unsupported'; supported types are library, executable, test, and binary\n")
    }

    func testAddDependencyEndToEnd() throws {
        try withFixture(named: "Empty") { emptyPath in
            try withFixture(named: "OneProduct") { oneProductPath in
                try localFileSystem.changeCurrentWorkingDirectory(to: emptyPath)
                try SwiftPackageEditor.executable.execute(["add-dependency", oneProductPath.pathString])
                let newManifest = try localFileSystem.readFileContents(emptyPath.appending(component: "Package.swift")).validDescription
                XCTAssertEqual(newManifest, """
                // swift-tools-version:5.3
                import PackageDescription

                let package = Package(
                    name: "MyPackage",
                    dependencies: [
                        .package(name: "MyPackage2", path: "\(oneProductPath.pathString)"),
                    ]
                )
                """)
                assertFailure(args: "add-dependency", oneProductPath.pathString,
                              stderr: "error: 'MyPackage' already has a dependency on '\(oneProductPath.pathString)'\n")
            }
        }
    }

    func testAddTargetEndToEnd() throws {
        try withFixture(named: "Empty") { emptyPath in
            try withFixture(named: "OneProduct") { oneProductPath in
                try localFileSystem.changeCurrentWorkingDirectory(to: emptyPath)
                try SwiftPackageEditor.executable.execute(["add-dependency", oneProductPath.pathString])
                try SwiftPackageEditor.executable.execute(["add-target", "MyLibrary", "--dependencies", "Library"])
                try SwiftPackageEditor.executable.execute(["add-target", "MyExecutable", "--type", "executable",
                                                           "--dependencies", "MyLibrary"])
                try SwiftPackageEditor.executable.execute(["add-target", "--type", "test", "IntegrationTests",
                                                           "--dependencies", "MyLibrary"])
                let newManifest = try localFileSystem.readFileContents(emptyPath.appending(component: "Package.swift")).validDescription
                XCTAssertEqual(newManifest, """
                // swift-tools-version:5.3
                import PackageDescription

                let package = Package(
                    name: "MyPackage",
                    dependencies: [
                        .package(name: "MyPackage2", path: "\(oneProductPath.pathString)"),
                    ],
                    targets: [
                        .target(
                            name: "MyLibrary",
                            dependencies: [
                                .product(name: "Library", package: "MyPackage2"),
                            ]
                        ),
                        .testTarget(
                            name: "MyLibraryTests",
                            dependencies: [
                                "MyLibrary",
                            ]
                        ),
                        .target(
                            name: "MyExecutable",
                            dependencies: [
                                "MyLibrary",
                            ]
                        ),
                        .testTarget(
                            name: "IntegrationTests",
                            dependencies: [
                                "MyLibrary",
                            ]
                        ),
                    ]
                )
                """)
                XCTAssertTrue(localFileSystem.exists(emptyPath.appending(components: "Sources", "MyLibrary", "MyLibrary.swift")))
                XCTAssertTrue(localFileSystem.exists(emptyPath.appending(components: "Tests", "MyLibraryTests", "MyLibraryTests.swift")))
                XCTAssertTrue(localFileSystem.exists(emptyPath.appending(components: "Sources", "MyExecutable", "main.swift")))
                XCTAssertTrue(localFileSystem.exists(emptyPath.appending(components: "Tests", "IntegrationTests", "IntegrationTests.swift")))
                assertFailure(args: "add-target", "MyLibrary",
                              stderr: "error: a target named 'MyLibrary' already exists in 'MyPackage'\n")
            }
        }
    }

    func testAddProductEndToEnd() throws {
        try withFixture(named: "Empty") { emptyPath in
            try localFileSystem.changeCurrentWorkingDirectory(to: emptyPath)
            try SwiftPackageEditor.executable.execute(["add-target", "MyLibrary", "--no-test-target"])
            try SwiftPackageEditor.executable.execute(["add-target", "MyLibrary2", "--no-test-target"])
            try SwiftPackageEditor.executable.execute(["add-product", "LibraryProduct",
                                                       "--targets", "MyLibrary", "MyLibrary2"])
            try SwiftPackageEditor.executable.execute(["add-product", "DynamicLibraryProduct",
                                                       "--type", "dynamic-library",
                                                       "--targets", "MyLibrary"])
            try SwiftPackageEditor.executable.execute(["add-product", "StaticLibraryProduct",
                                                       "--type", "static-library",
                                                       "--targets", "MyLibrary"])
            try SwiftPackageEditor.executable.execute(["add-product", "ExecutableProduct",
                                                       "--type", "executable",
                                                       "--targets", "MyLibrary2"])
            let newManifest = try localFileSystem.readFileContents(emptyPath.appending(component: "Package.swift")).validDescription
            XCTAssertEqual(newManifest, """
            // swift-tools-version:5.3
            import PackageDescription

            let package = Package(
                name: "MyPackage",
                products: [
                    .library(
                        name: "LibraryProduct",
                        targets: [
                            "MyLibrary",
                            "MyLibrary2",
                        ]
                    ),
                    .library(
                        name: "DynamicLibraryProduct",
                        type: .dynamic,
                        targets: [
                            "MyLibrary",
                        ]
                    ),
                    .library(
                        name: "StaticLibraryProduct",
                        type: .static,
                        targets: [
                            "MyLibrary",
                        ]
                    ),
                    .executable(
                        name: "ExecutableProduct",
                        targets: [
                            "MyLibrary2",
                        ]
                    ),
                ],
                targets: [
                    .target(
                        name: "MyLibrary",
                        dependencies: []
                    ),
                    .target(
                        name: "MyLibrary2",
                        dependencies: []
                    ),
                ]
            )
            """)
            assertFailure(args: "add-product", "LibraryProduct", "--targets", "MyLibrary,MyLibrary2",
                          stderr: "error: a product named 'LibraryProduct' already exists in 'MyPackage'\n")
        }
    }
}
