//
//  PlaylistState.swift
//  TsukiSound
//
//  プレイリストの曲順と現在位置を管理する "地図"
//  Source of Truth として AudioService が保持し、UI は environmentObject で参照
//

import Foundation

/// プレイリストの状態を管理
@MainActor
public final class PlaylistState: ObservableObject {
    // MARK: - Published Properties

    /// 曲順（ユーザーがドラッグで変更可能）
    @Published public private(set) var orderedPresets: [UISoundPreset]

    /// 現在再生中の曲のインデックス
    @Published public private(set) var currentIndex: Int = 0

    // MARK: - Private Properties

    private let allPresets: [UISoundPreset]
    private let storageKey = "playlist.order.v1"

    // MARK: - Initialization

    public init(allPresets: [UISoundPreset] = Array(UISoundPreset.allCases)) {
        self.allPresets = allPresets
        self.orderedPresets = Self.loadOrder(from: "playlist.order.v1", allPresets: allPresets)
    }

    // MARK: - Public Methods

    /// 曲順を変更（ドラッグ&ドロップ用）
    public func move(from source: IndexSet, to destination: Int) {
        orderedPresets.move(fromOffsets: source, toOffset: destination)
        saveOrder()
    }

    /// 次の曲に進む（ループ）
    public func advanceToNext() -> UISoundPreset {
        guard !orderedPresets.isEmpty else {
            fatalError("Playlist is empty")
        }
        currentIndex = (currentIndex + 1) % orderedPresets.count
        return orderedPresets[currentIndex]
    }

    /// 特定の曲を現在位置に設定
    public func setCurrentIndex(to preset: UISoundPreset) {
        if let idx = orderedPresets.firstIndex(where: { $0.id == preset.id }) {
            currentIndex = idx
        } else {
            // 保険：存在しない場合は0に戻す
            currentIndex = 0
        }
    }

    /// 現在の曲を取得
    public func presetForCurrentIndex() -> UISoundPreset? {
        guard orderedPresets.indices.contains(currentIndex) else { return nil }
        return orderedPresets[currentIndex]
    }

    // MARK: - Private Methods

    /// UserDefaultsから曲順を復元
    private static func loadOrder(from key: String, allPresets: [UISoundPreset]) -> [UISoundPreset] {
        let map = Dictionary(uniqueKeysWithValues: allPresets.map { ($0.id, $0) })
        let storedIds = UserDefaults.standard.stringArray(forKey: key) ?? []

        // 1. storedIds にあるものを先に並べる（存在しないIDは無視）
        var result: [UISoundPreset] = storedIds.compactMap { map[$0] }

        // 2. まだ result に入ってないプリセットを後ろに足す（新規追加分）
        for preset in allPresets where !result.contains(where: { $0.id == preset.id }) {
            result.append(preset)
        }

        return result
    }

    /// UserDefaultsに曲順を保存
    private func saveOrder() {
        let ids = orderedPresets.map(\.id)
        UserDefaults.standard.set(ids, forKey: storageKey)
    }
}
