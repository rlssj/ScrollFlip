import AppKit

enum ScrollDirection: Int, CaseIterable {
    case natural, classic, unchanged

    var title: String {
        switch self {
        case .natural: "Natural"
        case .classic: "Clásico"
        case .unchanged: "Sin cambios"
        }
    }
}

/* An event tap that reverses scrolling, ported from Scroll Reverser's MouseTap.
 Continuous scrolling (trackpads, and the Magic Mouse) counts as trackpad, discrete scrolling (scroll wheels) as mouse.
 Scrolling posted by apps is left alone. */
final class ScrollReverser {
    fileprivate var tap: EventTap!

    // the settings, copied here so the callback doesn't read preferences for every event
    var trackpadDirection = ScrollDirection.natural
    var mouseDirection = ScrollDirection.classic
    var trackpadHorizontal = false
    var mouseHorizontal = true

    init() {
        tap = EventTap(events: [.scrollWheel], options: .defaultTap, callback: scrollCallback, userInfo: self)
    }

    // the tap is only installed while active, since an installed tap holds up every scroll event
    var active: Bool {
        get { tap.installed }
        set { tap.installed = newValue }
    }

    fileprivate func adjust(_ event: CGEvent) {
        guard event.getIntegerValueField(.eventSourceUnixProcessID) == 0 else { return }
        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let direction = continuous ? trackpadDirection : mouseDirection
        if direction == .unchanged { return }
        // has the system applied natural scrolling to this event?
        let natural = NSEvent(cgEvent: event)?.isDirectionInvertedFromDevice ?? false
        guard natural != (direction == .natural) else { return }

        reverseAxis(event, delta: .scrollWheelEventDeltaAxis1, fixedPt: .scrollWheelEventFixedPtDeltaAxis1, point: .scrollWheelEventPointDeltaAxis1)
        // horizontal follows vertical when chosen (shift+scroll with a wheel arrives here already horizontal)
        if continuous ? trackpadHorizontal : mouseHorizontal {
            reverseAxis(event, delta: .scrollWheelEventDeltaAxis2, fixedPt: .scrollWheelEventFixedPtDeltaAxis2, point: .scrollWheelEventPointDeltaAxis2)
        }
    }

    /* We have to set the point values second, or we lose smooth scrolling: setting DeltaAxis makes macOS
     internally modify PointDeltaAxis (8x multiplier on DeltaAxis value) and FixedPtDeltaAxis (1x multiplier). */
    private func reverseAxis(_ event: CGEvent, delta: CGEventField, fixedPt: CGEventField, point: CGEventField) {
        let fixedPtValue = event.getDoubleValueField(fixedPt)
        let pointValue = event.getIntegerValueField(point)
        event.setIntegerValueField(delta, value: -event.getIntegerValueField(delta))
        event.setDoubleValueField(fixedPt, value: -fixedPtValue)
        event.setIntegerValueField(point, value: -pointValue)
    }
}

private let scrollCallback: CGEventTapCallBack = { _, type, event, userInfo in
    let reverser = Unmanaged<ScrollReverser>.fromOpaque(userInfo!).takeUnretainedValue()
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        reverser.tap.reenable()
    case .scrollWheel:
        reverser.adjust(event)
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}
