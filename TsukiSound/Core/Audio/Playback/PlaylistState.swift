//
//  PlaylistState.swift
//  TsukiSound
//
//  プレイリストの曲順と現在位置を管理する "地図"
//  Source of Truth として AudioService が保持し、UI は environmentObject で参照
//

import Foundation

/// リピートモード
public enum RepeatMode: String, CaseIterable {
    case one = "one"    // 一曲リピート
    case all = "all"    // 連続再生（全曲ループ）

    var icon: String {
        switch self {
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }

    var displayName: String {
        switch self {
        case .one: return "audio.repeat.one".localized
        case .all: return "audio.repeat.all".localized
        }
    }
}

/// プレイリストの状態を管理
@MainActor
public final class PlaylistState: ObservableObject {
    // MARK: - Published Properties

    /// 曲順（ユーザーがドラッグで変更可能）
    @Published public private(set) var orderedPresets: [UISoundPreset]

    /// 現在再生中の曲のインデックス
    @Published public private(set) var currentIndex: Int = 0

    /// リピートモード
    @Published public var repeatMode: RepeatMode = .all

    /// 選択中のカテゴリ（nil = 全曲表示）
    @Published public var selectedCategory: AudioCategory?

    // MARK: - Computed Properties

    /// カテゴリでフィルタされたプリセット一覧
    public var displayedPresets: [UISoundPreset] {
        guard let category = selectedCategory else {
            return orderedPresets  // 全曲
        }
        let categoryPresets = Set(category.presets)
        return orderedPresets.filter { categoryPresets.contains($0) }
    }

    // MARK: - Private Properties

    private let allPresets: [UISoundPreset]
    private let storageKey = "playlist.order.v1"
    private let categoryStorageKey = "playlist.category.v1"

    // MARK: - Initialization

    public init(allPresets: [UISoundPreset] = Array(UISoundPreset.allCases)) {
        self.allPresets = allPresets
        self.orderedPresets = Self.loadOrder(from: "playlist.order.v1", allPresets: allPresets)
        self.selectedCategory = Self.loadCategory(from: "playlist.category.v1")
    }

    // MARK: - Public Methods

    /// 曲順を変更（ドラッグ&ドロップ用）
    public func move(from source: IndexSet, to destination: Int) {
        orderedPresets.move(fromOffsets: source, toOffset: destination)
        saveOrder()
    }

    /// 次の曲に進む（リピートモードに応じて動作、カテゴリフィルタを考慮）
    public func advanceToNext() -> UISoundPreset {
        let activePresets = displayedPresets
        guard !activePresets.isEmpty else {
            fatalError("Playlist is empty")
        }

        switch repeatMode {
        case .one:
            // 一曲リピート: 同じ曲を返す
            return activePresets[currentIndex]
        case .all:
            // 連続再生: 次の曲に進む（ループ）
            currentIndex = (currentIndex + 1) % activePresets.count
            return activePresets[currentIndex]
        }
    }

    /// 特定の曲を現在位置に設定（カテゴリフィルタを考慮）
    public func setCurrentIndex(to preset: UISoundPreset) {
        let activePresets = displayedPresets
        if let idx = activePresets.firstIndex(where: { $0.id == preset.id }) {
            currentIndex = idx
        } else {
            // 保険：存在しない場合は0に戻す
            currentIndex = 0
        }
    }

    /// 現在の曲を取得（カテゴリフィルタを考慮）
    public func presetForCurrentIndex() -> UISoundPreset? {
        let activePresets = displayedPresets
        guard activePresets.indices.contains(currentIndex) else { return nil }
        return activePresets[currentIndex]
    }

    /// カテゴリを設定（永続化付き）
    public func setCategory(_ category: AudioCategory?) {
        selectedCategory = category
        // カテゴリ変更時はインデックスをリセット
        currentIndex = 0
        saveCategory()
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

    /// UserDefaultsからカテゴリを復元
    private static func loadCategory(from key: String) -> AudioCategory? {
        guard let categoryId = UserDefaults.standard.string(forKey: key) else {
            return nil
        }
        return AudioCategory(rawValue: categoryId)
    }

    /// UserDefaultsにカテゴリを保存
    private func saveCategory() {
        if let category = selectedCategory {
            UserDefaults.standard.set(category.rawValue, forKey: categoryStorageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: categoryStorageKey)
        }
    }
}
