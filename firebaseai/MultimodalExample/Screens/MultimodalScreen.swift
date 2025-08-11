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
import MarkdownUI
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct MultimodalScreen: View {
  let firebaseService: FirebaseAI
  @StateObject var viewModel: MultimodalViewModel

  @State private var showingPhotoPicker = false
  @State private var showingFilePicker = false
  @State private var showingLinkDialog = false
  @State private var linkText = ""
  @State private var linkMimeType = ""
  @State private var selectedPhotoItems = [PhotosPickerItem]()

  init(firebaseService: FirebaseAI, sample: Sample? = nil) {
    self.firebaseService = firebaseService
    _viewModel =
      StateObject(wrappedValue: MultimodalViewModel(firebaseService: firebaseService,
                                                    sample: sample))
  }

  var body: some View {
    NavigationStack {
      ConversationView(messages: $viewModel.messages,
                       userPrompt: viewModel.initialPrompt) { message in
        MessageView(message: message)
      }
      .attachmentActions {
        Button(action: showLinkDialog) {
          Label("Link", systemImage: "link")
        }
        Button(action: showFilePicker) {
          Label("File", systemImage: "doc.text")
        }
        Button(action: showPhotoPicker) {
          Label("Photo", systemImage: "photo.on.rectangle.angled")
        }
      }
      .pendingAttachments(viewModel.attachments)
      .onAttachmentRemove { attachment in
        viewModel.removeAttachment(attachment)
      }
      .errorState(viewModel.error)
      .onSendMessage { prompt in
        Task {
          await viewModel.sendMessage(prompt, streaming: true)
        }
      }
      .photosPicker(
        isPresented: $showingPhotoPicker,
        selection: $selectedPhotoItems,
        maxSelectionCount: 5,
        matching: .any(of: [.images, .videos])
      )
      .fileImporter(
        isPresented: $showingFilePicker,
        allowedContentTypes: [.pdf, .audio],
        allowsMultipleSelection: true
      ) { result in
        handleFileImport(result)
      }
      .alert("Add Web URL", isPresented: $showingLinkDialog) {
        TextField("Enter URL", text: $linkText)
        TextField("Enter mimeType", text: $linkMimeType)
        Button("Add") {
          handleLinkAttachment()
        }
        Button("Cancel", role: .cancel) {
          linkText = ""
          linkMimeType = ""
        }
      }
    }
    .onChange(of: selectedPhotoItems) { _, newItems in
      handlePhotoSelection(newItems)
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

  private func newChat() {
    viewModel.startNewChat()
  }

  private func showPhotoPicker() {
    showingPhotoPicker = true
  }

  private func showFilePicker() {
    showingFilePicker = true
  }

  private func showLinkDialog() {
    showingLinkDialog = true
  }

  private func handlePhotoSelection(_ items: [PhotosPickerItem]) {
    Task {
      for item in items {
        if let attachment = await MultimodalAttachment.fromPhotosPickerItem(item) {
          await MainActor.run {
            viewModel.addAttachment(attachment)
          }
        }
      }
      await MainActor.run {
        selectedPhotoItems = []
      }
    }
  }

  private func handleFileImport(_ result: Result<[URL], Error>) {
    switch result {
    case let .success(urls):
      Task {
        for url in urls {
          if let attachment = await MultimodalAttachment.fromFilePickerItem(from: url) {
            await MainActor.run {
              viewModel.addAttachment(attachment)
            }
          }
        }
      }
    case let .failure(error):
      viewModel.handleError(error)
    }
  }

  private func handleLinkAttachment() {
    guard !linkText.isEmpty, let url = URL(string: linkText) else {
      return
    }

    let trimmedMime = linkMimeType.trimmingCharacters(in: .whitespacesAndNewlines)
    Task {
      if let attachment = await MultimodalAttachment.fromURL(url, mimeType: trimmedMime) {
        await MainActor.run {
          viewModel.addAttachment(attachment)
        }
      }
      await MainActor.run {
        linkText = ""
        linkMimeType = ""
      }
    }
  }
}

#Preview {
  MultimodalScreen(firebaseService: FirebaseAI.firebaseAI())
}
