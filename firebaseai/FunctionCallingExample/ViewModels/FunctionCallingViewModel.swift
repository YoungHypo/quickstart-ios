// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import FirebaseAI
import Foundation
import UIKit

@MainActor
class FunctionCallingViewModel: ObservableObject {
  /// This array holds both the user's and the system's chat messages
  @Published var messages = [ChatMessage]()

  /// Indicates we're waiting for the model to finish
  @Published var busy = false

  @Published var error: Error?
  var hasError: Bool {
    return error != nil
  }

  @Published var initialPrompt: String = ""
  @Published var title: String = ""

  private var model: GenerativeModel
  private var chat: Chat

  private var chatTask: Task<Void, Never>?

  private var sample: Sample?

  init(firebaseService: FirebaseAI, sample: Sample? = nil) {
    self.sample = sample

    // create a generative model with sample data
    model = firebaseService.generativeModel(
      modelName: "gemini-2.0-flash-001",
      tools: sample?.tools,
      systemInstruction: sample?.systemInstruction
    )

    chat = model.startChat()

    initialPrompt = sample?.initialPrompt ?? ""
    title = sample?.title ?? ""
  }

  func sendMessage(_ text: String, streaming: Bool = true) async {
    error = nil
    if streaming {
      await internalSendMessageStreaming(text)
    } else {
      await internalSendMessage(text)
    }
  }

  func startNewChat() {
    stop()
    error = nil
    chat = model.startChat()
    messages.removeAll()
    initialPrompt = ""
  }

  func stop() {
    chatTask?.cancel()
    error = nil
  }

  private func internalSendMessageStreaming(_ text: String) async {
    chatTask?.cancel()

    chatTask = Task {
      busy = true
      defer {
        busy = false
      }

      // first, add the user's message to the chat
      let userMessage = ChatMessage(message: text, participant: .user)
      messages.append(userMessage)

      // add a pending message while we're waiting for a response from the backend
      let systemMessage = ChatMessage.pending(participant: .system)
      messages.append(systemMessage)

      do {
        let responseStream = try chat.sendMessageStream(text)

        for try await chunk in responseStream {
          if !chunk.functionCalls.isEmpty {
            try await handleFunctionCallsStreaming(chunk)
          } else {
            if let text = chunk.text {
              messages[messages.count - 1].message += text
              messages[messages.count - 1].pending = false
            }
          }
        }

      } catch {
        self.error = error
        print(error.localizedDescription)
        messages.removeLast()
      }
    }
  }

  private func internalSendMessage(_ text: String) async {
    chatTask?.cancel()

    chatTask = Task {
      busy = true
      defer {
        busy = false
      }

      // first, add the user's message to the chat
      let userMessage = ChatMessage(message: text, participant: .user)
      messages.append(userMessage)

      // add a pending message while we're waiting for a response from the backend
      let systemMessage = ChatMessage.pending(participant: .system)
      messages.append(systemMessage)

      do {
        let response = try await chat.sendMessage(text)

        if !response.functionCalls.isEmpty {
          try await handleFunctionCalls(response)
        } else {
          if let responseText = response.text {
            // replace pending message with backend response
            messages[messages.count - 1].message = responseText
            messages[messages.count - 1].pending = false
          }
        }
      } catch {
        self.error = error
        print(error.localizedDescription)
        messages.removeLast()
      }
    }
  }

  private func handleFunctionCallsStreaming(_ response: GenerateContentResponse) async throws {
    var functionResponses = [FunctionResponsePart]()

    for functionCall in response.functionCalls {
      switch functionCall.name {
      case "fetchWeather":
        guard case let .string(city) = functionCall.args["city"] else { fatalError() }
        guard case let .string(state) = functionCall.args["state"] else { fatalError() }
        guard case let .string(date) = functionCall.args["date"] else { fatalError() }

        functionResponses.append(
          FunctionResponsePart(
            name: functionCall.name,
            response: WeatherService.fetchWeather(city: city, state: state, date: date)
          )
        )

        let finalResponse = try await chat
          .sendMessageStream([ModelContent(role: "function", parts: functionResponses)])

        for try await chunk in finalResponse {
          guard let candidate = chunk.candidates.first else {
            fatalError("No candidate.")
          }

          for part in candidate.content.parts {
            if let textPart = part as? TextPart {
              messages[messages.count - 1].message += textPart.text
              messages[messages.count - 1].pending = false
            }
          }
        }
      default:
        print("Unknown function named \"\(functionCall.name)\".")
      }
    }
  }

  private func handleFunctionCalls(_ response: GenerateContentResponse) async throws {
    var functionResponses = [FunctionResponsePart]()

    for functionCall in response.functionCalls {
      switch functionCall.name {
      case "fetchWeather":
        guard case let .string(city) = functionCall.args["city"] else { fatalError() }
        guard case let .string(state) = functionCall.args["state"] else { fatalError() }
        guard case let .string(date) = functionCall.args["date"] else { fatalError() }

        functionResponses.append(
          FunctionResponsePart(
            name: functionCall.name,
            response: WeatherService.fetchWeather(city: city, state: state, date: date)
          )
        )

        let finalResponse = try await chat
          .sendMessage([ModelContent(role: "function", parts: functionResponses)])

        guard let candidate = finalResponse.candidates.first else {
          fatalError("No candidate.")
        }

        for part in candidate.content.parts {
          if let textPart = part as? TextPart {
            messages[messages.count - 1].message += textPart.text
            messages[messages.count - 1].pending = false
          }
        }
      default:
        print("Unknown function named \"\(functionCall.name)\".")
      }
    }
  }
}
