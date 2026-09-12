// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TC002",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        // Der Name des Produkts ist der Name der Datei — so heisst das Werkzeug
        // auf der Kommandozeile `mqtttc002` und nicht `TC002CLI`.
        .executable(name: "mqtttc002", targets: ["TC002CLI"]),
        // Fuer das iOS-Projekt, das dieses Paket ueber xcodegen einbindet.
        .library(name: "TC002Core", targets: ["TC002Core"]),
        .library(name: "TC002Modell", targets: ["TC002Modell"]),
        // Plattformfreie SwiftUI-Ansichten, die sich alle Oberflaechen teilen
        // (Mac, iPhone, kuenftig iPad) — angefangen beim Geraeterahmen.
        .library(name: "TC002Ansichten", targets: ["TC002Ansichten"]),
    ],
    targets: [
        .target(name: "TC002Core", swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "TC002Modell", dependencies: ["TC002Core"],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "TC002Ansichten", dependencies: ["TC002Core"],
                resources: [.process("Resources")],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "TC002App", dependencies: ["TC002Core", "TC002Modell", "TC002Ansichten"],
                          swiftSettings: [.swiftLanguageMode(.v5)]),
        // Das Kommandozeilenwerkzeug. Liest die Einrichtung der App und schickt
        // damit Meldungen — eigenes Ziel, damit die Oberflaeche nicht mitkommt.
        .executableTarget(name: "TC002CLI", dependencies: ["TC002Core"],
                          swiftSettings: [.swiftLanguageMode(.v5)]),
        // Die Schnappschuesse des Rahmenbaus sind keine Buendelressourcen: Die
        // Tests lesen sie ueber `#filePath` aus dem Quellbaum. Ohne diesen
        // Ausschluss warnt SwiftPM bei jedem Bau ueber unbehandelte Dateien.
        .testTarget(name: "TC002CoreTests", dependencies: ["TC002Core"],
                    exclude: ["Schnappschuesse"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TC002ModellTests", dependencies: ["TC002Modell"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TC002AppTests", dependencies: ["TC002App"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TC002CLITests", dependencies: ["TC002CLI"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
