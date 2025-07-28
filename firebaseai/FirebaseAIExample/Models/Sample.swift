// Copyright 2025 Google LLC
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

import Foundation

struct Sample: Identifiable {
  let id = UUID()
  let title: String
  let description: String
  let useCase: UseCase
}

extension Sample {
  static let samples: [Sample] = [
    // Text
    Sample(
      title: "Travel tips", 
      description: "The user wants the model to help a new traveler" +
                " with travel tips", 
      useCase: .text),
    Sample(title: "Chatbot recommendations for courses", 
      description: "A chatbot suggests courses for a performing arts program.",
      useCase: .text),
    // Image
    Sample(title: "Blog post creator", 
      description: "Create a blog post from an image file stored in Cloud Storage.",
      useCase: .image),
    Sample(title: "Imagen 3 - image generation", 
      description: "Generate images using Imagen 3",
      useCase: .image),
    Sample(title: "Gemini 2.0 Flash - image generation", 
      description: "Generate and/or edit images using Gemini 2.0 Flash",
      useCase: .image),
    // Video
    Sample(title: "Hashtags for a video", 
      description: "Generate hashtags for a video ad stored in Cloud Storage.",
      useCase: .video),
    Sample(title: "Summarize video", 
      description: "Summarize a video and extract important dialogue.",
      useCase: .video),
    // Audio
    Sample(title: "Audio Summarization", 
      description: "Summarize an audio file",
      useCase: .audio),
    Sample(title: "Translation from audio (Vertex AI)", 
      description: "Translate an audio file stored in Cloud Storage",
      useCase: .audio),
    // Document
    Sample(
      title: "Document comparison", 
      description: "Compare the contents of 2 documents." +
                " Only supported by the Vertex AI Gemini API because the documents are stored in Cloud Storage",
      useCase: .document),
    // Function Calling
    Sample(
      title: "Weather Chat", 
      description: "Use function calling to get the weather conditions" +
                " for a specific US city on a specific date.",
      useCase: .functionCalling)
  ]

  static var sample = samples[0]
}
