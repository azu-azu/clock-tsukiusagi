//
//  GnossienneIntroSignal.swift
//  TsukiSound
//
//  Satie - Gnossienne No.1 (Public Domain)
//  Iconic opening motif: Eb–F–Gb（ear-based, contains uncertainty）
//
//  Uses SignalEnvelopeUtils for noise-free envelope generation
//

import Foundation

public struct GnossienneIntroSignal {
    public static func makeSignal() -> Signal {
        let g = GnoIntroGenerator()
        return Signal { t in g.sample(at: t) }
    }
}

private final class GnoIntroGenerator {

    struct Note { let freq: Float; let dur: Float }

    // Opening motif only（耳コピ。不確実）
    // Eb4–F4–Gb4 → Eb4 → Db4 → Eb4（1.2x slower）
    let melody: [Note] = [
        Note(freq: 311.13, dur: 1.40), // Eb4
        Note(freq: 349.23, dur: 1.40), // F4
        Note(freq: 369.99, dur: 1.80), // Gb4
        Note(freq: 311.13, dur: 1.40), // Eb4
        Note(freq: 277.18, dur: 1.40), // Db4
        Note(freq: 311.13, dur: 2.20), // Eb4 (smooth loop)
    ]

    lazy var cumulative: [Float] = {
        var a: [Float] = [0]
        for n in melody { a.append(a.last! + n.dur) }
        return a
    }()
    lazy var cycle: Float = cumulative.last!

    // Sound Parameters（周波数に応じたアタック時間）
    let attack: Float = SignalEnvelopeUtils.AttackTime.mid  // 200-500Hz range
    let decay: Float = 3.0
    let gain: Float = 0.30

    func sample(at t: Float) -> Float {

        let local = t.truncatingRemainder(dividingBy: cycle)
        guard let idx = find(local) else { return 0 }

        let n = melody[idx]
        let st = cumulative[idx]
        let dt = local - st

        let env = SignalEnvelopeUtils.smoothEnvelope(
            t: dt,
            duration: n.dur,
            attack: attack,
            decay: decay
        )

        // Pure sine wave for clean sound
        let v = SignalEnvelopeUtils.pureSine(frequency: n.freq, t: t)

        return SignalEnvelopeUtils.softClip(v * env * gain)
    }

    private func find(_ t: Float) -> Int? {
        for i in 0..<melody.count {
            if t >= cumulative[i] && t < cumulative[i+1] { return i }
        }
        return nil
    }
}
