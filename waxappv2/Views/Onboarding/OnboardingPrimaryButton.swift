//
//  OnboardingPrimaryButton.swift
//  waxappv2
//
//  Created by Herman Henriksen on 08/01/2026.
//
import SwiftUI

struct OnboardingPrimaryButton: View {
  let title: String
  let isWorking: Bool
  let action: () -> Void

  init(title: String, isWorking: Bool = false, action: @escaping () -> Void) {
    self.title = title
    self.isWorking = isWorking
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        if isWorking {
          ProgressView()
            .tint(.white)
        }
        Text(title)
          .bold()
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(Color.blue)
      .foregroundColor(.white)
      .cornerRadius(10)
    }
    .padding(.horizontal, 40)
    .padding(.bottom, 24)
  }
}
