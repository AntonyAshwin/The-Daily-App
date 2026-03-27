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

                        TextField("Your Name", text: $viewModel.userProfile.name)
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
                        Text("\(viewModel.userProfile.level)")
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
                        Text("\(viewModel.userProfile.streak) days")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label {
                            Text("RP")
                        } icon: {
                            Image(systemName: "banknote.fill")
                                .foregroundColor(.yellow)
                        }
                        Spacer()
                        Text("\(viewModel.totalPoints)")
                            .font(.headline)
                            .foregroundColor(.yellow)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
        }
    }
}
