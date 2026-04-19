import AVFoundation
import OSLog
import RA11yCore

/// Renders semantic feedback intents as lightweight generated iOS tones.
///
/// The renderer stays semantic: quests emit shared feedback intents, and this type maps them
/// to short synthesized cue patterns. No gameplay view needs to know about frequencies,
/// envelopes, or audio engine details.
@MainActor
protocol iOSAudioFeedbackRendering {
    /// Renders one semantic feedback cue.
    func render(intent: QuestFeedbackIntent, cue: QuestFeedbackCue)
}

/// Internal tone segment used to synthesize short cue patterns.
private struct ToneSegment {
    let primaryFrequency: Double
    let secondaryFrequency: Double?
    let duration: Double
    let amplitude: Float
    let trailingSilence: Double
}

/// Default iOS audio renderer for quest feedback.
@MainActor
final class iOSAudioFeedbackRenderer: iOSAudioFeedbackRendering {

    private let session: AVAudioSession
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var hasConfiguredSession = false
    private var hasPreparedEngine = false

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    func render(intent: QuestFeedbackIntent, cue: QuestFeedbackCue) {
        guard cue.audio != .none else { return }
        configureSessionIfNeeded()
        prepareEngineIfNeeded()

        guard engine.isRunning else {
            RA11yLogger.feedback.error("Audio cue dropped because engine is not running")
            return
        }

        let segments = cuePattern(for: intent, family: cue.audio)
        guard let buffer = makeBuffer(for: segments) else {
            RA11yLogger.feedback.error("Failed to synthesize audio cue for family \(cue.audio.rawValue)")
            return
        }

        if !player.isPlaying {
            player.play()
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        RA11yLogger.feedback.debug(
            "Audio cue rendered — intent: \(String(describing: intent)), family: \(cue.audio.rawValue)"
        )
    }

    private func configureSessionIfNeeded() {
        guard !hasConfiguredSession else { return }
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            hasConfiguredSession = true
        } catch {
            RA11yLogger.feedback.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func prepareEngineIfNeeded() {
        guard !hasPreparedEngine else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        guard let format else {
            RA11yLogger.feedback.error("Failed to create audio format for feedback renderer")
            return
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            hasPreparedEngine = true
        } catch {
            RA11yLogger.feedback.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    private func cuePattern(for intent: QuestFeedbackIntent, family: QuestFeedbackAudioFamily) -> [ToneSegment] {
        switch family {
        case .none:
            return []
        case .resonance:
            return resonancePattern(for: intent)
        case .mutedError:
            return [
                ToneSegment(primaryFrequency: 288, secondaryFrequency: 272, duration: 0.08, amplitude: 0.07, trailingSilence: 0.02),
                ToneSegment(primaryFrequency: 244, secondaryFrequency: 230, duration: 0.12, amplitude: 0.08, trailingSilence: 0.0),
            ]
        case .crystallineSuccess:
            return [
                ToneSegment(primaryFrequency: 660, secondaryFrequency: 990, duration: 0.08, amplitude: 0.08, trailingSilence: 0.025),
                ToneSegment(primaryFrequency: 880, secondaryFrequency: 1_320, duration: 0.1, amplitude: 0.1, trailingSilence: 0.025),
                ToneSegment(primaryFrequency: 1_176, secondaryFrequency: 1_760, duration: 0.16, amplitude: 0.12, trailingSilence: 0.0),
            ]
        case .warningPulse:
            return [
                ToneSegment(primaryFrequency: 372, secondaryFrequency: 366, duration: 0.12, amplitude: 0.08, trailingSilence: 0.02),
                ToneSegment(primaryFrequency: 332, secondaryFrequency: nil, duration: 0.1, amplitude: 0.06, trailingSilence: 0.0),
            ]
        case .hintChime:
            return [
                ToneSegment(primaryFrequency: 740, secondaryFrequency: 1_110, duration: 0.14, amplitude: 0.08, trailingSilence: 0.0),
            ]
        }
    }

    private func resonancePattern(for intent: QuestFeedbackIntent) -> [ToneSegment] {
        switch intent {
        case .proximityEntered(.warm):
            return [
                ToneSegment(primaryFrequency: 432, secondaryFrequency: 438, duration: 0.12, amplitude: 0.05, trailingSilence: 0.0),
            ]
        case .proximityEntered(.near):
            return [
                ToneSegment(primaryFrequency: 524, secondaryFrequency: 526, duration: 0.12, amplitude: 0.07, trailingSilence: 0.0),
            ]
        case .proximityEntered(.locked), .lockAcquired:
            return [
                ToneSegment(primaryFrequency: 660, secondaryFrequency: 990, duration: 0.18, amplitude: 0.1, trailingSilence: 0.0),
            ]
        case .lockLost:
            return [
                ToneSegment(primaryFrequency: 510, secondaryFrequency: 500, duration: 0.1, amplitude: 0.06, trailingSilence: 0.0),
            ]
        default:
            return [
                ToneSegment(primaryFrequency: 410, secondaryFrequency: 418, duration: 0.1, amplitude: 0.04, trailingSilence: 0.0),
            ]
        }
    }

    private func makeBuffer(for segments: [ToneSegment]) -> AVAudioPCMBuffer? {
        guard !segments.isEmpty else { return nil }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return nil
        }

        let totalFrameCount = segments.reduce(0) { partialResult, segment in
            let frames = Int((segment.duration + segment.trailingSilence) * sampleRate)
            return partialResult + max(frames, 1)
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(totalFrameCount)
        ) else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(totalFrameCount)
        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        var frameIndex = 0
        for segment in segments {
            let toneFrames = max(Int(segment.duration * sampleRate), 1)
            let silenceFrames = max(Int(segment.trailingSilence * sampleRate), 0)
            for localFrame in 0..<toneFrames {
                let progress = Double(localFrame) / sampleRate
                let attack = min(Float(localFrame) / Float(max(toneFrames / 8, 1)), 1)
                let release = min(Float(toneFrames - localFrame) / Float(max(toneFrames / 6, 1)), 1)
                let envelope = max(0, min(attack, release))
                let primary = sin(2 * Double.pi * segment.primaryFrequency * progress)
                let secondary = segment.secondaryFrequency.map {
                    sin(2 * Double.pi * $0 * progress)
                } ?? 0
                let mixed = (primary + (secondary * 0.45)) * Double(segment.amplitude * envelope)
                channelData[frameIndex] = Float(mixed)
                frameIndex += 1
            }

            if silenceFrames > 0 {
                for _ in 0..<silenceFrames {
                    channelData[frameIndex] = 0
                    frameIndex += 1
                }
            }
        }

        return buffer
    }
}
