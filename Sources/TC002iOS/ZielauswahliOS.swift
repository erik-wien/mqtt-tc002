import SwiftUI
import TC002Core
import TC002Modell

/// An welche Uhren gesendet wird. Erscheint nur, wenn es mehr als eine gibt.
struct ZielauswahliOS: View {
    @Bindable var zustand: AppZustand
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List {
                ForEach(zustand.uhren) { uhr in
                    Button {
                        if zustand.zielIDs.contains(uhr.id) {
                            zustand.zielIDs.remove(uhr.id)
                        } else {
                            zustand.zielIDs.insert(uhr.id)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(uhr.name)
                                Text(uhr.host).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if zustand.zielIDs.contains(uhr.id) {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .tint(.primary)
                }
            }
            .navigationTitle("Ziel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            } }
            .onAppear {
                // Konkretisieren: Sonst zeigte das Blatt bei leerer Auswahl
                // keine Uhr angehakt, obwohl eben noch die aktive als Ziel galt.
                if zustand.zielIDs.isEmpty { zustand.zielIDs = Set(zustand.ziele().map(\.id)) }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
