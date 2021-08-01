// swift-tools-version:5.5

/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageDescription
import Foundation

let package = Package(
    name: "swift-package-editor",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .executable(
            name: "swift-package-editor",
            targets: ["swift-package-editor"])
    ],
    targets: [
        .executableTarget(name: "swift-package-editor", dependencies: [
            "PackageSyntax",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
            .product(name: "SwiftPM-auto", package: "swift-package-manager"),
        ]),
        .target(name: "PackageSyntax", dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
            .product(name: "SwiftPM-auto", package: "swift-package-manager")
        ]),
        .testTarget(name: "PackageSyntaxTests", dependencies: [
            "PackageSyntax",
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
            .product(name: "SwiftPM-auto", package: "swift-package-manager"),
            .product(name: "PackageDescription", package: "swift-package-manager")
        ])
    ]
)

let relatedDependenciesBranch = "main"

if ProcessInfo.processInfo.environment["SWIFTCI_USE_LOCAL_DEPS"] == nil {
    package.dependencies += [
        .package(url: "https://github.com/apple/swift-tools-support-core.git", .branch(relatedDependenciesBranch)),
        // The 'swift-argument-parser' version declared here must match that
        // used by 'swift-driver', 'sourcekit-lsp', and 'swiftpm'. Please coordinate
        // dependency version changes here with those projects.
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "0.4.3")),
        .package(url: "https://github.com/apple/swift-package-manager.git", .branch(relatedDependenciesBranch)),
        .package(url: "https://github.com/apple/swift-syntax.git", .branch(relatedDependenciesBranch))
    ]
} else {
    package.dependencies += [
        .package(path: "../swift-tools-support-core"),
        .package(path: "../swift-argument-parser"),
        .package(name: "swift-package-manager", path: "../swiftpm"),
        .package(path: "../swift-syntax")
    ]
}
