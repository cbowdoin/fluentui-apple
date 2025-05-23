//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

#if canImport(FluentUI_common)
import FluentUI_common
#endif
import SwiftUI
import UIKit

/// Pre-defined sizes of the Activity Indicator.
@objc public enum MSFActivityIndicatorSize: Int, CaseIterable {
    case xSmall
    case small
    case medium
    case large
    case xLarge
}

public enum ActivityIndicatorToken: Int, TokenSetKey {
    /// The default color of the Activity Indicator.
    case defaultColor

    /// The value for the thickness of the ActivityIndicator ring.
    case thickness
}

/// Design token set for the `ActivityIndicator` control.
public class ActivityIndicatorTokenSet: ControlTokenSet<ActivityIndicatorToken> {
    init(size: @escaping () -> MSFActivityIndicatorSize) {
        self.size = size
        super.init { [size] token, _ in
            switch token {
            case .defaultColor:
                return .uiColor {
                    UIColor(light: GlobalTokens.neutralColor(.grey56),
                            dark: GlobalTokens.neutralColor(.grey72))
                }

            case .thickness:
                return .float {
                    switch size() {
                    case .xSmall, .small:
                        return 1
                    case .medium:
                        return 2
                    case .large:
                        return 3
                    case .xLarge:
                        return 4
                    }
                }
            }
        }
    }

    /// MSFActivityIndicatorSize enumeration value that will define pre-defined values for side and thickness.
    var size: () -> MSFActivityIndicatorSize

}

// MARK: - Constants

extension ActivityIndicatorTokenSet {
    static func sideLength(size: MSFActivityIndicatorSize) -> CGFloat {
        switch size {
        case .xSmall:
            return 12
        case .small:
            return 16
        case .medium:
            return 24
        case .large:
            return 32
        case .xLarge:
            return 36
        }
    }
}
