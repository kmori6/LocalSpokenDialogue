//
//  LLMClient.swift
//  LocalSpokenDialogue
//
//  Created by Kosuke Mori on 2026/03/19.
//

import Foundation
import Combine
import llama

struct Request: Encodable {
    let model: String
    let instructions: String
    let input: [Content]
}

struct Responses: Decodable {
    let id: String
    let output: [Content]
}

struct Content: Codable {
    let role: String
    let content: [ContentItem]
}

struct ContentItem: Codable {
    let type: String
    let text: String
}

final class LLMClient: ObservableObject {
    
    @Published var isReady = false
    private let modelFileName = "Qwen3.5-4B-Q4_K_M"
    private let modelFileExtension = "gguf"
    private var context: LlamaContext?
    private let instructions = "You are a helpful assistant."
    
    func load() async {
        if isReady {
            return
        }
        
        do {
            guard let modelURL = Bundle.main.url(
                forResource: modelFileName,
                withExtension: modelFileExtension,
            ) else {
                print("model url error.")
                return
            }

            context = try LlamaContext.create_context(path: modelURL.path)
            isReady = true
            print("loaded model.")
        } catch {
            print("model load failed.")
        }
    }
    
    func generate(text: String) async -> String {
        guard let context else {
            return "model is not loaded."
        }
        
        var prompt = "<|im_start|>system\n\(instructions)<|im_end|>\n"
        prompt += "<|im_start|>user\n\(text)<|im_end|>\n"
        prompt += "<|im_start|>assistant\n"
        
        await context.completion_init(text: prompt)
        
        var output = ""
        while await !context.is_done {
            print(output)
            output += await context.completion_loop()
        }
        
        await context.clear()
        
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }
}
