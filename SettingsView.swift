import SwiftUI

// the pink of the logo
let brandPink = Color(red: 1.0, green: 0.30, blue: 0.56)

/* Everything on one page, in two columns, with no scrolling: the window takes the size of its content. */
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !model.permitted {
                permissionBanner
            }
            HStack(alignment: .top, spacing: 16) {
                scrollCard
                    .frame(width: columnWidth)
                VStack(spacing: 16) {
                    quitCard
                    generalCard
                }
                .frame(width: columnWidth)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 34) // room for the window buttons in the transparent title bar
        .padding(.bottom, 20)
        .fixedSize()
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(brandPink)
    }

    private let columnWidth: CGFloat = 340

    // MARK: Permission

    private var permissionBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            IconTile(symbol: "hand.raised.fill", color: .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Falta un permiso").font(.headline)
                Text("ScrollFlip necesita el permiso de Accesibilidad para funcionar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Abrir Ajustes") { model.openAccessibilitySettings() }
            Button("Dar permiso") { model.requestPermission() }
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(width: columnWidth * 2 + 16)
    }

    // MARK: Scrolling

    private var scrollCard: some View {
        Card(title: "Desplazamiento") {
            ToggleRow(symbol: "arrow.up.arrow.down", color: brandPink, title: "Cambiar el desplazamiento",
                      subtitle: "Hacia dónde se mueve la página en cada dispositivo",
                      isOn: $model.scrollEnabled)
            if model.scrollEnabled {
                Divider()
                DeviceRow(symbol: "rectangle.and.hand.point.up.left.filled", name: "Trackpad",
                          direction: $model.trackpadDirection, horizontal: $model.trackpadHorizontal)
                Divider()
                DeviceRow(symbol: "computermouse.fill", name: "Ratón",
                          direction: $model.mouseDirection, horizontal: $model.mouseHorizontal)
                Divider()
                Text("**Natural:** la página sigue a tus dedos, como en el iPhone. **Clásico:** como la rueda de un ratón de siempre.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Closing apps

    private var quitCard: some View {
        Card(title: "Cerrar apps") {
            ToggleRow(symbol: "xmark", color: .red, title: "Salir con el botón rojo",
                      subtitle: "Al cerrar la última ventana de una app, se cierra la app entera",
                      isOn: $model.quitEnabled)
            if model.quitEnabled {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Excepciones")
                        Text("Aquí el botón rojo solo cierra la ventana")
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
                            .frame(width: 20, height: 20)
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
                }
            }
        }
    }

    // MARK: General

    private var generalCard: some View {
        Card(title: "General") {
            ToggleRow(symbol: "power", color: .green, title: "Abrir al iniciar sesión", isOn: $model.startAtLogin)
            Divider()
            ToggleRow(symbol: "menubar.rectangle", color: .blue, title: "Icono en la barra de menús",
                      isOn: $model.showInMenuBar)
        }
    }
}

// MARK: Pieces

// a titled, rounded panel, like a section in System Settings
struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        }
    }
}

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

    // the switch always sits at the right edge, however short the title
    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

struct DeviceRow: View {
    let symbol: String
    let name: String
    @Binding var direction: ScrollDirection
    @Binding var horizontal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(name, systemImage: symbol)
            Picker(name, selection: $direction) {
                ForEach(ScrollDirection.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Toggle("Invertir también el horizontal", isOn: $horizontal)
                .toggleStyle(.checkbox)
                .font(.callout)
                .foregroundStyle(.secondary)
                .disabled(direction == .unchanged)
        }
    }
}
