//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

#if canImport(FluentUI_common)
import FluentUI_common
#endif
import SwiftUI
import UIKit

/// Properties available to customize the state of the Activity Indicator state
@objc public protocol MSFActivityIndicatorState {

    /// Sets the accessibility label for the Activity Indicator.
    var accessibilityLabel: String? { get set }

    /// Sets the color of the Activity Indicator.
    var color: UIColor? { get set }

    /// Defines whether the Activity Indicator is animating or stopped.
    var isAnimating: Bool { get set }

    /// Defines whether the Activity Indicator is visible when its animation stops.
    var hidesWhenStopped: Bool { get set }

    /// The MSFActivityIndicatorSize value used by the Activity Indicator.
    var size: MSFActivityIndicatorSize { get set }
}

/// View that represents the Activity Indicator.
public struct ActivityIndicator: View, TokenizedControlView {

    public typealias TokenSetKeyType = ActivityIndicatorTokenSet.Tokens
    @ObservedObject public var tokenSet: ActivityIndicatorTokenSet

    /// Creates the ActivityIndicator.
    /// - Parameter size: The MSFActivityIndicatorSize value used by the Activity Indicator.
    public init(size: MSFActivityIndicatorSize) {
        let state = MSFActivityIndicatorStateImpl(size: size)
        self.state = state
        self.tokenSet = ActivityIndicatorTokenSet(size: { state.size })
    }

    public var body: some View {
        tokenSet.update(fluentTheme)
        let side = ActivityIndicatorTokenSet.sideLength(size: state.size)
        let color: Color = {
            guard let stateUIColor = state.color else {
                return Color(tokenSet[.defaultColor].uiColor)
            }

            return Color(stateUIColor)
        }()
        let accessibilityLabel: String = {
            if let overriddenAccessibilityLabel = state.accessibilityLabel {
                return overriddenAccessibilityLabel
            }

            return state.isAnimating ?
                "Accessibility.ActivityIndicator.Animating.label".localized
                :
                "Accessibility.ActivityIndicator.Stopped.label".localized
        }()

#if DEBUG
        let accessibilityIdentifier: String = {
            let status: String = state.isAnimating ? "in progress" : "progress halted"
            return "Activity Indicator that is \(status) and size \(state.size.rawValue)"
        }()

        let semiRing = SemiRing(color: color,
                                thickness: tokenSet[.thickness].float,
                                accessibilityLabel: accessibilityLabel,
                                accessibilityIdentifier: accessibilityIdentifier)
#else
        let semiRing = SemiRing(color: color,
                                thickness: tokenSet[.thickness].float,
                                accessibilityLabel: accessibilityLabel)
#endif

        return semiRing
            .onAppear {
                if state.isAnimating {
                    startAnimation()
                }
            }
            .opacity(!state.isAnimating && state.hidesWhenStopped ? 0 : 1)
            .rotationEffect(.degrees(rotationAngle), anchor: .center)
            .onChange_iOS17(of: state.isAnimating) { newValue in
                newValue ? startAnimation() : stopAnimation()
            }
            .frame(width: side,
                   height: side,
                   alignment: .center)
    }

    @Environment(\.fluentTheme) var fluentTheme: FluentTheme
    @ObservedObject var state: MSFActivityIndicatorStateImpl
    @State var rotationAngle: Double = 0.0

    private struct SemiRing: View {
        var color: Color
        var thickness: CGFloat
        var accessibilityLabel: String
#if DEBUG
        var accessibilityIdentifier: String
#endif

        public var body: some View {
            Circle()
                .trim(from: semiRingStartFraction,
                      to: semiRingEndFraction)
                .stroke(style: StrokeStyle(lineWidth: thickness,
                                           lineCap: .round))
                .foregroundColor(color)
                .accessibilityElement(children: .ignore)
                .accessibility(addTraits: .isImage)
                .accessibility(label: Text(accessibilityLabel))
#if DEBUG
                .accessibility(identifier: accessibilityIdentifier)
#endif
        }

        private let semiRingStartFraction: CGFloat = 0.0
        private let semiRingEndFraction: CGFloat = 0.75
    }

    private func startAnimation() {
        stopAnimation()
        rotationAngle = Self.initialAnimationRotationAngle

        withAnimation(Animation.linear(duration: Self.animationDuration)
                                .repeatForever(autoreverses: false)) {
                                    rotationAngle = Self.finalAnimationRotationAngle
        }
    }

    private func stopAnimation() {
        rotationAngle = Self.finalAnimationRotationAngle

        withAnimation(Animation.linear(duration: 0)) {
            rotationAngle = Self.initialAnimationRotationAngle
        }
    }

    private static let animationDuration: Double = 0.75
    private static let initialAnimationRotationAngle: Double = 0.0
    private static let finalAnimationRotationAngle: Double = 360.0
}

/// Properties available to customize the state of the Activity Indicator
class MSFActivityIndicatorStateImpl: ControlState, MSFActivityIndicatorState {
    @Published var color: UIColor?
    @Published var isAnimating: Bool = false
    @Published var hidesWhenStopped: Bool = true
    @Published var size: MSFActivityIndicatorSize

    init(size: MSFActivityIndicatorSize) {
        self.size = size
        super.init()
    }
}
