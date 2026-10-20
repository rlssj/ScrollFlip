import SwiftUI

// the pink of the logo
let brandPink = Color(red: 1.0, green: 0.30, blue: 0.56)

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Form {
                if !model.permitted {
                    permissionSection
                }
                scrollSection
                quitSection
                generalSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(.background)
        .tint(brandPink)
        .frame(width: 480, height: 730)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            // the Icon Composer icon, which follows light and dark mode
            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text("ScrollFlip")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Tu desplazamiento, a tu manera")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 4)
    }

    // MARK: Sections

    private var permissionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    IconTile(symbol: "hand.raised.fill", color: .orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Falta un permiso").font(.headline)
                        Text("Para cambiar el desplazamiento y detectar el botón rojo, ScrollFlip necesita el permiso de Accesibilidad. Actívalo en la lista que se abrirá.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack {
                    Spacer()
                    Button("Abrir Ajustes del Sistema") { model.openAccessibilitySettings() }
                    Button("Dar permiso") { model.requestPermission() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var scrollSection: some View {
        Section {
            ToggleRow(symbol: "arrow.up.arrow.down", color: brandPink, title: "Cambiar el desplazamiento",
                      subtitle: "Elige hacia dónde se mueve la página en cada dispositivo",
                      isOn: $model.scrollEnabled)
            if model.scrollEnabled {
                DeviceRow(symbol: "rectangle.and.hand.point.up.left.filled", name: "Trackpad",
                          direction: $model.trackpadDirection, horizontal: $model.trackpadHorizontal)
                DeviceRow(symbol: "computermouse.fill", name: "Ratón",
                          direction: $model.mouseDirection, horizontal: $model.mouseHorizontal)
            }
        } header: {
            Text("Desplazamiento")
        } footer: {
            if model.scrollEnabled {
                Text("**Natural:** la página sigue a tus dedos, como en el iPhone. **Clásico:** como la rueda de un ratón de siempre.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quitSection: some View {
        Section {
            ToggleRow(symbol: "xmark", color: .red, title: "Salir con el botón rojo",
                      subtitle: "Al cerrar la última ventana de una app, se cierra la app entera",
                      isOn: $model.quitEnabled)
            if model.quitEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Excepciones")
                            Text("En estas apps el botón rojo solo cierra la ventana")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            model.addQuitException()
                        } label: {
                            Label("Añadir", systemImage: "plus")
                        }
                    }
                    ForEach(model.quitExceptions, id: \.self) { bundleID in
                        HStack(spacing: 10) {
                            Image(nsImage: model.appIcon(bundleID))
                                .resizable()
                                .frame(width: 22, height: 22)
                            Text(model.appName(bundleID))
                            Spacer()
                            Button {
                                model.quitExceptions.removeAll { $0 == bundleID }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Quitar")
                        }
                        .padding(.leading, 4)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Cerrar apps")
        } footer: {
            Text("Si la app tiene más ventanas abiertas, solo se cierra esa. Si hay algo sin guardar, te preguntará antes. El Finder nunca se cierra.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var generalSection: some View {
        Section("General") {
            ToggleRow(symbol: "power", color: .green, title: "Abrir al iniciar sesión", isOn: $model.startAtLogin)
            ToggleRow(symbol: "menubar.rectangle", color: .blue, title: "Icono en la barra de menús",
                      subtitle: "Sin icono, abre ScrollFlip otra vez para ver esta ventana",
                      isOn: $model.showInMenuBar)
        }
    }
}

// MARK: Pieces

// a coloured rounded square with a white symbol, like in System Settings
struct IconTile: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct ToggleRow: View {
    let symbol: String
    let color: Color
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                IconTile(symbol: symbol, color: color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toggleStyle(.switch)
    }
}

struct DeviceRow: View {
    let symbol: String
    let name: String
    @Binding var direction: ScrollDirection
    @Binding var horizontal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(name, systemImage: symbol)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.primary)
                Spacer()
                Picker(name, selection: $direction) {
                    ForEach(ScrollDirection.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            Toggle("Invertir también el horizontal", isOn: $horizontal)
                .toggleStyle(.checkbox)
                .font(.callout)
                .foregroundStyle(.secondary)
                .disabled(direction == .unchanged)
                .padding(.leading, 28)
        }
        .padding(.vertical, 2)
    }
}
