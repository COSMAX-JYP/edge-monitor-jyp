import SwiftUI
import AVFoundation
import DomainModels
import LibraryStore
import RecordingEngine
import Transcriber
import Diarizer
import Summarizer
import Pipeline
import PrivacyController
import UI
import RecordingCoordinator

@Observable
final class MeetingRecorderHost {
    let store: any LibraryStore
    let paths: PathProvider
    let pipeline: MeetingPipeline
    let modelManager: ModelManager
    let audio: AudioSessionManager
    let coordinator: RecordingCoordinator
    var lastError: String?

    // 자동 중지 모니터
    private var sleepObserver: NSObjectProtocol?
    private var silenceMonitorTask: Task<Void, Never>?
    private static let silenceTimeoutSeconds: Double = 30
    private static let silenceThresholdDb: Float = -45

    // 자동 다운로드 진행 상황 (UI 노출용)
    var modelDownloadProgress: Double? = nil   // nil = idle/완료, 0~1 = 진행 중
    var modelDownloadDone: Bool = false         // 다운로드 완료(또는 이미 캐시 있음)
    var modelDownloadError: String? = nil       // 실패 시 메시지
    var modelDownloadInFlight: Bool = false     // 중복 시작 방지

    static let defaultWhisperModel = "openai_whisper-large-v3-v20240930_turbo"

    init() {
        let paths = PathProvider()
        let store: any LibraryStore
        do { store = try GRDBLibraryStore(paths: paths) }
        catch { fatalError("LibraryStore 초기화 실패: \(error)") }
        self.store = store
        self.paths = paths

        let mm = ModelManager(modelsDir: paths.modelsDir)
        self.modelManager = mm
        let transcriber = WhisperKitTranscriber(modelManager: mm)
        let diarizer = SpeakerKitDiarizer()
        let summarizer = ClaudeCLIBackend()
        let privacy = PrivacyController(store: store)
        // AVRecordingEngine 은 Pipeline 인자용 더미 인스턴스 (Task 8 에서 제거 예정)
        let dummyRecorder = AVRecordingEngine()
        let pipeline = MeetingPipeline(
            store: store,
            recorder: dummyRecorder,
            transcriber: transcriber,
            diarizer: diarizer,
            summarizer: summarizer,
            privacy: privacy,
            paths: paths
        )
        self.pipeline = pipeline

        let audio = AudioSessionManager()
        self.audio = audio
        self.coordinator = RecordingCoordinator(
            audio: audio,
            store: store,
            pipeline: pipeline,
            modelManager: mm,
            paths: paths
        )

        Task { await pipeline.resumeUnfinishedMeetings() }
        Task { await self.ensureModelDownloaded() }
    }

    @MainActor
    func ensureModelDownloaded() async {
        guard !modelDownloadInFlight else { return }
        let modelName = Self.defaultWhisperModel

        // 이미 캐시에 있는지 즉시 확인
        let dest = paths.modelsDir.appendingPathComponent(modelName, isDirectory: true)
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: dest.path),
           !contents.isEmpty {
            modelDownloadDone = true
            modelDownloadProgress = nil
            modelDownloadError = nil
            return
        }

        modelDownloadInFlight = true
        modelDownloadError = nil
        modelDownloadDone = false
        modelDownloadProgress = 0.001  // "시작됨" 신호 (0% 이면 UI 가 표시 안 할 수 있음)

