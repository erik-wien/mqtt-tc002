import Foundation

/// Der Satz über dem Klangbestand einer Uhr: Zahl der Melodien und MP3-Dateien,
/// dazu die Belegung des Speichers, wo die Uhr sie nennt.
public enum Klangbelegung {
    /// "21 Melodien · 3 MP3 · 118 KB von 512 KB". Ohne beide Listen steht "—".
    /// Eine Uhr, die keine MP3 spielt, führt keine MP3-Zahl und liefert keine Belegung dafür.
    public static func zusammenfassung(melodien: Tonablage?, mp3: Tonablage?, mp3Spielbar: Bool) -> String {
        guard melodien != nil || mp3 != nil else { return "—" }
        var teile: [String] = []
        if let melodien { teile.append(lokf("%d Melodien", melodien.namen.count)) }
        if let mp3, mp3Spielbar { teile.append(lokf("%d MP3", mp3.namen.count)) }
        let quelle = [mp3Spielbar ? mp3 : nil, melodien].compactMap { $0 }.first { $0.belegteBytes != nil && $0.gesamteBytes != nil }
        if let belegt = quelle?.belegteBytes, let gesamt = quelle?.gesamteBytes {
            func menge(_ b: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .file) }
            teile.append(lokf("%@ von %@", menge(belegt), menge(gesamt)))
        }
        return teile.joined(separator: " · ")
    }
}
