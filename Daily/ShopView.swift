//
//  ShopView.swift
//  Daily
//
//  Created by GitHub Copilot on 28/03/26.
//

import SwiftUI

struct ShopView: View {
    @ObservedObject var viewModel: TaskViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Coming Soon") {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Shop Items")
                                .font(.headline)
                            Text("Spend your RP to customize your profile")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("🔒")
                    }
                }
                
                Section("Your Balance") {
                    HStack {
                        Label {
                            Text("Current RP")
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
            .navigationTitle("Shop")
        }
    }
}
