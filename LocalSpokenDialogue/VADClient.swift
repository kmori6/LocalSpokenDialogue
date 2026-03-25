//
//  VADClient.swift
//  LocalSpokenDialogue
//
//  Created by Kosuke Mori on 2026/03/24.
//

import Foundation
import OnnxRuntimeBindings

final class VADClient {
    private var session: ORTSession?
    private var state: [Float] = Array(repeating: 0, count: 2 * 1 * 128)
    private var context: [Float] = Array(repeating: 0, count: 64)
    private var sr = [Int64(16000)]
    private let contextSize = 64

    func load() throws {
        let modelURL = Bundle.main.url(
            forResource: "silero_vad_op18_ifless",
            withExtension: "onnx"
        )!
        
        let env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        try options.setIntraOpNumThreads(1)
        session = try ORTSession(
            env: env,
            modelPath: modelURL.path,
            sessionOptions: options
        )
    }

    func reset() {
        state = Array(repeating: 0, count: 2 * 1 * 128)
        context = Array(repeating: 0, count: 64)
    }
    
    func predict(audio: [Float]) throws -> Float {
        guard let session else {
            return 0.0
        }
        
        // input audio
        let input = context + audio
        // convert to raw array
        let inputData = input.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        let inputTensor = try ORTValue(
            tensorData: NSMutableData(data: inputData),
            elementType: .float,
            shape: [1, input.count].map { NSNumber(value: $0) }
        )
        
        // state
        let stateData = state.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        let stateTensor = try ORTValue(
            tensorData: NSMutableData(data: stateData),
            elementType: .float,
            shape: [2, 1, 128].map { NSNumber(value: $0) }
        )
        
        let srData = sr.withUnsafeMutableBytes { buffer in
            NSMutableData(bytes: buffer.baseAddress, length: buffer.count)
        }
        let srTensor = try ORTValue(
            tensorData: srData,
            elementType: .int64,
            shape: [1].map { NSNumber(value: $0) }
        )
        
        let inputs: [String: ORTValue] = [
            "input": inputTensor,
            "state": stateTensor,
            "sr": srTensor,
        ]
        let outputs = try session.run(
            withInputs: inputs,
            outputNames: Set(["output", "stateN"]),
            runOptions: nil
        )
        
        guard let probTensor = outputs["output"] else {
            return 0.0
        }
        let probData = try probTensor.tensorData() as Data
        let probs = probData.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
        guard let prob = probs.first else {
            return 0.0
        }
        
        guard let nextStateTensor = outputs["stateN"] else {
            return 0.0
        }
        let nextStateData = try nextStateTensor.tensorData() as Data
        let nextState = probData.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
        
        state = nextState
        context = Array(audio.suffix(contextSize))

        return prob
    }
}
