# Signal Performance General Guide

**TsukiSound 音源システム：パフォーマンス最適化・原則ガイド（General Principles）**

このガイドは、TsukiSound の **全 Signal（Melody / Drone / Chime / Noise）** に共通する
**パフォーマンス設計の原則** をまとめた資料。

特定の曲（例：Jupiter）ではなく、**全体の基礎思想・セーフティライン** を定義する。

---

## 1. TsukiSound の基本思想

TsukiSound の音源は、次の価値観の上に成り立つ：

* **Quiet Expression（静けさの表現）**
* **Calm Computational Design（穏やかな計算構造）**
* **必要以上の計算をしない、ミニマルな合成**
* **豪華さより、持続可能な音の質感**

この思想に基づき、「CPU負荷を抑えつつ美しい音を作るための原則」を示す。

---

## 2. パフォーマンスの基本原則（Universal Principles）

### **① sin() の計算回数がすべてを決める**

1サンプル = 1/44100秒
→ この中で全計算が終わらなければ音飛びが発生する。

**安全圏の目安：
1秒あたり 50万 sin() 計算**

### **② レイヤー追加は"4倍負荷"として扱う**

1レイヤー増えると倍音計算が丸ごと乗る。
レイヤーは**基本1つ、最大2つまで**が現実的。

### **③ 倍音(harmonics)は 4〜6本まで**

6本を越えると急激に重くなる。
メロディ系：5〜6本
ドローン系：3〜5本
チャイム系：4〜6本

### **④ legato overlap は最強＆最凶**

自然な繋がりを得られるが、
**計算量は"ほぼ2倍"**になる。
必要最小限に。

### **⑤ エンベロープ（attack/release）は負荷ゼロで効果大**

CPU負荷なしで音の質感が激変する。
派手にするなら倍音より**エンベロープ強化**の方が賢い。

### **⑥ ビブラートは PM（位相変調）を使う**

FM（周波数変調）はノイズが出やすく高負荷。
PM のみ推奨。

---

## 3. Signalタイプ別の推奨パラメータ帯

### **■ Melody-type（Jupiter, Gymnopédie, etc）**

* harmonics: **5〜6**
* attackTime: **0.2〜0.5**
* releaseTime: **0.6〜1.2**
* vibratoRate: **3〜5Hz**
* vibratoDepth: **0.0008〜0.0012**
* legatoOverlap: **0.05〜0.12**

目的：
「余韻のある滑らかな主旋律」「静けさの中の存在感」

---

### **■ Drone-type（BassoonDrone, LunarPulse etc）**

* harmonics: **3〜5**
* attack: **0.8〜2.0**
* release: **1.0〜3.0**
* vibrato: **非常に弱く（0.0005未満）**

目的：
「変化は最小限、環境ノイズのような存在感」

---

### **■ Chime-type（TreeChime etc）**

* harmonics: **4〜6**
* attack: **0.01〜0.05**
* release: **0.3〜0.7**
* vibrato: **基本なし**
* ランダム揺らぎは LFO で処理

目的：
「瞬間的・儚い・自然物のような不規則さ」

---

### **■ Noise-type（AirLayerの代替など）**

* AVAudioSourceNode 推奨
* harmonics は使用しない
* フィルタは stateful なので必ず SourceNode 側に置く

目的：
「ステートレスSignalでは作れない"生きたノイズ"を作る」

---

## 4. 避けるべきアンチパターン（Anti-patterns）

以下は TsukiSound の核心思想に反する構造であり、
CPU爆発やノイズの主原因となる。

### **❌ 過剰レイヤー（3〜4）**

→ CPUが爆死
→ 音飛び
→ 挙動不安定
（※ 詳細な破綻例は `report/report-jupiter-melody-optimization.md` 参照）

### **❌ FMビブラート**

→ 蛇行した不自然な音
→ 位相乱れ
→ 計算コスト増

### **❌ Noise を Signal関数で実装**

→ ランダム生成は状態を持てない
→ フィルタが正常動作しない
→ AirLayer の失敗例（詳細は別ガイド）

### **❌ harmonics の欲張り（7本以上）**

→ 効果に比べて負荷が爆増する

### **❌ legatoOverlap の過剰**

→ 2倍負荷
→ 音の混濁

---

## 5. パフォーマンス計算例（基礎理解）

### sin() 計算回数

| 構成                              | sin()/sample | sin()/sec  |
| ------------------------------- | ------------ | ---------- |
| 1 layer × 6 harmonics           | 6            | 約 26万      |
| + legato                        | 12           | 約 53万      |
| 2 layers × 6 harmonics          | 12           | 約 53万      |
| 4 layers × 6 harmonics × legato | 48           | 約 210万（破綻） |

**→ 安全圏は 50万程度。
→ 100万以上は運が悪いと破綻。
→ 200万超は確実に破綻。**

---

## 6. 原則に反した時の実例

※実例は別資料
**`report/report-jupiter-melody-optimization.md`** の以下章を参照：

* 背景
* 4レイヤー構成
* 負荷計算
* 破綻の原因
* エンベロープ＋PMでの改善

これは TsukiSound における
**典型的なアンチパターン → 原則遵守で解決する流れ**
を示す教材になる。

---

## 7. まとめ（General Summary）

* **豪華さより値打ちなのは"構造の静けさ"**
* レイヤーではなく **エンベロープで豊かさを作る**
* PMビブラートは低負荷で有機的
* sin() 計算回数 = 音源の生死線
* 原則を破ると破綻し、守ると静かに美しくなる

TsukiSound の美しさは、
**「無駄を足すのではなく、必要を丁寧に残すこと」**
にある。

---

## Appendix: TsukiSound 設計の美学（Philosophy）

* "音は足して豪華にするより、構造を綺麗にする方が強い"
* "静けさは構造の副産物であって、飾りではない"
* "音はPoetic、構造はRational。その両立がTsukiSound"
