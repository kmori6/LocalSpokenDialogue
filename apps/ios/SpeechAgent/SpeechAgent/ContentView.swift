//
//  ContentView.swift
//  SpeechAgent
//
//  Created by Kosuke Mori on 2026/03/18.
//

import SwiftUI

struct Message {
    var role: String
    var content: String
}

struct ContentView: View {
    @State private var text: String = ""
    
    var body: some View {
        VStack {
            
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
        }
        .padding()
    }
    
    private func sendMessage() {
        
    }
}

struct MessageView: View {
    let message: Message
    
    var body: some View {
        
    }
}

#Preview {
    ContentView()
}
