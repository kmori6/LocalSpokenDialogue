//
//  ContentView.swift
//  SpeechAgent
//
//  Created by Kosuke Mori on 2026/03/18.
//

import SwiftUI

struct Message: Identifiable {
    var id = UUID()
    var role: String
    var content: String
}

struct Responses: Decodable {
    let id: String
    let output: [Output]
}

struct Output: Decodable {
    let type: String
    let content: [Content]
}

struct Content: Decodable {
    let type: String
    let text: String
}

struct ContentView: View {
    @State private var text: String = ""
    @State private var messages: [Message] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                    .onChange(of: messages.count) { _ in
                        if let lastID = messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
                
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Input message", text: $text, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(Color.blue)
                            )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
    }
    
    private func sendMessage() {
        guard !text.isEmpty else {
            return
        }
        
        messages.append(Message(role: "user", content: text))
        
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            let body = [
                "model": "gpt-5.4",
                "input": text,
                "instructions": "You are a helpful assistant."
            ]
            guard let url = URL(string: "https://api.openai.com/v1/responses") else {
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                //
            }
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard let data = data else { return }
                do {
                    let decoder = JSONDecoder()
                    let json = try decoder.decode(Responses.self, from: data)
                    let assistantMessage = json.output[0].content[0].text
                    let message = Message(role: "assistant", content: assistantMessage)
                    messages.append(message)
                } catch let error {
                    print(error)
                }
            }
            task.resume()
        }
        
        text = ""
    }
}

struct MessageView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer(minLength: 40)
                                
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Spacer(minLength: 40)
            }
        }
    }
}

#Preview {
    ContentView()
}
