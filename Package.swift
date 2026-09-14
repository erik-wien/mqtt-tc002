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
        // **Ohne Ressourcen.** Bis zum 14.09.2026 lag hier ein Bildkatalog mit
        // einer einzigen SVG — der Geraetefront der TC002. Sie wird seit
        // `97f22ea` gezeichnet statt eingesetzt, und mit ihr ist die ganze
        // Kette gefallen: `Bilder.swift` (das Ressourcenbuendel suchen), der
        // `actool`-Schritt in `build.sh`, die Info.plist-Nachreichung und die
        // Assets.car-Pflicht in `scripts/buendel-pruefen.sh`. Rund sechzig
        // Zeilen Baumaschinerie fuer ein Bild, das niemand mehr laedt.
        .target(name: "TC002Ansichten", dependencies: ["TC002Core", "TC002Modell"],
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
        .testTarget(name: "TC002AnsichtenTests", dependencies: ["TC002Ansichten"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TC002AppTests", dependencies: ["TC002App"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TC002CLITests", dependencies: ["TC002CLI"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
