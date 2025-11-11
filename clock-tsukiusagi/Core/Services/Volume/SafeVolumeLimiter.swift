//
//  SafeVolumeLimiter.swift
//  clock-tsukiusagi
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
/// Architecture:
/// Sources → masterBusMixer → Limiter → mainMixerNode → outputNode (Apple's auto-wiring)
/// This avoids conflicts with Apple's automatic mainMixer→output connection
public final class SafeVolumeLimiter: SafeVolumeLimiting {
    // MARK: - Properties

    private let limiterNode = AVAudioUnitDistortion()
    public let masterBusMixer = AVAudioMixerNode()  // All sources connect here

    public var maxOutputDb: Float {
        didSet {
            print("🔊 [SafeVolumeLimiter] Max output updated to \(maxOutputDb) dB")
            updateLimiterSettings()
        }
    }

    private var isConfigured = false
    private var needsRebind = false
    private weak var engine: AVAudioEngine?
    private var nodesAttached = false

    // MARK: - Initialization

    public init(maxOutputDb: Float = -6.0) {
        self.maxOutputDb = maxOutputDb
    }

    // MARK: - Public Methods

    /// Attach nodes to engine (call once during initialization)
    /// - Parameter engine: AVAudioEngine
    public func attachNodes(to engine: AVAudioEngine) {
        guard !nodesAttached else {
            print("🔊 [SafeVolumeLimiter] Nodes already attached, skipping")
            return
        }

        self.engine = engine

        print("🔊 [SafeVolumeLimiter] Attaching nodes to engine...")

        // Attach nodes to engine
        if !engine.attachedNodes.contains(masterBusMixer) {
            engine.attach(masterBusMixer)
            print("   ✅ masterBusMixer attached")
        }

        if !engine.attachedNodes.contains(limiterNode) {
            engine.attach(limiterNode)
            print("   ✅ limiterNode attached")
        }

        nodesAttached = true
        print("🔊 [SafeVolumeLimiter] Nodes attached successfully")
    }

    /// Configure limiter with masterBusMixer approach
    /// Should be called AFTER engine.start() and AFTER at least one source is connected
    public func configure(engine: AVAudioEngine, format: AVAudioFormat) {
        // Ensure nodes are attached first
        attachNodes(to: engine)

        // Skip if already configured and no rebind needed
        guard !isConfigured || needsRebind else {
            print("🔊 [SafeVolumeLimiter] Already configured, skipping")
            return
        }

        // Ensure engine is running
        guard engine.isRunning else {
            print("🔊 [SafeVolumeLimiter] Engine not running, skipping configuration")
            return
        }

        print("🔊 [SafeVolumeLimiter] Configuring soft limiter (masterBusMixer approach)")
        print("   Max output: \(maxOutputDb) dB")
        print("   Format: \(format.sampleRate) Hz, \(format.channelCount) channels")

        // Disconnect existing connections to ensure clean state
        engine.disconnectNodeOutput(masterBusMixer)
        engine.disconnectNodeOutput(limiterNode)

        // Connect: masterBusMixer → Limiter → mainMixerNode
        // (mainMixerNode → outputNode is Apple's automatic connection)
        engine.connect(masterBusMixer, to: limiterNode, format: format)
        engine.connect(limiterNode, to: engine.mainMixerNode, format: format)

        print("   ✅ Audio path: masterBusMixer → limiter → mainMixer → output")

        // Configure limiter settings
        updateLimiterSettings()

        isConfigured = true
        needsRebind = false
        print("🔊 [SafeVolumeLimiter] Configuration complete")
    }

    public func updateLimit(_ db: Float) {
        maxOutputDb = db
    }

    /// Reset configuration state (call when engine is stopped)
    public func reset() {
        print("🔊 [SafeVolumeLimiter] Resetting configuration state")
        needsRebind = true
    }

    // MARK: - Private Methods

    private func updateLimiterSettings() {
        // iOS用ソフトクリッピング設定
        // AVAudioUnitDistortionを使用してソフトリミットを実現
        // 負のプリゲイン + ソフトクリッピングでダイナミクスプロセッサーに近い効果を得る

        limiterNode.loadFactoryPreset(.multiDecimated4)  // ソフトなプリセットを使用

        // プリゲイン: maxOutputDbに基づいて調整（-6dB → 約-6dB gain）
        limiterNode.preGain = maxOutputDb

        // ウェットドライミックス: 100%ウェット（完全に処理を適用）
        limiterNode.wetDryMix = 100

        print("   Pre-gain: \(maxOutputDb) dB")
        print("   Preset: MultiDecimated4 (soft clipping)")
        print("   Wet/Dry: 100% (full processing)")
    }
}
