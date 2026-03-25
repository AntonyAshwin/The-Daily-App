//
//  Haptics.swift
//  Daily
//
//  Created by Ashwin, Antony on 26/03/26.
//

import UIKit

enum Haptics {
    static func taskProgress(isCompleted: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(isCompleted ? .success : .warning)
    }

    static func pageChange() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
