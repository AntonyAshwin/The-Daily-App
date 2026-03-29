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
                Section("Overview") {
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

                    HStack(alignment: .top) {
                        Label {
                            Text("Active Bonuses")
                        } icon: {
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Reward: +\(viewModel.rewardChanceBonusPercent)%")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Text("XP: +\(viewModel.xpBonusPercent)%")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Text("RP: +\(viewModel.taskRPBonusPercent)%")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                        }
                    }
                }

                StreakShieldView(viewModel: viewModel)

                Section("Reward Assets") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(viewModel.rewardAssets) { asset in
                                rewardAssetCard(asset)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Shop")
        }
    }

    @ViewBuilder
    private func rewardAssetCard(_ asset: RewardAsset) -> some View {
        let isOwned = viewModel.isAssetOwned(asset)
        let canBuy = viewModel.canPurchaseAsset(asset)
        let isLocked = viewModel.userProfile.level < asset.unlockLevel

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(asset.title)
                    .font(.headline)
                Spacer()
                Text(asset.stageText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            LoopingLottieView(animationName: asset.animationName)
                .frame(height: 90)

            Text("Unlock L\(asset.unlockLevel) • \(asset.price) RP")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(asset.bonusText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color(for: asset.bonusKind))

            Text(asset.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Button {
                _ = viewModel.purchaseAsset(asset)
            } label: {
                Text(isOwned ? "Owned" : (isLocked ? "Locked" : (canBuy ? "Buy" : "Need RP")))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isOwned ? Color.green.opacity(0.2) : (canBuy ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2)))
                    .foregroundColor(isOwned ? .green : (canBuy ? .blue : .secondary))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isOwned || !canBuy)
        }
        .padding(12)
        .frame(width: 230, height: 300, alignment: .topLeading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isOwned ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }

    private func color(for kind: RewardBonusKind) -> Color {
        switch kind {
        case .rp:
            return .yellow
        case .xp:
            return .blue
        case .both:
            return .green
        }
    }
}
