//
//  AboutView.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image("MenuBarIcon")
                .resizable()
                .frame(width: 48, height: 48)

            Text(AppConstants.appName)
                .font(.title.bold())

            Text("v\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("AI usage tracker & prompt vault\nfor your macOS menu bar")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Link("GitHub", destination: URL(string: AppConstants.githubURL)!)
                .font(.subheadline)

            Text("MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 280)
    }
}

#Preview {
    AboutView()
}
