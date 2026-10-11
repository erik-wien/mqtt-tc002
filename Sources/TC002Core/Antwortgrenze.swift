import Foundation

/// Wie groß eine Antwort der Uhr höchstens sein darf, je Art. Die App lädt nie
/// mehr als das in den Speicher: `Content-Length` über der Grenze bricht vor dem
/// ersten Byte ab, ein Rumpf ohne Längenangabe (chunked) beim Überschreiten.
/// Überall sonst wird nichts aus dem Netz geladen — Icons, LaMetric-Bestände und
/// Melodiedateien kommen aus dem Bündel oder von der Platte.
public enum Antwortgrenze {
    /// Zustand, Einstellungen, Fähigkeiten, App- und Klanglisten: Text im
    /// KiB-Bereich; 1 MiB lässt einer langen Liste von Dateinamen Raum.
    public static let standard = 1 << 20
    /// Das Abbild des Displays (`display/screen`): bei 52 × 16 Punkten rund
    /// 8 KiB JSON; 128 KiB ist das Mehr als Zehnfache.
    public static let bildschirm = 128 << 10
}

/// Sammelt eine Antwort ein und bricht ab, sobald sie die Grenze überschreitet.
final class Antwortbegrenzer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    /// Der Fehler, mit dem die Sammlung endet, wenn die Grenze riss.
    struct ZuGross: Error {}

    private let grenze: Int
    private let fach: Rueckruffach<(Data?, URLResponse?, Error?)>
    private var daten = Data()
    private var antwort: URLResponse?
    private var zuGross = false

    init(grenze: Int, fach: Rueckruffach<(Data?, URLResponse?, Error?)>) {
        self.grenze = grenze
        self.fach = fach
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        antwort = response
        if response.expectedContentLength > Int64(grenze) {
            zuGross = true
            completionHandler(.cancel)
        } else {
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !zuGross else { return }
        daten.append(data)
        if daten.count > grenze {
            zuGross = true
            daten = Data()
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if zuGross {
            fach.abgeben((nil, antwort, ZuGross()))
        } else {
            fach.abgeben((daten, antwort ?? task.response, error))
        }
    }
}
