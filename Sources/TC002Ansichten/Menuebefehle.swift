import SwiftUI

/// Was die Mac-Menüleiste vom Editor braucht: Rückgängig, Wiederherstellen und
/// Sichern. Der Editor meldet es über `focusedSceneValue`; ohne offenen Editor
/// ist der Wert `nil`, und die Menüeinträge sind ausgegraut.
///
/// Die Befehle selbst stehen in `TC002App/App.swift`. Die Typen liegen hier, weil
/// `EditorBereichView` und `SendenView` sie setzen und die Mac-App sie nur liest.
public struct EditorAktionen {
    public let kannZurueck: Bool
    public let kannVor: Bool
    public let zurueck: () -> Void
    public let vor: () -> Void
    /// `nil` in der Übersicht: Dort liegt nichts auf der Leinwand.
    public let sichern: (() -> Void)?

    public init(kannZurueck: Bool, kannVor: Bool,
                zurueck: @escaping () -> Void, vor: @escaping () -> Void,
                sichern: (() -> Void)?) {
        self.kannZurueck = kannZurueck
        self.kannVor = kannVor
        self.zurueck = zurueck
        self.vor = vor
        self.sichern = sichern
    }
}

/// Die Sendung des Bereichs „Senden" für den Menübefehl. `nil` heißt: es gibt
/// nichts zu senden (leerer Text, keine Zieluhr, läuft schon).
public struct SendeAktion {
    public let senden: (() -> Void)?

    public init(senden: (() -> Void)?) { self.senden = senden }
}

private struct EditorAktionenSchluessel: FocusedValueKey { typealias Value = EditorAktionen }
private struct SendeAktionSchluessel: FocusedValueKey { typealias Value = SendeAktion }

public extension FocusedValues {
    var editorAktionen: EditorAktionen? {
        get { self[EditorAktionenSchluessel.self] }
        set { self[EditorAktionenSchluessel.self] = newValue }
    }

    var sendeAktion: SendeAktion? {
        get { self[SendeAktionSchluessel.self] }
        set { self[SendeAktionSchluessel.self] = newValue }
    }
}
