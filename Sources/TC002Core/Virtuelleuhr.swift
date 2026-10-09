import Foundation

/// Die Form einer HTTP-Anfrage und -Antwort an die virtuelle Uhr — vom
/// Dienst (`Uhrenserver`) gebaut, von `VirtuelleNGUhr` beantwortet. Beide
/// Seiten reden ohne Steckdose miteinander, damit sich die Uhr ohne Netz
/// prüfen lässt.
public enum Virtuelleuhr {
    public struct Anfrage: Equatable, Sendable {
        public var methode: String
        public var pfad: String
        public var abfrage: [String: String]
        public var koerper: Data
        /// Kopfzeilen, Namen kleingeschrieben.
        public var kopf: [String: String]

        public init(_ methode: String = "GET", _ pfad: String,
                    abfrage: [String: String] = [:], koerper: Data = Data(),
                    kopf: [String: String] = [:]) {
            self.methode = methode
            self.pfad = pfad
            self.abfrage = abfrage
            self.koerper = koerper
            self.kopf = kopf
        }
    }

    public struct Antwort: Equatable, Sendable {
        public var status: Int
        public var koerper: Data
        public var inhaltstyp: String

        public init(status: Int = 200, koerper: Data,
                    inhaltstyp: String = "application/json") {
            self.status = status
            self.koerper = koerper
            self.inhaltstyp = inhaltstyp
        }
    }
}