        do {
            _ = try await modelManager.ensureModel(modelName) { [weak self] p in
                Task { @MainActor [weak self] in
                    self?.modelDownloadProgress = max(0.001, p)
                }
            }
            modelDownloadProgress = nil
            modelDownloadDone = true
            modelDownloadError = nil
        } catch {
            modelDownloadProgress = nil
            modelDownloadDone = false
            modelDownloadError = error.localizedDescription
        }
        modelDownloadInFlight = false
    }

    @MainActor
    func retryModelDownload() {
        modelDownloadError = nil
        Task { await self.ensureModelDownloaded() }
    }

    func cancel() async {
        stopAutoStopMonitor()
        await coordinator.cancelRecording()
    }

    func retry(meetingId: UUID) async { try? await pipeline.retry(meetingId: meetingId) }

    func stopRecording() async {
        stopAutoStopMonitor()
        await coordinator.stopRecording()
    }

    /// 녹음 시작 시 호출: 시스템 sleep + 무음 timeout 모니터 시작.
    @MainActor
    func startAutoStopMonitor() {
        stopAutoStopMonitor()
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleAutoStop(reason: "맥북 슬립으로 자동 정지됨")
            }
        }
        silenceMonitorTask = Task { [weak self] in
            await self?.runSilenceMonitor()
        }
    }

    @MainActor
    func stopAutoStopMonitor() {
        if let obs = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            sleepObserver = nil
        }
        silenceMonitorTask?.cancel()
        silenceMonitorTask = nil
    }

    @MainActor
    private func handleAutoStop(reason: String) async {
        guard await pipeline.isRunning else { return }
        stopAutoStopMonitor()
        await coordinator.stopRecording()
        lastError = reason
    }

    /// 1초마다 입력 레벨을 체크. 연속 30초 동안 -45 dB 이하면 자동 정지.
    private func runSilenceMonitor() async {
        var silentSince: Date?
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { break }
            let level = coordinator.inputLevel
            if level < Self.silenceThresholdDb {
                if silentSince == nil {
                    silentSince = Date()
                } else if let started = silentSince,
                          Date().timeIntervalSince(started) >= Self.silenceTimeoutSeconds {
                    Task { @MainActor in
                        await self.handleAutoStop(reason: "30초 무음으로 자동 정지됨")
                    }
                    return
                }
            } else {
                silentSince = nil
            }
        }
    }

    @MainActor
    func deleteMeeting(_ id: UUID) async {
        // 1) DB 레코드 + 자식 테이블 삭제 (cascade)
        do { try await store.deleteMeeting(id: id) }
        catch { lastError = "회의 삭제 실패: \(error.localizedDescription)" }
        // 2) 회의 폴더 (audio.m4a, transcript.jsonl, summary.json 등) 삭제
        let folder = paths.meetingFolder(id)
        try? FileManager.default.removeItem(at: folder)
        // 3) 사이드바 갱신 신호
        NotificationCenter.default.post(name: .meetingRecorderPipelineEvent, object: nil)
    }

    @MainActor
    func ensurePermissions() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            lastError = "마이크 권한이 거부됨. 시스템 설정 > 개인 정보 보호 및 보안 > 마이크 에서 EdgeLauncher 를 허용하세요."
            return false
        @unknown default:
            return false
        }
    }
}

struct MeetingRecorderModule: EdgeModule {
    let id = "meeting-recorder"
    let title = "회의록"
    let iconName = "mic.fill"
    let supportsFullscreen = false

    var view: some View { MeetingRecorderRootView() }
}

private struct MeetingRecorderRootView: View {
    @State private var host = MeetingRecorderHost()
    @State private var showStartSheet = false
    @State private var showSettings = false
    @State private var openSettingsAfterStartSheetDismiss = false

    var body: some View {
        MainWindow(
            store: host.store,
            paths: host.paths,
            onCancelMeeting: { _ in await host.cancel() },
            onRetryMeeting: { id in await host.retry(meetingId: id) },
            onStartNewMeeting: {
                Task {
                    if await host.ensurePermissions() {
                        showStartSheet = true
                    }
                }
            },
            onStopRecording: { await host.stopRecording() },
            onOpenSettings: { openSettings() },
            onDeleteMeeting: { id in await host.deleteMeeting(id) }
        )
        .sheet(isPresented: $showStartSheet) {
            StartMeetingSheet(
                isPresented: $showStartSheet,
                defaultTitle: defaultTitle(),
                onConfirm: { input in
                    Task {
                        do {
                            let newId = try await host.coordinator.startRecording(
                                title: input.title, attendees: input.attendees)
                            // 자동 중지 모니터 가동 (sleep + 30초 무음)
                            host.startAutoStopMonitor()
                            // 새 회의를 사이드바에서 자동 선택
                            await MainActor.run {
                                NotificationCenter.default.post(
                                    name: .meetingRecorderSelectMeeting,
                                    object: nil,
                                    userInfo: ["meetingId": newId])
                            }
                        } catch {
                            await MainActor.run {
                                host.lastError = "녹음 시작 실패: \(error.localizedDescription)"
                            }
                        }
                    }
                },
                onOpenSettings: { openSettingsAfterStartSheetDismiss = true; showStartSheet = false },
                modelDownloadProgress: host.modelDownloadProgress,
                modelDownloadDone: host.modelDownloadDone,
                modelDownloadError: host.modelDownloadError,
                onRetryModelDownload: { host.retryModelDownload() },
                coordinator: host.coordinator
            )
        }
        .onChange(of: showStartSheet) { _, isPresented in
            if !isPresented && openSettingsAfterStartSheetDismiss {
                openSettingsAfterStartSheetDismiss = false
                DispatchQueue.main.async { showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) {
            UI.SettingsView(store: host.store, paths: host.paths, modelManager: host.modelManager)
        }
        .alert("오류", isPresented: Binding(
            get: { host.lastError != nil },
            set: { if !$0 { host.lastError = nil } }
        )) {
            Button("확인") { host.lastError = nil }
        } message: {
            Text(host.lastError ?? "")
        }
        .task {
            for await _ in await host.pipeline.events {
                NotificationCenter.default.post(
                    name: .meetingRecorderPipelineEvent, object: nil)
            }
        }
    }

    private func openSettings() {
        if showStartSheet {
            openSettingsAfterStartSheetDismiss = true
            showStartSheet = false
        } else {
            showSettings = true
        }
    }

    private func defaultTitle() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm 회의"
        return f.string(from: Date())
    }
}
