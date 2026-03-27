//
//  ProfileView.swift
//  Daily
//
//  Created by GitHub Copilot on 27/03/26.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: TaskViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        LoopingLottieView(animationName: "rabbit")
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                            )

                        Text("Profile Animation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section("Stats") {
                    HStack {
                        Label {
                            Text("Level")
                        } icon: {
                            Image(systemName: "star.fill")
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Text("\(viewModel.level)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label {
                            Text("Streak")
                        } icon: {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Text("\(viewModel.streak) days")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label {
                            Text("Points")
                        } icon: {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                        }
                        Spacer()
                        Text("\(viewModel.dailyPoints)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
        }
    }
}
