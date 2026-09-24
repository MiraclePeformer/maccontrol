import Cocoa

/// Keeps the Mac awake by nudging the cursor a few pixels each tick.
final class Jiggler {
    private var timer: Timer?
    private(set) var isRunning = false
    var interval: TimeInterval = 30
    private var direction: CGFloat = 1

    func start() {
        stop()
        isRunning = true
        jiggle() // fire once immediately so it's visibly working
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.jiggle()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func jiggle() {
        guard let here = CGEvent(source: nil)?.location else { return }
        // Move a few pixels, alternating direction each tick, so it drifts back.
        let target = CGPoint(x: here.x + direction * 4, y: here.y)
        post(to: target)
        direction = -direction
    }

    private func post(to point: CGPoint) {
        CGEvent(mouseEventSource: nil,
                mouseType: .mouseMoved,
                mouseCursorPosition: point,
                mouseButton: .left)?.post(tap: .cghidEventTap)
    }
}
