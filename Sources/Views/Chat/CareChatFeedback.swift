import AVFoundation
import Foundation


final class CareChatFeedback {
    static let shared = CareChatFeedback()

    enum Tone: Hashable {
        case send
        case receive
        case error
    }

    private let engine = AVAudioEngine()
    private let players = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
    private var buffers: [Tone: AVAudioPCMBuffer] = [:]
    private var nextPlayerIndex = 0
    private var configured = false

    private init() {
        for player in players {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        buffers[.send] = makeBuffer(.send)
        buffers[.receive] = makeBuffer(.receive)
        buffers[.error] = makeBuffer(.error)
    }

    func prepare() {
        configureIfNeeded()
    }

    func play(_ tone: Tone) {
        configureIfNeeded()
        guard let buffer = buffers[tone] else { return }

        if !engine.isRunning {
            try? engine.start()
        }

        let player = players[nextPlayerIndex]
        nextPlayerIndex = (nextPlayerIndex + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true

        let session = AVAudioSession.sharedInstance()
        // Ambient keeps the sound respectful of the silent switch and does not steal
        // playback from the user's Qur'an, music or navigation audio.
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])

        engine.prepare()
        try? engine.start()
    }

    private func makeBuffer(_ tone: Tone) -> AVAudioPCMBuffer? {
        let duration: Double
        switch tone {
        case .send: duration = 0.115
        case .receive: duration = 0.185
        case .error: duration = 0.175
        }

        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = frameCount

        var p1 = 0.0
        var p2 = 0.0
        var p3 = 0.0

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let x = min(1.0, max(0.0, t / duration))

            let left: Double
            let right: Double

            switch tone {
            case .send:
                // A tiny ascending, airy glass transient: recognizable but deliberately
                // not a copy of Apple's Messages asset.
                let attack = min(1.0, x / 0.020)
                let release = pow(max(0, 1 - x), 3.8)
                let envelope = attack * release
                let f1 = 880 + 520 * x
                let f2 = 1_420 + 390 * x
                p1 += 2 * .pi * f1 / sampleRate
                p2 += 2 * .pi * f2 / sampleRate
                let shimmer = sin(2 * .pi * 3_250 * t) * exp(-t * 48)
                let core = sin(p1) * 0.70 + sin(p2) * 0.20 + shimmer * 0.10
                left = core * envelope * 0.155
                right = core * envelope * 0.160

            case .receive:
                // Two very soft resonances make the incoming tone read as warmer and
                // more dimensional than a single synthetic beep.
                let attack = min(1.0, x / 0.025)
                let release = pow(max(0, 1 - x), 2.45)
                let envelope = attack * release
                let f1 = 980 - 135 * x
                let f2 = 1_480 - 155 * x
                let f3 = 2_020 - 190 * x
                p1 += 2 * .pi * f1 / sampleRate
                p2 += 2 * .pi * f2 / sampleRate
                p3 += 2 * .pi * f3 / sampleRate
                let body = sin(p1) * 0.58 + sin(p2) * 0.24 + sin(p3) * 0.09
                let secondPing = sin(2 * .pi * 1_090 * max(0, t - 0.072))
                    * exp(-max(0, t - 0.072) * 28)
                    * (t >= 0.072 ? 1 : 0)
                let core = body + secondPing * 0.10
                left = core * envelope * 0.125
                right = core * envelope * 0.132

            case .error:
                let attack = min(1.0, x / 0.05)
                let release = pow(max(0, 1 - x), 2.8)
                let envelope = attack * release
                let f1 = 290 - 42 * x
                let f2 = 435 - 58 * x
                p1 += 2 * .pi * f1 / sampleRate
                p2 += 2 * .pi * f2 / sampleRate
                let core = sin(p1) * 0.70 + sin(p2) * 0.18
                left = core * envelope * 0.105
                right = core * envelope * 0.105
            }

            channels[0][frame] = Float(max(-1, min(1, left)))
            channels[1][frame] = Float(max(-1, min(1, right)))
        }

        return buffer
    }
}
