import AVFoundation
import Combine
import Speech
import SwiftUI

/// Owns the SFSpeechRecognizer + AVSpeechSynthesizer for hands-free
/// control of the refraction flow.
///
/// Phase views call `say(_:thenListenFor:onMatch:)` (or
/// `startListening(...)` directly) when they appear, and `cancel()`
/// when they leave. Matched keywords are routed to the existing
/// view-model action methods, so nothing in the VMs changes.
///
/// Recognition runs on-device (no network). Permissions are *desired*,
/// not required — when denied, every screen still works via taps.
@MainActor
final class VoiceCoordinator: NSObject, ObservableObject {

    // MARK: - Published State

    @Published private(set) var isListening: Bool = false
    @Published private(set) var isSpeaking: Bool = false
    /// True when both speech-recognition and microphone permissions
    /// have been granted by the user. Voice features no-op when false.
    @Published private(set) var isAuthorized: Bool = false

    // MARK: - Private

    private var synthesizer = AVSpeechSynthesizer()
    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var vocabulary: [String] = []
    private var matchHandler: ((String) -> Void)?
    private var lastMatchTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.8

    /// Listener config queued while the synthesizer is still speaking;
    /// promoted to a real recognition session in `didFinish`.
    private var pendingListen: (vocabulary: [String], onMatch: (String) -> Void)?

    /// Utterance queued behind a `stopSpeaking(.immediate)` call;
    /// delivered from `didCancel` once iOS has fully released the
    /// previous utterance's audio resources. Speaking immediately
    /// after a cancel makes the new utterance barely audible — the
    /// synth's gain hasn't ramped back up — so we wait for the
    /// cancellation callback before issuing the next `speak()`.
    private var pendingUtterance: AVSpeechUtterance?

    /// Per-utterance completions, keyed by the utterance identity.
    /// Required because callers can queue a second `say()` while the
    /// first is mid-stream — a single shared slot would let the later
    /// utterance's `onFinish` get popped at the earlier utterance's end.
    private var completions: [ObjectIdentifier: () -> Void] = [:]
    private var starts: [ObjectIdentifier: () -> Void] = [:]

    /// Track the audio-session category we last configured so back-to-back
    /// say() calls don't re-activate the same category — re-activation can
    /// briefly cut the audio route and clip the start of the next utterance.
    private var activeSessionCategory: AVAudioSession.Category?

