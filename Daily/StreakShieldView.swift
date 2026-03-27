//
//  StreakShieldView.swift
//  Daily
//
//  Created by GitHub Copilot on 28/03/26.
//

import SwiftUI

struct StreakShieldView: View {
    @ObservedObject var viewModel: TaskViewModel
    @State private var purchaseMessage: String?
    @State private var showMessage = false

    var body: some View {
        Group {
            Section("⚔️ Streak Shield System") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your Shields")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.shieldsDisplay)
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Shields protect your streak if you miss a day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Buy Shield") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Shield")
                            .font(.headline)
                        Text("Protect your streak from 1 missed day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(viewModel.shieldCostDisplay) RP")
                            .font(.headline)
                            .foregroundColor(.yellow)
                        Button(action: buyShield) {
                            Text("Buy")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .disabled(!viewModel.canBuyShield)
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Section("Upgrade Shield Capacity") {
                if viewModel.userProfile.shieldCapacity < 3 {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Capacity: Level \(viewModel.userProfile.shieldCapacity + 1)")
                                .font(.headline)
                            Text("Hold up to \(viewModel.userProfile.shieldCapacity + 1) shields")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(viewModel.nextUpgradeCost) RP")
                                .font(.headline)
                                .foregroundColor(.yellow)
                            Button(action: upgradeCapacity) {
                                Text("Upgrade")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .disabled(!viewModel.canUpgradeCapacity)
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    HStack {
                        Text("Max Capacity Reached")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .alert("Shield Purchased!", isPresented: $showMessage) {
            Button("OK") { }
        } message: {
            Text(purchaseMessage ?? "")
        }
    }
    
    private func buyShield() {
        if viewModel.buyShield() {
            purchaseMessage = "Shield purchased! You now have \(viewModel.shieldsDisplay) shields."
            showMessage = true
        }
    }
    
    private func upgradeCapacity() {
        if viewModel.upgradeCapacity() {
            purchaseMessage = "Capacity upgraded to \(viewModel.userProfile.shieldCapacity)!"
            showMessage = true
        }
    }
}
