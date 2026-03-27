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
                            .frame(width: 170, height: 170)

                        TextField("Your Name", text: $viewModel.profileName)
                            .multilineTextAlignment(.center)
                            .font(.headline)
                            .textFieldStyle(.plain)
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