    override init() {
        // Locale-flexible: prefer the user's locale, fall back to en-US.
        self.recognizer = SFSpeechRecognizer(locale: Locale.current)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Permissions

    func requestAuthorization() async {
        let speech = await requestSpeechPermission()
        let mic = await requestMicPermission()
        isAuthorized = speech && mic
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Speech synthesis

    /// Speak `text`, optionally then start a listening session for
    /// `vocabulary`. This is the primary entry point per phase: the
    /// spoken instruction plays, and listening kicks in only after the
    /// synthesizer finishes (so the mic doesn't pick up our own voice).
    func say(_ text: String,
             rate: Float = 0.5,
             postDelay: TimeInterval = 0,
             thenListenFor vocabulary: [String] = [],
             onMatch: ((String) -> Void)? = nil,
             onStart: (() -> Void)? = nil,
             onFinish: (() -> Void)? = nil) {
        if isListening {
            stopListening()
        }
        if !vocabulary.isEmpty, let onMatch {
            pendingListen = (vocabulary, onMatch)
        } else {
            pendingListen = nil
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.volume = 1.0
        utterance.voice = preferredVoice
        utterance.postUtteranceDelay = postDelay
        let id = ObjectIdentifier(utterance)
        if let onFinish {
            completions[id] = onFinish
        }
        if let onStart {
            starts[id] = onStart
        }

        // The new utterance is destined to play — keep isSpeaking
        // true synchronously so startListening() doesn't race in
        // between and grab the mic ahead of us.
        isSpeaking = true

        if synthesizer.isSpeaking {
            // Defer until didCancel fires for the in-flight
            // utterance. iOS lowers the synth's audio gain on
            // stop and needs the cancellation to complete before
            // the next speak() will come out at full volume.
            pendingUtterance = utterance
            synthesizer.stopSpeaking(at: .immediate)
            // Watchdog: AVSpeechSynthesizer occasionally reports
            // isSpeaking == true for an utterance that's already
            // settled internally, in which case stopSpeaking does
            // not fire didCancel/didFinish and the pending
            // utterance would be stranded. If no callback has
            // consumed it after a short window, kick it ourselves.
            let pending = utterance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self, self.pendingUtterance === pending else { return }
                self.pendingUtterance = nil
                // When stopSpeaking() yields no delegate callback,
                // the synth has reported isSpeaking=true for something
                // it's no longer tracking — internal state is wedged
                // and further speak() calls produce no audio. Swap
                // in a fresh synthesizer to break out of it.
                self.recreateSynthesizer()
                self.deliverPending(pending)
            }
        } else {
            pendingUtterance = nil
            // Activate a playback-capable category so the synth
            // ignores the device's silent switch — guidance prompts
            // must be audible even when notifications are muted.
            configureSessionForPlayback()
            synthesizer.speak(utterance)
        }
    }

    /// System-default voice for the user's preferred speech-synth
    /// language (e.g. "en-AU"). Falls back to the en-US default. Using
    /// `currentLanguageCode()` returns a BCP-47 tag the synth maps to
    /// the OS's chosen voice — the same one Siri / Speak Selection use.
    private var preferredVoice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// Speak a queued utterance from outside the synthesizer's
    /// delegate task. Re-entering the synth from inside its own
    /// didCancel/didFinish task leaves the synth in a half-settled
    /// state — the queued utterance plays, but the *next* speak()
    /// after that one often comes out silent. Hopping out via a
    /// fresh MainActor task gives iOS a chance to settle first.
    private func recreateSynthesizer() {
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
    }

    private func deliverPending(_ utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.configureSessionForPlayback()
            self.synthesizer.speak(utterance)
        }
    }

    private func configureSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Always deactivate before re-asserting. iOS otherwise
            // leaves the playback route in a half-released state
            // after the previous utterance finishes — the session
            // reports active but the next speak() comes out silent.
            // Bouncing the session forces a fresh route assertion.
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            activeSessionCategory = .playback
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Best-effort: if session config fails the synthesizer falls
            // back to its default behaviour (which respects the mute
            // switch, so prompts may be inaudible — but the visual cues
            // and buttons keep the test usable).
        }
    }

    // MARK: - Recognition

    func startListening(vocabulary: [String], onMatch: @escaping (String) -> Void) {
        guard isAuthorized,
              let recognizer,
              recognizer.isAvailable,
              !vocabulary.isEmpty else { return }

        if isSpeaking {
            pendingListen = (vocabulary, onMatch)
            return
        }

        stopListening()

        self.vocabulary = vocabulary.map { $0.lowercased() }
        self.matchHandler = onMatch

        do {
            let session = AVAudioSession.sharedInstance()
            if activeSessionCategory != .playAndRecord {
                try session.setCategory(.playAndRecord,
                                        mode: .measurement,
                                        options: [.duckOthers, .defaultToSpeaker])
                activeSessionCategory = .playAndRecord
            }
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Let the system pick the more accurate engine (cloud when
        // available, on-device otherwise). Forcing on-device degraded
        // recognition reliability after several phase cycles in
        // testing — the keyword vocabulary is short enough that cloud
        // round-trip latency is acceptable.
        // Bias the language model toward the expected keywords —
        // single-word commands like "clear" are otherwise easy to
        // mis-decode as "here" / "near" / "queer".
        request.contextualStrings = self.vocabulary
        request.taskHint = .confirmation
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            recognitionRequest = nil
            return
        }

        isListening = true
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let fullText = result.bestTranscription.formattedString.lowercased()
                Task { @MainActor in
                    self.handlePartial(text: fullText)
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopListening()
                }
            }
        }
    }

    /// Tear down the active recognition session. Does *not* touch the
    /// synthesizer or the queued `pendingListen` — in iOS 17 a new
    /// view's `.onAppear` can fire before the old view's `.onDisappear`,
    /// so the new phase may have already queued its own listener by
    /// the time we run; clearing pendingListen here would erase it.
    /// `say()` and `interrupt()` clear pendingListen explicitly when
    /// they need to.
    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        vocabulary = []
        matchHandler = nil
        isListening = false
    }

    /// Cancel any in-flight utterance without touching recognition
    /// or queued listeners. Use from a view's onAppear when it has
    /// no spoken prompt of its own but the previous phase may have
    /// left speech running.
    func cancelSpeech() {
        pendingUtterance = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        pendingListen = nil
    }

    /// Hard-stop everything: listening, queued listener, in-flight
    /// speech, and any pending completions. Reserve for explicit user
    /// abort (e.g. cancelling the test mid-flow).
    func interrupt() {
        completions.removeAll()
        starts.removeAll()
        pendingUtterance = nil
        stopListening()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        pendingListen = nil
    }

    // MARK: - Matching

    private func handlePartial(text: String) {
        let now = Date()
        guard now.timeIntervalSince(lastMatchTime) >= debounceInterval else { return }

        // Tokenise on non-letter/digit boundaries so a short keyword like
        // "ok" doesn't false-match inside "look" / "took". Multi-word
        // keywords (rare) still fall back to substring matching.
        let tokens = Set(text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                             .map { String($0).lowercased() })

        for keyword in vocabulary {
            let matched = keyword.contains(" ")
                ? text.contains(keyword)
                : tokens.contains(keyword)
            if matched {
                lastMatchTime = now
                matchHandler?(keyword)
                return
            }
        }
    }
}

