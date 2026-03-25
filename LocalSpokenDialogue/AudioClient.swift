//
//  AudioClient.swift
//  LocalSpokenDialogue
//
//  Created by Kosuke Mori on 2026/03/25.
//

import Foundation
import AVFoundation

final class AudioClient {
    private let engine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "vad.audio.queue")
    
    private let vadClient = VADClient()
    private let asrClient = ASRClient()
    
    private var vadInputBuffer: [Float] = []
    private var consecutiveSilenceCount = 0
    private let endCount = 6  // 32 * 6 = 192ms
    private let startThreshold: Float = 0.5
    private let endThreshold: Float = 0.35
    
    // state
    private var isSpeaking = false
    
    func start() async throws {
        try vadClient.load()
        
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker]
        )
        try session.setPreferredSampleRate(16_000)
        try session.setActive(true)
        
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }

            audioQueue.async {
                self.process(buffer, inputFormat: format)
            }
        }

        try engine.start()
    }
    
    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        vadClient.reset()
        vadInputBuffer.removeAll()
    }

    private func process(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) {

        let vadSamples = convertTo16kMonoFloatArray(buffer, inputFormat: inputFormat)
        guard !vadSamples.isEmpty else { return }

        vadInputBuffer.append(contentsOf: vadSamples)

        var latestProb: Float?

        while vadInputBuffer.count >= 512 {
            let chunk = Array(vadInputBuffer.prefix(512))
            vadInputBuffer.removeFirst(512)

            do {
                latestProb = try vadClient.predict(audio: chunk)
            } catch {
                return
            }
        }

        guard let prob = latestProb else { return }

        if prob >= startThreshold {
            // silence -> utt
            if !isSpeaking {
                asrClient.startRecognition()
            }
            isSpeaking = true
            consecutiveSilenceCount = 0
        } else if prob <= endThreshold {
            consecutiveSilenceCount += 1
        }
        
        // utt -> silence
        if isSpeaking && consecutiveSilenceCount >= endCount {
            isSpeaking = false
            consecutiveSilenceCount = 0
            asrClient.stopRecognition()
        }
        
        // push pcm buffer to asr
        if isSpeaking {
            asrClient.append(buffer)
        }
    }
}
