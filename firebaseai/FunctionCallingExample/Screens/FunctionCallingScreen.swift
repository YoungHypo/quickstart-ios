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

import SwiftUI

struct FunctionCallingScreen: View {
  let firebaseService: FirebaseAI
  @StateObject var viewModel: FunctionCallingViewModel

  init(firebaseService: FirebaseAI, sample: Sample? = nil) {
    self.firebaseService = firebaseService
    _viewModel =
      StateObject(wrappedValue: FunctionCallingViewModel(firebaseService: firebaseService,
                                              sample: sample))
  }

  var body: some View {
    NavigationStack {
      ConversationView(messages: $viewModel.messages,
                       userPrompt: viewModel.initialPrompt) { message in
        MessageView(message: message)
      }
      .disableAttachments()
      .errorState(viewModel.error)
      .onSendMessage { prompt in
        Task {
          await viewModel.sendMessage(prompt, streaming: true)
        }
      }
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: newChat) {
            Image(systemName: "square.and.pencil")
          }
        }
      }
      .navigationTitle(viewModel.title)
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func newChat() {
    viewModel.startNewChat()
  }
}

struct FunctionCallingScreen_Previews: PreviewProvider {
  struct ContainerView: View {
    @StateObject var viewModel = FunctionCallingViewModel(firebaseService: FirebaseAI
      .firebaseAI(), sample: nil) // Example service init

    var body: some View {
      FunctionCallingScreen(firebaseService: FirebaseAI.firebaseAI())
        .onAppear {
          viewModel.messages = ChatMessage.samples
        }
    }
  }

  static var previews: some View {
    NavigationStack {
      FunctionCallingScreen(firebaseService: FirebaseAI.firebaseAI())
    }
  }
}