// MARK: - SwiftUI ergonomics

/// Apply to any phase view: speaks `prompt` (if provided) when the
/// view appears, then listens for `vocabulary`. Cancels everything in
/// `onDisappear`. No-ops silently when voice isn't authorized.
struct VoiceInputModifier: ViewModifier {
    let voice: VoiceCoordinator
    let prompt: String?
    let vocabulary: [String]
    let onMatch: (String) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                if let prompt {
                    voice.say(prompt, thenListenFor: vocabulary, onMatch: onMatch)
                } else {
                    voice.startListening(vocabulary: vocabulary, onMatch: onMatch)
                }
            }
            .onDisappear {
                voice.stopListening()
            }
    }
}

extension View {
    func voiceInput(_ voice: VoiceCoordinator,
                    prompt: String? = nil,
                    vocabulary: [String],
                    onMatch: @escaping (String) -> Void) -> some View {
        modifier(VoiceInputModifier(voice: voice, prompt: prompt, vocabulary: vocabulary, onMatch: onMatch))
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceCoordinator: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didStart utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in
            // Defer onStart for the same reason as onFinish — if a
            // future onStart calls voice.say() we must not re-enter
            // the synth from inside its delegate callback.
            if let onStart = self.starts.removeValue(forKey: key) {
                Task { @MainActor in onStart() }
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in
            let completion = self.completions.removeValue(forKey: key)
            // A stopSpeaking() during postUtteranceDelay fires didFinish
            // rather than didCancel, so consume any pending utterance
            // from here too — otherwise the queued speech is stranded.
            if let next = self.pendingUtterance {
                self.pendingUtterance = nil
                self.isSpeaking = true
                self.deliverPending(next)
            } else {
                // synthesizer.isSpeaking remains true while a queued
                // next utterance is still pending; only flip our flag
                // once the queue has actually drained, otherwise
                // startListening would race the next utterance.
                self.isSpeaking = self.synthesizer.isSpeaking
                if !self.isSpeaking, let pending = self.pendingListen {
                    self.pendingListen = nil
                    self.startListening(vocabulary: pending.vocabulary, onMatch: pending.onMatch)
                }
            }
            // Defer the user's completion to the next runloop tick.
            // If it triggers another voice.say() (e.g. a view
            // transition whose onAppear speaks), we must not re-enter
            // the synthesizer from inside its own delegate callback —
            // doing so leaves the next utterance silent.
            if let completion {
                Task { @MainActor in completion() }
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.completions.removeValue(forKey: key)
            self.starts.removeValue(forKey: key)
            // Don't touch pendingListen here — when a fresh say()/
            // startListening() triggered this cancel, it has already
            // installed the latest pendingListen synchronously and
            // this async callback must not clobber it.
            if let next = self.pendingUtterance {
                self.pendingUtterance = nil
                self.isSpeaking = true
                self.deliverPending(next)
            } else {
                self.isSpeaking = self.synthesizer.isSpeaking
            }
        }
    }
}
