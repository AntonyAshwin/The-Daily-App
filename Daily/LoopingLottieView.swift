//
//  LoopingLottieView.swift
//  Daily
//
//  Created by GitHub Copilot on 27/03/26.
//

import SwiftUI

#if canImport(Lottie)
import Lottie
import UIKit
#endif

struct LoopingLottieView: View {
    let animationName: String

    var body: some View {
        #if canImport(Lottie)
        LottieViewRepresentable(animationName: animationName)
        #else
        ZStack {
            Circle()
                .fill(Color(UIColor.systemGray5))
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
        }
        #endif
    }
}

#if canImport(Lottie)
private struct LottieViewRepresentable: UIViewRepresentable {
    let animationName: String

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear

        let animation =
            LottieAnimation.named(animationName, bundle: .main)
            ?? LottieAnimation.named(animationName, bundle: .main, subdirectory: "Rewards")
        let animationView = LottieAnimationView(animation: animation)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.play()

        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let animationView = uiView.subviews.first as? LottieAnimationView else {
            return
        }

        if !animationView.isAnimationPlaying {
            animationView.play()
        }
    }
}
#endif
