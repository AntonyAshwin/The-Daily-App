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
                StreakShieldView(viewModel: viewModel)
                
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
