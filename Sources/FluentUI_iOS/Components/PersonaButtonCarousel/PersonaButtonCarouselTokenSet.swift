//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

#if canImport(FluentUI_common)
import FluentUI_common
#endif
import UIKit

/// Representation of design tokens to controls at runtime which interfaces with the Design Token System auto-generated code.
/// Updating these properties causes the SwiftUI controls to update its view automatically.
public class PersonaButtonCarouselTokenSet: ControlTokenSet<PersonaButtonCarouselTokenSet.Tokens> {
    public enum Tokens: TokenSetKey {
        /// The background color for the `PersonaButtonCarousel`.
        case backgroundColor
    }

    init() {
        super.init { token, theme in
            switch token {
            case .backgroundColor:
                return .uiColor { theme.color(.background1) }
            }
        }
    }
}
