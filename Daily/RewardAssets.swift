//
//  RewardAssets.swift
//  Daily
//
//  Created by GitHub Copilot on 29/03/26.
//

import Foundation

enum RewardBonusKind {
    case rp
    case xp
    case both
}

struct RewardAsset: Identifiable {
    let id: String
    let title: String
    let animationName: String
    let unlockLevel: Int
    let price: Int
    let bonusText: String
    let bonusKind: RewardBonusKind
    let stageText: String
    let description: String

    static let catalog: [RewardAsset] = [
        RewardAsset(
            id: "adobe",
            title: "Adobe",
            animationName: "Adobe",
            unlockLevel: 2,
            price: 100,
            bonusText: "+1% reward chance",
            bonusKind: .both,
            stageText: "Early Game",
            description: "First exciting purchase that helps trigger more rewards early."
        ),
        RewardAsset(
            id: "salesforce",
            title: "Salesforce",
            animationName: "salesforce",
            unlockLevel: 5,
            price: 250,
            bonusText: "+15% RP per task",
            bonusKind: .rp,
            stageText: "Early-Mid Game",
            description: "Starts boosting earnings noticeably."
        ),
        RewardAsset(
            id: "meta",
            title: "Meta",
            animationName: "meta",
            unlockLevel: 8,
            price: 500,
            bonusText: "+2% reward chance",
            bonusKind: .both,
            stageText: "Mid Game",
            description: "Makes your random reward system feel more active."
        ),
        RewardAsset(
            id: "microsoft",
            title: "Microsoft",
            animationName: "microsoft",
            unlockLevel: 12,
            price: 900,
            bonusText: "+25% RP + XP",
            bonusKind: .both,
            stageText: "Late Game",
            description: "Big progression jump that feels powerful."
        ),
        RewardAsset(
            id: "google",
            title: "Google",
            animationName: "google",
            unlockLevel: 18,
            price: 1500,
            bonusText: "+4% reward chance, +40% RP + XP",
            bonusKind: .both,
            stageText: "End Game",
            description: "Massive multiplier across your progression rewards."
        )
    ]
}

extension UserProfile {
    var rewardChanceMultiplier: Double {
        var multiplier = 1.0
        if ownedRewardAssets.contains("adobe") { multiplier += 0.01 }
        if ownedRewardAssets.contains("meta") { multiplier += 0.02 }
        if ownedRewardAssets.contains("google") { multiplier += 0.04 }
        return multiplier
    }

    var taskRPMultiplier: Double {
        var multiplier = 1.0
        if ownedRewardAssets.contains("salesforce") { multiplier += 0.15 }
        if ownedRewardAssets.contains("microsoft") { multiplier += 0.25 }
        if ownedRewardAssets.contains("google") { multiplier += 0.40 }
        return multiplier
    }

    var rewardRPMultiplier: Double {
        var multiplier = 1.0
        if ownedRewardAssets.contains("microsoft") { multiplier += 0.25 }
        if ownedRewardAssets.contains("google") { multiplier += 0.40 }
        return multiplier
    }

    var xpMultiplier: Double {
        var multiplier = 1.0
        if ownedRewardAssets.contains("microsoft") { multiplier += 0.25 }
        if ownedRewardAssets.contains("google") { multiplier += 0.40 }
        return multiplier
    }
}
