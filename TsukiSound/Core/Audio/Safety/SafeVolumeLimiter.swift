//
//  SafeVolumeLimiter.swift
//  TsukiSound
//
//  Created by Claude Code on 2025-11-10.
//  安全音量リミッター（iOS: AVAudioUnitDistortion使用）
//  Architecture: masterBusMixer approach to avoid conflicts with Apple's auto-wiring
//

import AVFoundation
import Foundation

/// 安全音量制限プロトコル
public protocol SafeVolumeLimiting {
    var maxOutputDb: Float { get set }
    var masterBusMixer: AVAudioMixerNode { get }
    func attachNodes(to engine: AVAudioEngine)
    func configure(engine: AVAudioEngine, format: AVAudioFormat)
    func updateLimit(_ db: Float)
    func reset()
}

/// 安全音量リミッター
/// iOS用実装: AVAudioUnitDistortion + ソフトクリッピングを使用
/// Note: AVAudioUnitDynamicsProcessorはmacOSのみで利用可能なため、
/// iOS用の代替として歪みエフェクトを使用してソフトリミットを実装
///
/// Architecture: ADR-0002 (iOS Volume Limiter - AVAudioUnitDistortion Alternative)
/// Sources → masterBusMixer → Limiter → mainMixerNode → outputNode (Apple's auto-wiring)
/// This avoids conflicts with Apple's automatic mainMixer→output connection
public final class SafeVolumeLimiter: SafeVolumeLimiting {
    // MARK: - Properties

    private let limiterNode = AVAudioUnitDistortion()
    public let masterBusMixer = AVAudioMixerNode()  // All sources connect here

    public var maxOutputDb: Float {
        didSet {
            updateLimiterSettings()
        }
    }

    private var isConfigured = false
    private var needsRebind = false
    private weak var engine: AVAudioEngine?
    private var nodesAttached = false
    private var configuredFormat: AVAudioFormat?

    // MARK: - Initialization

    public init(maxOutputDb: Float = -6.0) {
        self.maxOutputDb = maxOutputDb
    }

    // MARK: - Public Methods

    /// Attach nodes to engine (call once during initialization)
    /// - Parameter engine: AVAudioEngine
    public func attachNodes(to engine: AVAudioEngine) {
        guard !nodesAttached else {
            return
        }

        self.engine = engine

        // Attach nodes to engine
        if !engine.attachedNodes.contains(masterBusMixer) {
            engine.attach(masterBusMixer)
        }

        if !engine.attachedNodes.contains(limiterNode) {
            engine.attach(limiterNode)
        }

        nodesAttached = true
    }

    /// Configure limiter with masterBusMixer approach
    /// CRITICAL: Must be called BEFORE engine.start() to avoid runtime reconfiguration
    /// Should use output format (48kHz/2ch) for consistency, not file format
    public func configure(engine: AVAudioEngine, format: AVAudioFormat) {
        // Ensure nodes are attached first
        attachNodes(to: engine)

        // Idempotent check: Skip if already configured with same format
        if isConfigured, !needsRebind,
           let existing = configuredFormat,
           existing.sampleRate == format.sampleRate,
           existing.channelCount == format.channelCount {
            return
        }

        // CRITICAL: Refuse to reconfigure if engine is running
        // Runtime graph reconfiguration causes -10868 crashes
        if engine.isRunning {
            #if DEBUG
            print("[SafeVolumeLimiter] Engine is running, cannot reconfigure (would crash)")
            print("   Current format: \(configuredFormat?.sampleRate ?? 0)Hz/\(configuredFormat?.channelCount ?? 0)ch")
            print("   Requested format: \(format.sampleRate)Hz/\(format.channelCount)ch")
            #endif
            return
        }

        // Disconnect existing connections to ensure clean state
        engine.disconnectNodeOutput(masterBusMixer)
        engine.disconnectNodeOutput(limiterNode)

        // Connect: masterBusMixer → Limiter → mainMixerNode
        // Use provided format for masterBusMixer→Limiter connection
        // Use nil format for Limiter→mainMixer to allow automatic format conversion
        engine.connect(masterBusMixer, to: limiterNode, format: format)
        engine.connect(limiterNode, to: engine.mainMixerNode, format: nil)  // Auto-conversion

        // Configure limiter settings
        updateLimiterSettings()

        isConfigured = true
        needsRebind = false
        configuredFormat = format
    }

    public func updateLimit(_ db: Float) {
        maxOutputDb = db
    }

    /// Reset configuration state (call when engine is stopped)
    public func reset() {
        needsRebind = true
    }

    /// Reset configuration state completely (for file switching)
    /// CRITICAL: Forces complete reconfiguration on next configure() call
    /// This prevents audio buffer cache reuse between different files
    public func resetConfigurationState() {
        isConfigured = false
        needsRebind = true
        configuredFormat = nil
    }

    // MARK: - Private Methods

    private func updateLimiterSettings() {
        // NOTE: Volume limiting is intentionally bypassed.
        // AVAudioUnitDistortion caused noise/artifacts with all presets tested.
        // iOS lacks AVAudioUnitDynamicsProcessor (macOS only).
        // Future options: AVAudioUnitEQ-based soft limiting or custom gain node.
        limiterNode.wetDryMix = 0  // 100% dry = no processing
    }
}
