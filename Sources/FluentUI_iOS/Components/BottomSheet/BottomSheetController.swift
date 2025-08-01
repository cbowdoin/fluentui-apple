//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

#if canImport(FluentUI_common)
import FluentUI_common
#endif
import UIKit

@objc(MSFBottomSheetControllerDelegate)
public protocol BottomSheetControllerDelegate: AnyObject {

    /// Called after a transition to a new expansion state completes.
    ///
    /// External changes to`isExpanded` or `isHidden` will not trigger this callback.
    /// - Parameters:
    ///   - bottomSheetController: The caller object.
    ///   - expansionState: The expansion state that the sheet moved to.
    ///   - interaction: The user interaction that caused the state change.
    @objc optional func bottomSheetController(_ bottomSheetController: BottomSheetController,
                                              didMoveTo expansionState: BottomSheetExpansionState,
                                              interaction: BottomSheetInteraction)

    /// Called before a transition to a new expansion state starts.
    ///
    /// External changes to `isExpanded` or `isHidden` will not trigger this callback.
    /// - Parameters:
    ///   - bottomSheetController: The caller object.
    ///   - expansionState: The expansion state that the sheet will move to.
    ///   - interaction: The user interaction that caused the state change.
    @objc optional func bottomSheetController(_ bottomSheetController: BottomSheetController,
                                              willMoveTo expansionState: BottomSheetExpansionState,
                                              interaction: BottomSheetInteraction)

    /// Called when `collapsedHeightInSafeArea` changes.
    @objc optional func bottomSheetControllerCollapsedHeightInSafeAreaDidChange(_ bottomSheetController: BottomSheetController)

    /// Called when the user initiates the pan gesture
    ///
    ///    - Parameters:
    ///    - bottomSheetController: The caller object.
    ///    - expansionState: The expansion state that the sheet moved from
    @objc optional func bottomSheetStartedPan(_ bottomSheetController: BottomSheetController, from expansionState: BottomSheetExpansionState)
}

/// Interactions that can trigger a state change.
@objc public enum BottomSheetInteraction: Int {
    case noUserAction // No user action, used for events not triggered by users
    case swipe // Swipe on the sheet view
    case resizingHandleTap // Tap on the sheet resizing handle
    case dimmingViewTap // Tap on the dimming view
}

/// Defines the position the sheet is currently in
@objc public enum BottomSheetExpansionState: Int {
    case expanded // Sheet is fully expanded
    case partial // Sheet is partially expanded
    case collapsed // Sheet is collapsed
    case hidden // Sheet is hidden (fully off-screen)
    case transitioning // Sheet is between states, only used during user interaction / animation
}

/// Defines where the sheet should be postionioned relative to the screen space
@objc(MSFBottomSheetAnchorEdge) public enum BottomSheetAnchorEdge: Int {
    case center // Sheet is centered on the screen
    case leading // Sheet is constrained to the leading edge
    case trailing // Sheet is constrained to the trailing edge
}

@objc(MSFBottomSheetController)
public class BottomSheetController: UIViewController, Shadowable, TokenizedControl {

    /// Initializes the bottom sheet controller
    /// - Parameters:
    ///   - headerContentView: Top part of the sheet content that is visible in both collapsed and expanded state.
    ///   - expandedContentView: Sheet content below the header which is only visible when the sheet is expanded.
    ///   - shouldShowDimmingView: Indicates if the main content is dimmed when the sheet is expanded.
    ///   - style: The style override for the BottomSheet's background material.
    @objc public init(headerContentView: UIView? = nil,
                      expandedContentView: UIView,
                      shouldShowDimmingView: Bool = true,
                      style: BottomSheetControllerStyle) {
        self.headerContentView = headerContentView
        self.expandedContentView = expandedContentView
        self.shouldShowDimmingView = shouldShowDimmingView
        self.style = style
        super.init(nibName: nil, bundle: nil)
    }

    /// Initializes the bottom sheet controller
    /// - Parameters:
    ///   - headerContentView: Top part of the sheet content that is visible in both collapsed and expanded state.
    ///   - expandedContentView: Sheet content below the header which is only visible when the sheet is expanded.
    ///   - shouldShowDimmingView: Indicates if the main content is dimmed when the sheet is expanded.
    @objc public convenience init(headerContentView: UIView? = nil, expandedContentView: UIView, shouldShowDimmingView: Bool = true) {
        self.init(headerContentView: headerContentView,
                  expandedContentView: expandedContentView,
                  shouldShowDimmingView: shouldShowDimmingView,
                  style: .primary)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        preconditionFailure("init(coder:) has not been implemented")
    }

    /// Top part of the sheet content that is visible in both collapsed and expanded state.
    @objc public let headerContentView: UIView?

    /// Sheet content below the header which is only visible when the sheet is expanded.
    @objc public let expandedContentView: UIView

    /// A scroll view in `expandedContentView`'s view hierarchy.
    /// Provide this to ensure the bottom sheet pan gesture recognizer coordinates with the scroll view to enable scrolling based on current bottom sheet position and content offset.
    @objc open var hostedScrollView: UIScrollView?

    /// Indicates if the bottom sheet is expandable.
    @objc open var isExpandable: Bool = true {
        didSet {
            if isExpandable != oldValue {
                resizingHandleView.isHidden = !isExpandable
                panGestureRecognizer.isEnabled = isExpandable
                if isViewLoaded {
                    move(to: .collapsed, animated: false)
                }

#if DEBUG
                if isExpandable {
                    bottomSheetView.accessibilityIdentifier?.append(", a resizing handle")
                } else {
                    bottomSheetView.accessibilityIdentifier = bottomSheetView.accessibilityIdentifier?.replacingOccurrences(of: ", a resizing handle", with: "")
                }
#endif
            }
        }
    }

    /// Indicates if the bottom sheet view is hidden.
    ///
    /// Changes to this property are animated. When hiding, new value is reflected after the animation completes.
    @objc open var isHidden: Bool {
        get {
            return bottomSheetView.isHidden
        }
        set {
            setIsHidden(newValue)
        }
    }

    /// Indicates if the sheet height is flexible.
    ///
    /// When set to `false`, the sheet height is static and always corresponds to the height of the maximum expansion state.
    /// Interacting with the sheet will only vertically translate it, moving it partially on/off-screen.
    ///
    /// When set to `true`, moving the sheet beyond the `.collapsed` state will resize it.
    ///
    /// Use flexible height if you have views attached to the bottom of `expandedContentView` that should always be visible.
    @objc open var isFlexibleHeight: Bool = false {
        didSet {
            guard isViewLoaded else {
                return
            }
            view.setNeedsLayout()
        }
    }

    /// Height of `headerContentView`.
    ///
    /// Setting this is required when the `headerContentView` is non-nil.
    @objc open var headerContentHeight: CGFloat = 0 {
        didSet {
            guard headerContentHeight != oldValue && isViewLoaded else {
                return
            }
            completeAnimationsIfNeeded(skipToEnd: true)
            headerContentViewHeightConstraint?.constant = headerContentHeight
        }
    }

    /// Preferred height of `expandedContentView`.
    ///
    /// The default value is 0, which results in a full screen sheet expansion.
    @objc open var preferredExpandedContentHeight: CGFloat = 0 {
        didSet {
            guard preferredExpandedContentHeight != oldValue && isViewLoaded else {
                return
            }
            completeAnimationsIfNeeded(skipToEnd: true)
            view.setNeedsLayout()
        }
    }

    /// A string to optionally customize the accessibility label of the bottom sheet handle.
    /// The message should convey the "Expand" action and will be used when the bottom sheet is collapsed.
    @objc public var handleExpandCustomAccessibilityLabel: String? {
        didSet {
            updateResizingHandleViewAccessibility(for: currentExpansionState)
        }
    }

    /// A string to optionally customize the accessibility label of the bottom sheet handle.
    /// The message should convey the "Collapse" action and will be used when the bottom sheet is expanded.
    @objc public var handleCollapseCustomAccessibilityLabel: String? {
        didSet {
            updateResizingHandleViewAccessibility(for: currentExpansionState)
        }
    }

    /// Indicates if the bottom sheet is expanded.
    ///
    /// Changes to this property are animated. A new value is reflected in the getter only after the animation completes.
    @objc open var isExpanded: Bool {
        get {
            return currentExpansionState == .expanded
        }
        set {
            setIsExpanded(newValue)
        }
    }

    /// A closure for resolving the desired collapsed sheet height given a resolution context.
    @objc open var collapsedHeightResolver: ((ContentHeightResolutionContext) -> CGFloat)? {
        didSet {
            if isViewLoaded {
                invalidateSheetSize()
            }
        }
    }

    /// A closure for resolving the desired partially expanded sheet height given a resolution context.
    @objc open var partialHeightResolver: ((ContentHeightResolutionContext) -> CGFloat)? {
        didSet {
            if isViewLoaded {
                invalidateSheetSize()
            }
        }
    }

    /// Height of the top portion of the content view that should be visible when the bottom sheet is collapsed.
    ///
    /// When set to 0, `headerContentHeight` will be used.
    @objc open var collapsedContentHeight: CGFloat = 0 {
        didSet {
            guard collapsedContentHeight != oldValue && isViewLoaded else {
                return
            }
            completeAnimationsIfNeeded(skipToEnd: true)
            view.setNeedsLayout()
        }
    }

    /// Indicates if the content should be hidden when the sheet is collapsed
    @objc open var shouldHideCollapsedContent: Bool = true {
        didSet {
            guard shouldHideCollapsedContent != oldValue && isViewLoaded else {
                return
            }
            view.setNeedsLayout()
        }
    }

    /// Indicates if the sheet should always fill the available width. The default value is true.
    @objc open var shouldAlwaysFillWidth: Bool = true {
        didSet {
            guard shouldAlwaysFillWidth != oldValue && isViewLoaded else {
                return
            }
            view.setNeedsLayout()

#if DEBUG
                if shouldAlwaysFillWidth {
                    bottomSheetView.accessibilityIdentifier?.append(", filled width")
                } else {
                    bottomSheetView.accessibilityIdentifier = bottomSheetView.accessibilityIdentifier?.replacingOccurrences(of: ", filled width", with: "")
                }
#endif
        }
    }

    /// Setting this property  will result in the sheet trying to be as close to this width as possible.
    /// If the declared width is too large it will roll back to the maximum width
    @objc open var preferredWidth: CGFloat = 0 {
        didSet {
            let shouldInvalidateLayout = (preferredWidth != oldValue) && isViewLoaded
            if shouldInvalidateLayout {
                view.setNeedsLayout()
            }
        }
    }

    /// Represents where the sheet should appear on the screen.
    /// Defaults to being centered
    @objc open var anchoredEdge: BottomSheetAnchorEdge = .center {
        didSet {
            guard anchoredEdge != oldValue && isViewLoaded else {
                return
            }
            view.setNeedsLayout()
        }
    }

    /// When enabled, users will be able to move the sheet to the hidden state by swiping down.
    @objc open var allowsSwipeToHide: Bool = false

    /// Current height of the portion of a collapsed sheet that's in the safe area.
    @objc public private(set) var collapsedHeightInSafeArea: CGFloat = 0 {
        didSet {
            guard collapsedHeightInSafeArea != oldValue else {
                return
            }
            delegate?.bottomSheetControllerCollapsedHeightInSafeAreaDidChange?(self)
        }
    }

    /// A layout guide that covers the on-screen portion of the sheet view.
    @objc public let sheetLayoutGuide = UILayoutGuide()

    /// The object that acts as the delegate of the bottom sheet.
    @objc open weak var delegate: BottomSheetControllerDelegate?

    /// Height of the resizing handle
    @objc public static var resizingHandleHeight: CGFloat {
        return ResizingHandleView.height
    }

    // MARK: - Parametrized setters

    /// Sets the `isExpanded` property with a completion handler.
    /// - Parameters:
    ///   - isExpanded: The new value.
    ///   - animated: Indicates if the change should be animated. The default value is `true`.
    ///   - completion: Closure to be called when the state change completes.
    @objc public func setIsExpanded(_ isExpanded: Bool, animated: Bool = true, completion: ((_ isFinished: Bool) -> Void)? = nil) {
        guard isExpanded != self.isExpanded, !isHiddenOrHiding, isExpandable else {
            return
        }

        let targetExpansionState: BottomSheetExpansionState = isExpanded ? .expanded : .collapsed
        if isViewLoaded {
            move(to: targetExpansionState, animated: animated, shouldNotifyDelegate: false) { finalPosition in
                completion?(finalPosition == .end)
            }
        } else {
            currentExpansionState = targetExpansionState
            completion?(true)
        }
    }

    /// Changes the `isHidden` state with a completion handler.
    /// - Parameters:
    ///   - isHidden: The new value.
    ///   - animated: Indicates if the change should be animated. The default value is `true`.
    ///   - completion: Closure to be called when the state change completes.
    @objc public func setIsHidden(_ isHidden: Bool, animated: Bool = true, completion: ((_ isFinished: Bool) -> Void)? = nil) {
        if isHidden {
            dismissSheet(animated: animated, completion: completion)
        } else {
            presentSheet(expandedState: .collapsed, animated: animated, completion: completion)
        }

    }

    /// Presents the bottom sheet view
    /// - Parameters:
    ///   - expandedState: The state the bottom sheet should expand to when presented
    ///   - animated: Indicates if the change should be animated. The default value is `true`.
    ///   - completion: Closure to be called when the state change completes.
    @objc public func presentSheet(expandedState: BottomSheetExpansionState, animated: Bool = true, completion: ((_ isFinished: Bool) -> Void)? = nil) {
        let finishedState: BottomSheetExpansionState

        switch expandedState {
        case .collapsed:
            finishedState = .collapsed
        case .expanded:
            finishedState = isExpandable ? .expanded : .collapsed
        case .partial:
            finishedState = isExpandable && supportsPartialExpansion ? .partial : .collapsed
        // Safe fallback for any invalid target states
        default:
            finishedState = .collapsed
        }

        if isViewLoaded {
            move(to: finishedState, animated: animated, allowUnhiding: true) { finalPosition in
                completion?(finalPosition == .end)
            }
        } else {
            currentExpansionState = expandedState
            completion?(true)
        }
    }

    /// Dismiss the bottom the bottom sheet view
    /// - Parameters:
    ///   - animated: Indicates if the change should be animated. The default value is `true`.
    ///   - completion: Closure to be called when the state change completes.
    @objc public func dismissSheet(animated: Bool = true, completion: ((_ isFinished: Bool) -> Void)? = nil) {
        if isViewLoaded {
            move(to: .hidden, animated: animated, allowUnhiding: true) { finalPosition in
                completion?(finalPosition == .end)
            }
        } else {
            currentExpansionState = .hidden
            completion?(true)
        }
    }

    /// Initiates an interactive `isHidden` state change driven by the returned `UIViewPropertyAnimator`.
    ///
    /// The returned animator comes preloaded with all the animations required to reach the target `isHidden` state.
    ///
    /// You can modify the `fractionComplete` property of the animator to interactively drive the animation in the paused state.
    /// You can also change the `isReversed` property to swap the start and target `isHidden` states.
    ///
    /// When you are done driving the animation interactively, you must call `startAnimation` on the animator to let the animation resume
    /// from the current value of `fractionComplete`.
    /// - Parameters:
    ///   - isHidden: The target state.
    ///   - completion: Closure to be called when the state change completes.
    /// - Returns: A `UIViewPropertyAnimator`. The associated animations start in a paused state.
    @objc public func prepareInteractiveIsHiddenChange(_ isHidden: Bool, completion: ((_ finalPosition: UIViewAnimatingPosition) -> Void)? = nil) -> UIViewPropertyAnimator? {
        guard isViewLoaded else {
            return nil
        }

        completeAnimationsIfNeeded(skipToEnd: true)

        var animator: UIViewPropertyAnimator?
        if isHidden != self.isHidden {
            let initialState: BottomSheetExpansionState = isHidden ? .collapsed : .hidden
            let targetState: BottomSheetExpansionState = isHidden ? .hidden : .collapsed

            move(to: initialState, animated: false, allowUnhiding: true)
            animator = stateChangeAnimator(to: targetState)

            currentStateChangeAnimator = animator
            animator?.addCompletion { finalPosition in
                completion?(finalPosition)
            }
        }

        return animator
    }

    /// Forces a call to `collapsedHeightResolver` to fetch the latest desired sheet height.
    @objc public func invalidateSheetSize() {
        guard isViewLoaded else {
            return
        }

        cachedResolvedDynamicSheetHeights = nil

        // If we are animating to one of the affected states, we need to retarget the animation.
        if targetExpansionState == .collapsed || (currentExpansionState == .collapsed && targetExpansionState == nil) {
            move(to: .collapsed)
        } else if supportsPartialExpansion && (targetExpansionState == .partial || (currentExpansionState == .partial && targetExpansionState == nil)) {
            move(to: .partial)
        }
    }

    // MARK: - View loading

    // View hierarchy
    // self.view - BottomSheetPassthroughView (full overlay area)
    // |--dimmingView (spans self.view)
    // |--bottomSheetView (sheet shadow)
    // |  |--UIStackView (round corner mask)
    // |  |  |--resizingHandleView
    // |  |  |--headerContentView
    // |  |  |--expandedContentView
    // |--overflowView
    public override func loadView() {
        view = BottomSheetPassthroughView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addLayoutGuide(sheetLayoutGuide)

        var constraints = [NSLayoutConstraint]()

        if shouldShowDimmingView {
            view.addSubview(dimmingView)
            constraints.append(contentsOf: [
                dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
                dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        view.addSubview(bottomSheetView)
        bottomSheetView.isHidden = currentExpansionState == .hidden

        // The non-zero frame here ensures the layout engine won't complain if it tries to calculate
        // sheet content layout before view.bounds is set to a non-zero rect.
        // We will set the sheet frame to a more meaningful rect after the first layout pass.
        bottomSheetView.frame = CGRect(x: 0, y: 0, width: Constants.minSheetWidth, height: expandedSheetHeight)

        overflowView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overflowView)

        if let headerContentView = headerContentView {
            let heightConstraint = headerContentView.heightAnchor.constraint(equalToConstant: headerContentHeight)
            constraints.append(heightConstraint)
            headerContentViewHeightConstraint = heightConstraint
        }

        constraints.append(contentsOf: [
            overflowView.leadingAnchor.constraint(equalTo: bottomSheetView.leadingAnchor),
            overflowView.trailingAnchor.constraint(equalTo: bottomSheetView.trailingAnchor),
            overflowView.heightAnchor.constraint(equalToConstant: Constants.Spring.overflowHeight),
            overflowView.topAnchor.constraint(equalTo: bottomSheetView.bottomAnchor)
        ])

        constraints.append(contentsOf: makeLayoutGuideConstraints())

        NSLayoutConstraint.activate(constraints)

        // Update appearance whenever `tokenSet` changes.
        tokenSet.registerOnUpdate(for: view) { [weak self] in
            self?.updateAppearance()
        }
    }

    // MARK: - Shadow Layers
    public var ambientShadow: CALayer?
    public var keyShadow: CALayer?

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        tokenSet.update(fluentTheme)

        updateResizingHandleViewAccessibility(for: currentExpansionState)
    }

    public override func viewDidLayoutSubviews() {
        let newHeight = view.bounds.height
        if currentRootViewHeight != newHeight && currentExpansionState == .transitioning {
            // The view height has changed and we can't guarantee the animation target frame is valid anymore.
            // Let's complete animations and cancel ongoing gestures to guarantee we end up in a good state.
            completeAnimationsIfNeeded(skipToEnd: true)

            if panGestureRecognizer.state != .possible {
                panGestureRecognizer.state = .cancelled
            }
        }
        currentRootViewHeight = newHeight

        // In the transitioning state a pan gesture or an animator temporarily owns the sheet frame updates,
        // so to avoid interfering we won't update the frame here.
        if currentExpansionState != .transitioning {
            bottomSheetView.frame = sheetFrame(offset: offset(for: currentExpansionState))
            updateSheetLayoutGuideTopConstraint()
            updateExpandedContentAlpha()
            updateDimmingViewAlpha()
            updateDimmingViewAccessibility()
        }
        collapsedHeightInSafeArea = view.safeAreaLayoutGuide.layoutFrame.maxY - offset(for: .collapsed)

        updateAppearance()

        super.viewDidLayoutSubviews()
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        completeAnimationsIfNeeded(skipToEnd: true)
    }

    public override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        completeAnimationsIfNeeded(skipToEnd: true)
    }

    public typealias TokenSetKeyType = BottomSheetTokenSet.Tokens
    public var tokenSet: BottomSheetTokenSet = .init()

    var fluentTheme: FluentTheme { return view.fluentTheme }

    private func updateAppearance() {
        updateBackgroundColor()
        updateResizingHandleColor()
        updateShadow()
        updateCornerRadius()
    }

    private func updateBackgroundColor() {
        // Of course we have no active background color applied when we're using a BlurEffect
        if (style != .glass) {
            let backgroundColor = tokenSet[.backgroundColor].uiColor
            bottomSheetView.subviews[0].backgroundColor = backgroundColor
            overflowView.backgroundColor = backgroundColor
        }
    }

    private func updateResizingHandleColor() {
        resizingHandleView.tokenSet.setOverrideValue(tokenSet[.resizingHandleMarkColor], forToken: .markColor)
    }

    private func updateShadow() {

        switch style {
        case .primary:
            let shadowInfo = tokenSet[.shadow].shadowInfo
            // We need to have the shadow on a parent of the view that does the corner masking.
            // Otherwise the view will mask its own shadow.
            shadowInfo.applyShadow(to: bottomSheetView, parentController: self)
        case .glass:
            // The current Fluent Shadow implementation in `applyShadow(to:)` adds extra CALayers with shadow properties
            // and relies on the target UIView having an opaque backgroundColor — the shadow visibility depends on its opacity.
            // This breaks down when using a UIVisualEffectView with a UIBlurEffect, since setting a backgroundColor would interfere
            // with blur sampling and defeat its purpose. In such cases, we bypass `applyShadow(to:)` and apply the shadow tokens
            // directly to the UIVisualEffectView’s primary layer, ensuring shadows render correctly without disrupting the blur effect.
            bottomSheetView.layer.shadowColor   = BottomSheetTokenSet.blurEffectShadowColor
            bottomSheetView.layer.shadowOpacity = BottomSheetTokenSet.blurEffectShadowOpacity
            bottomSheetView.layer.shadowOffset  = BottomSheetTokenSet.blurEffectShadowOffset
            bottomSheetView.layer.shadowRadius  = BottomSheetTokenSet.blurEffectShadowRadius
        }
    }

    private func updateCornerRadius() {
        bottomSheetView.subviews[0].layer.cornerRadius = tokenSet[.cornerRadius].float
    }

    private lazy var overflowView: UIView = UIView()

    private lazy var dimmingView: DimmingView = {
        var dimmingView = DimmingView(type: .black)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.alpha = 0.0

        dimmingView.accessibilityLabel = "Accessibility.Dismiss.Label".localized
        dimmingView.accessibilityHint = "Accessibility.Dismiss.Hint".localized
        dimmingView.accessibilityTraits = .button

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDimmingViewTap))
        dimmingView.addGestureRecognizer(tapGesture)
        return dimmingView
    }()

    private lazy var resizingHandleView: ResizingHandleView = {
        let resizingHandleView = ResizingHandleView()
        resizingHandleView.isAccessibilityElement = true
        resizingHandleView.accessibilityTraits = .button
        resizingHandleView.isUserInteractionEnabled = true
        resizingHandleView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleResizingHandleViewTap)))
        resizingHandleView.tokenSet.setOverrideValue(tokenSet[.resizingHandleMarkColor], forToken: .markColor)
        return resizingHandleView
    }()

    private lazy var bottomSheetView: UIView = {
        let bottomSheetContentView = UIView()
        bottomSheetContentView.translatesAutoresizingMaskIntoConstraints = false

        bottomSheetContentView.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.delegate = self

        let stackView = UIStackView(arrangedSubviews: [resizingHandleView])
        stackView.spacing = 0.0
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Some types of content (like navigation controllers) can mess up the VO order.
        // Explicitly specifying a11y elements helps prevents this.
        bottomSheetContentView.accessibilityElements = [resizingHandleView]

        if let headerView = headerContentView {
            stackView.addArrangedSubview(headerView)
            bottomSheetContentView.accessibilityElements?.append(headerView)
        }

        stackView.addArrangedSubview(expandedContentView)
        bottomSheetContentView.accessibilityElements?.append(expandedContentView)
        bottomSheetContentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: bottomSheetContentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: bottomSheetContentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: bottomSheetContentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomSheetContentView.bottomAnchor)
        ])

        return makeBottomSheetByEmbedding(contentView: bottomSheetContentView)
    }()

    private func makeBottomSheetByEmbedding(contentView: UIView) -> UIView {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.layer.cornerCurve = .continuous
        contentView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        contentView.clipsToBounds = true

        let bottomSheetView: UIView

        switch style {
        case .primary:
            bottomSheetView = UIView()

            // We need to set the background color of the embedding view otherwise the shadows will not display
            bottomSheetView.backgroundColor = tokenSet[.backgroundColor].uiColor
            bottomSheetView.layer.cornerRadius = tokenSet[.cornerRadius].float
            bottomSheetView.addSubview(contentView)
        case .glass:
            let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            blurEffectView.layer.cornerRadius = tokenSet[.cornerRadius].float
            blurEffectView.contentView.addSubview(contentView)

            bottomSheetView = blurEffectView
        }

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: bottomSheetView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: bottomSheetView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: bottomSheetView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomSheetView.bottomAnchor)
        ])

#if DEBUG
        bottomSheetView.accessibilityIdentifier = "Bottom Sheet View"
#endif

        return bottomSheetView
    }

    // MARK: - Gesture handling

    @objc private func handleDimmingViewTap(_ sender: UITapGestureRecognizer) {
        move(to: .collapsed, interaction: .dimmingViewTap)
    }

    @objc private func handleResizingHandleViewTap(_ sender: UITapGestureRecognizer) {
        guard let nextState = nextExpansionStateForResizingHandleTap(with: currentExpansionState) else {
            return
        }
        move(to: nextState, interaction: .resizingHandleTap)
    }

    private func updateResizingHandleViewAccessibility(for state: BottomSheetExpansionState) {
        guard let nextState = nextExpansionStateForResizingHandleTap(with: state) else {
            return
        }

        if nextState == .collapsed {
            resizingHandleView.accessibilityLabel = handleCollapseCustomAccessibilityLabel ?? "Accessibility.BottomSheet.ResizingHandle.Label.CollapseSheet".localized
            resizingHandleView.accessibilityHint = "Accessibility.Drawer.ResizingHandle.Hint.Collapse".localized
            resizingHandleView.accessibilityValue = "Accessibility.Drawer.ResizingHandle.Value.Expanded".localized
        } else {
            resizingHandleView.accessibilityLabel = handleExpandCustomAccessibilityLabel ?? "Accessibility.BottomSheet.ResizingHandle.Label.ExpandSheet".localized
            resizingHandleView.accessibilityHint = "Accessibility.Drawer.ResizingHandle.Hint.Expand".localized
            resizingHandleView.accessibilityValue = "Accessibility.Drawer.ResizingHandle.Value.Collapsed".localized
        }
    }

    private func nextExpansionStateForResizingHandleTap(with currentExpansionState: BottomSheetExpansionState) -> BottomSheetExpansionState? {
        return switch currentExpansionState {
        case .collapsed:
            supportsPartialExpansion ? .partial : .expanded
        case .partial:
            .expanded
        case .expanded:
            .collapsed
        default:
            nil
        }
    }

    private func updateExpandedContentAlpha() {
        let currentOffset = currentSheetVerticalOffset
        let collapsedOffset = offset(for: .collapsed)
        let expandedOffset = supportsPartialExpansion ? offset(for: .partial) : offset(for: .expanded)

        var targetAlpha: CGFloat = 1.0
        if shouldHideCollapsedContent && !isHeightRestricted {
            let transitionLength = min(Constants.expandedContentAlphaTransitionLength, abs(collapsedOffset - expandedOffset))
            if currentOffset >= collapsedOffset {
                targetAlpha = 0.0
            } else if currentOffset < collapsedOffset && currentOffset > collapsedOffset - transitionLength {
                targetAlpha = abs(currentOffset - collapsedOffset) / transitionLength
            }
        }
        expandedContentView.alpha = targetAlpha

#if DEBUG
        if targetAlpha == 1.0 {
            bottomSheetView.accessibilityIdentifier?.append(", an expanded content view")
        } else {
            bottomSheetView.accessibilityIdentifier = bottomSheetView.accessibilityIdentifier?.replacingOccurrences(of: ", an expanded content view", with: "")
        }
#endif
    }

    private func updateDimmingViewAlpha() {
        guard shouldShowDimmingView else {
            return
        }

        var targetAlpha: CGFloat = 0.0
        if isExpandable {
            // Offset marks top of the sheet in UIView coord space, so counterintuitively,
            // lowest -> highest means .expanded -> .hidden
            //             self.view top
            // ---------------------------------------- <--- low offset
            // ----------------------------------------
            // -----------fully dimmed (1.0)-----------
            // ----------------------------------------
            // ********highest dimmed offset***********
            // ----------------------------------------
            // ----------------------------------------
            // -------transition space (1.0-0.0)-------
            // ----------------------------------------
            // ----------------------------------------
            // ********lowest undimmed offset**********
            // ----------------------------------------
            // -------- fully undimmed (0.0)-----------
            // ----------------------------------------
            // ---------------------------------------- <--- high offset

            let currentOffset = currentSheetVerticalOffset
            let highestDimmedOffset = offset(for: .expanded)
            let lowestUndimmedOffset = offset(for: isHeightRestricted ? .hidden : supportsPartialExpansion ? .partial : .collapsed)

            if currentOffset <= highestDimmedOffset {
                targetAlpha = 1.0
            } else if currentOffset >= lowestUndimmedOffset {
                targetAlpha = 0.0
            } else {
                targetAlpha = abs(currentOffset - lowestUndimmedOffset) / (lowestUndimmedOffset - highestDimmedOffset)
            }
        }

        if currentExpansionState != .transitioning {
            // In the case that there has been a floating point precision error and
            // targetAlpha is a value very close to 0 or 1, set it explicitly
            if targetAlpha != 0 || targetAlpha != 1 {
                targetAlpha = currentExpansionState == .expanded ? 1 : 0
            }
        }

        dimmingView.alpha = targetAlpha
    }

    // When the bottomsheet is expanded and dimmingView is shown, we should make dimmingView accessibility
    // DimmingView is technically full screen. However, for accessibility users, we should update the dimmingView's accessibilityFrame to be only the offset from bottomsheet's frame.
    private func updateDimmingViewAccessibility() {
        guard shouldShowDimmingView else {
            return
        }

        if dimmingView.alpha == 0 {
            dimmingView.isAccessibilityElement = false
            view.accessibilityViewIsModal = false
        } else {
            dimmingView.isAccessibilityElement = true
            var margins: UIEdgeInsets = .zero
            margins.bottom = bottomSheetView.frame.height
            dimmingView.accessibilityFrame = view.frame.inset(by: margins)
            view.accessibilityViewIsModal = true
        }
    }

    private func updateSheetLayoutGuideTopConstraint() {
        if sheetLayoutGuideTopConstraint.constant != currentSheetVerticalOffset {
            sheetLayoutGuideTopConstraint.constant = currentSheetVerticalOffset
        }
    }

    @objc private func handlePan(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began:
            completeAnimationsIfNeeded()
            delegate?.bottomSheetStartedPan?(self, from: currentExpansionState)
            currentExpansionState = .transitioning
            fallthrough
        case .changed:
            translateSheet(by: sender.translation(in: view))
            sender.setTranslation(.zero, in: view)
        case .ended, .cancelled, .failed:
            completePan(with: sender.velocity(in: view).y)
        default:
            break
        }
    }

    private func translateSheet(by translationDelta: CGPoint) {
        let expandedOffset = offset(for: .expanded)
        let collapsedOffset = offset(for: .collapsed)
        let hiddenOffset = offset(for: .hidden)

        let minOffset = expandedOffset - Constants.maxRubberBandOffset
        let maxOffset = allowsSwipeToHide ? hiddenOffset : (collapsedOffset + Constants.maxRubberBandOffset)

        var offsetDelta = translationDelta.y
        if (currentSheetVerticalOffset >= collapsedOffset && !allowsSwipeToHide) || currentSheetVerticalOffset <= expandedOffset {
            offsetDelta *= translationRubberBandFactor(for: currentSheetVerticalOffset)
        }

        let targetOffset = min(max(bottomSheetView.frame.origin.y + offsetDelta, minOffset), maxOffset)
        bottomSheetView.frame = sheetFrame(offset: targetOffset)

        updateSheetLayoutGuideTopConstraint()
        updateExpandedContentAlpha()
        updateDimmingViewAlpha()
        updateDimmingViewAccessibility()
    }

    // Source of truth for the sheet frame at a given offset from the top of the root view bounds.
    // The output is only meaningful once view.bounds is non-zero i.e. a layout pass has occured.
    private func sheetFrame(offset: CGFloat) -> CGRect {
        let sheetWidth: CGFloat = determineSheetWidth()

        let sheetHeight: CGFloat

        if isFlexibleHeight {
            let minSheetHeight = collapsedSheetHeight
            sheetHeight = max(minSheetHeight, view.bounds.maxY - offset)
        } else {
            sheetHeight = expandedSheetHeight
        }

        // Calculates the location to put the left edge of the sheet relative to the view
        // For right aligned we get the width of the view offset by the sheets width and the padding
        // For left aligned we only need to add in the padding
        // For center aligned we need the position of the center offset by half the sheets width
        let xPosition: CGFloat
        let isLeftToRight: Bool = UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute) == .leftToRight
        switch anchoredEdge {
        case .center:
            xPosition = (view.bounds.width - sheetWidth) / 2
        case .leading:
            if isLeftToRight {
                xPosition = Constants.horizontalSheetPadding
            } else {
                xPosition = view.bounds.width - sheetWidth - Constants.horizontalSheetPadding
            }
        case .trailing:
            if isLeftToRight {
                xPosition = view.bounds.width - sheetWidth - Constants.horizontalSheetPadding
            } else {
                xPosition = Constants.horizontalSheetPadding
            }
        }

        let frame = CGRect(origin: CGPoint(x: xPosition, y: offset),
                             size: CGSize(width: sheetWidth, height: sheetHeight))
        return frame
    }

    // Helper function to determine how wide the sheet should be
    private func determineSheetWidth() -> CGFloat {
        // Width will the fill the screen if should always fill width
        // Otherwise we will try and set the size to the preferred width as long as its between the max and min width
        // If its not between those we will make the maximum width size
        let availableWidth: CGFloat = view.bounds.width
        let maxWidth = min(Constants.maxSheetWidth, availableWidth)
        let determinedWidth: CGFloat

        if shouldAlwaysFillWidth {
            determinedWidth = availableWidth
        } else if maxWidth > Constants.minSheetWidth {
            determinedWidth = Constants.minSheetWidth...maxWidth ~= preferredWidth ? preferredWidth : maxWidth
        } else {
            determinedWidth = maxWidth
        }

        return determinedWidth
    }

    private func translationRubberBandFactor(for currentOffset: CGFloat) -> CGFloat {
        let offLimitsOffset: CGFloat
        let expandedOffset = offset(for: .expanded)
        let collapsedOffset = offset(for: .collapsed)

        if currentOffset < expandedOffset {
            offLimitsOffset = min(expandedOffset - currentOffset, Constants.maxRubberBandOffset)
        } else if currentOffset > collapsedOffset {
            offLimitsOffset = min(currentOffset - collapsedOffset, Constants.maxRubberBandOffset)
        } else {
            offLimitsOffset = 0.0
        }

        return max(1.0 - offLimitsOffset / Constants.maxRubberBandOffset, Constants.minRubberBandScaleFactor)
    }

    // MARK: - Animations

    private func completePan(with velocity: CGFloat) {
        var targetState: BottomSheetExpansionState

        if abs(velocity) < Constants.directionOverrideVelocityThreshold {
            // With a low velocity, we should snap to the closest state.
            let eligibleStates: [BottomSheetExpansionState?] = [
                .expanded,
                .collapsed,
                supportsPartialExpansion ? .partial : nil,
                allowsSwipeToHide ? .hidden : nil
            ]

            let distances = eligibleStates
                .compactMap { $0 }
                .reduce(into: [BottomSheetExpansionState: CGFloat]()) { result, state in
                    result[state] = abs(offset(for: state) - currentSheetVerticalOffset)
                }

            targetState = distances.min(by: { $0.value < $1.value })?.key ?? .collapsed
        } else {
            // Velocity high enough, animate to the state we're swiping towards
            if currentSheetVerticalOffset > offset(for: .collapsed) && allowsSwipeToHide {
                targetState = velocity > 0 ? .hidden : .collapsed
            } else {
                if supportsPartialExpansion {
                    if velocity > 0 {
                        // Swiping down
                        targetState = currentSheetVerticalOffset > offset(for: .partial) ? .collapsed : .partial
                    } else {
                        // Swiping up
                        targetState = currentSheetVerticalOffset > offset(for: .partial) ? .partial : .expanded
                    }
                } else {
                    targetState = velocity > 0 ? .collapsed : .expanded
                }
            }
        }
        move(to: targetState, velocity: velocity, interaction: .swipe)
    }

    private func move(to targetExpansionState: BottomSheetExpansionState,
                      animated: Bool = true,
                      velocity: CGFloat = 0.0,
                      interaction: BottomSheetInteraction = .noUserAction,
                      shouldNotifyDelegate: Bool = true,
                      allowUnhiding: Bool = false,
                      completion: ((UIViewAnimatingPosition) -> Void)? = nil) {
        guard targetExpansionState == .hidden || !isHiddenOrHiding || allowUnhiding else {
            return
        }

        completeAnimationsIfNeeded()

        updateResizingHandleViewAccessibility(for: targetExpansionState)

        if currentSheetVerticalOffset != offset(for: targetExpansionState) {
            delegate?.bottomSheetController?(self, willMoveTo: targetExpansionState, interaction: interaction)

            let animator = stateChangeAnimator(to: targetExpansionState,
                                               velocity: velocity,
                                               interaction: interaction,
                                               shouldNotifyDelegate: shouldNotifyDelegate)
            animator.addCompletion({ finalPosition in
                completion?(finalPosition)
            })

            if animated {
                currentStateChangeAnimator = animator
                animator.startAnimation()
            } else {
                animator.startAnimation() // moves the animator into active state so it can be stopped
                animator.stopAnimation(false)
                animator.finishAnimation(at: .end)
            }
        } else {
            handleCompletedStateChange(to: targetExpansionState, interaction: interaction, shouldNotifyDelegate: shouldNotifyDelegate)
        }
    }

    private func stateChangeAnimator(to targetExpansionState: BottomSheetExpansionState,
                                     velocity: CGFloat = 0.0,
                                     interaction: BottomSheetInteraction = .noUserAction,
                                     shouldNotifyDelegate: Bool = true) -> UIViewPropertyAnimator {
        let targetVerticalOffset = offset(for: targetExpansionState)
        let distanceToGo = abs(currentSheetVerticalOffset - targetVerticalOffset)
        let springVelocity = min(abs(velocity / distanceToGo), Constants.Spring.maxInitialVelocity)
        let damping: CGFloat = abs(velocity) > Constants.Spring.flickVelocityThreshold
            ? Constants.Spring.oscillatingDampingRatio
            : Constants.Spring.defaultDampingRatio

        let springParams = UISpringTimingParameters(dampingRatio: damping,
                                                    initialVelocity: CGVector(dx: springVelocity, dy: springVelocity))
        let translationAnimator = UIViewPropertyAnimator(duration: Constants.Spring.animationDuration, timingParameters: springParams)

        self.targetExpansionState = targetExpansionState

        // Disable dragging while hiding the sheet
        if targetExpansionState == .hidden {
            panGestureRecognizer.isEnabled = false
        }

        // Animation might be reversed, so we need to remember the original state
        let originalExpansionState = currentExpansionState

        bottomSheetView.isHidden = false
        translationAnimator.addAnimations { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.bottomSheetView.frame = strongSelf.sheetFrame(offset: targetVerticalOffset)
            strongSelf.sheetLayoutGuideTopConstraint.constant = targetVerticalOffset

            strongSelf.updateDimmingViewAlpha()
            strongSelf.updateExpandedContentAlpha()
            strongSelf.view.layoutIfNeeded()
            strongSelf.updateDimmingViewAccessibility()
        }

        translationAnimator.addCompletion({ [weak self] finalPosition in
            guard let strongSelf = self else {
                return
            }

            // It's important we drop the reference to the animator as early as possible.
            // Otherwise we could accidentally try modifying the animator while it's calling out to its completion handler, which can lead to a crash.
            if let animator = strongSelf.currentStateChangeAnimator, animator == translationAnimator {
                strongSelf.currentStateChangeAnimator = nil
            }

            strongSelf.targetExpansionState = nil
            strongSelf.panGestureRecognizer.isEnabled = strongSelf.isExpandable
            strongSelf.handleCompletedStateChange(to: finalPosition == .start ? originalExpansionState : targetExpansionState,
                                                  interaction: interaction,
                                                  shouldNotifyDelegate: shouldNotifyDelegate && finalPosition != .current)
        })

        view.layoutIfNeeded()
        currentExpansionState = .transitioning
        return translationAnimator
    }

    // Vertical offset of bottomSheetView.origin for the given expansion state
    //
    // Note: Since .transitioning state doesn't have a well defined offset, this function will
    // only return the current sheet offset in that case.
    private func offset(for expansionState: BottomSheetExpansionState) -> CGFloat {
        let offset: CGFloat

        let minOffset = view.bounds.maxY - expandedSheetHeight
        switch expansionState {
        case .collapsed:
            if isHeightRestricted && isExpandable {
                // When we're height restricted a distinct collapsed offset doesn't make sense,
                // so we go straight to expanded.
                offset = minOffset
            } else {
                offset = view.bounds.maxY - collapsedSheetHeight
            }
        case .partial:
            if isHeightRestricted && isExpandable {
                // Same here, in height restricted scenarios we want to utilize the space.
                offset = minOffset
            } else {
                offset = view.bounds.maxY - (resolvedDynamicSheetHeights?.partialHeight ?? collapsedSheetHeight)
            }
        case .expanded:
            offset = minOffset
        case .hidden:
            offset = view.bounds.maxY
        case .transitioning:
            offset = bottomSheetView.frame.minY
        }

        return offset
    }

    private func handleCompletedStateChange(to targetExpansionState: BottomSheetExpansionState,
                                            interaction: BottomSheetInteraction = .noUserAction,
                                            shouldNotifyDelegate: Bool = true) {
        currentExpansionState = targetExpansionState
        if shouldNotifyDelegate {
            self.delegate?.bottomSheetController?(self, didMoveTo: targetExpansionState, interaction: interaction)
        }

        if targetExpansionState == .collapsed {
            hostedScrollView?.setContentOffset(.zero, animated: true)
        }

        bottomSheetView.isHidden = targetExpansionState == .hidden

        updateDimmingViewAlpha()
        updateDimmingViewAccessibility()

        // UIKit doesn't properly handle interrupted constraint animations, so we need to
        // detect and fix a possible desync here
        updateSheetLayoutGuideTopConstraint()
    }

    private func completeAnimationsIfNeeded(skipToEnd: Bool = false) {
        if let currentAnimator = currentStateChangeAnimator, currentAnimator.isRunning, currentAnimator.state == .active {
            let endPosition: UIViewAnimatingPosition = currentAnimator.isReversed ? .start : .end
            currentAnimator.stopAnimation(false)
            currentAnimator.finishAnimation(at: skipToEnd ? endPosition : .current)
            currentStateChangeAnimator = nil
        }
    }

    private func makeLayoutGuideConstraints() -> [NSLayoutConstraint] {
        let requiredConstraints = [
            sheetLayoutGuide.leadingAnchor.constraint(equalTo: bottomSheetView.leadingAnchor),
            sheetLayoutGuide.trailingAnchor.constraint(equalTo: bottomSheetView.trailingAnchor),
            sheetLayoutGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sheetLayoutGuide.topAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor)
        ]

        // This constraint is used to align the top of the layout guide with the top of the bottomSheetView.
        // BottomSheetView will go off-screen when it's hidden, so this constraint is not always required.
        let breakableTopConstraint = sheetLayoutGuideTopConstraint
        breakableTopConstraint.priority = .defaultHigh

        return requiredConstraints + [breakableTopConstraint]
    }

    private lazy var sheetLayoutGuideTopConstraint: NSLayoutConstraint = sheetLayoutGuide.topAnchor.constraint(equalTo: view.topAnchor)

    // Height of the sheet in the fully expanded state
    private var expandedSheetHeight: CGFloat {
        guard isExpandable else {
            return collapsedSheetHeight
        }

        let height: CGFloat

        if preferredExpandedContentHeight == 0 {
            height = maxSheetHeight
        } else {
            let idealHeight = currentResizingHandleHeight + headerContentHeight + preferredExpandedContentHeight + view.safeAreaInsets.bottom
            height = min(maxSheetHeight, idealHeight)
        }

        // One case when the lower bound is required is when view.frame is .zero (like before the initial layout pass)
        // This gives the sheet some space to layout in so the layout engine doesn't complain.
        return max(collapsedSheetHeight, height)
    }

    // Height of the sheet in collapsed state
    private var collapsedSheetHeight: CGFloat {
        let safeAreaSheetHeight: CGFloat
        if let dynamicHeight = resolvedDynamicSheetHeights?.collapsedHeight, dynamicHeight > 0 {
            safeAreaSheetHeight = dynamicHeight
        } else if collapsedContentHeight > 0 {
            safeAreaSheetHeight = collapsedContentHeight + currentResizingHandleHeight
        } else {
            safeAreaSheetHeight = headerContentHeight + currentResizingHandleHeight
        }

        let idealHeight = safeAreaSheetHeight + view.safeAreaInsets.bottom
        return min(idealHeight, maxSheetHeight)
    }

    // Maximum total sheet height including parts outside of the safe area.
    private var maxSheetHeight: CGFloat {
        let maxHeight: CGFloat

        if view.frame != .zero {
            maxHeight = view.frame.height - view.safeAreaInsets.top - Constants.minimumTopExpandedPadding
        } else {
            maxHeight = Constants.defaultMaxSheetHeight
        }

        return maxHeight
    }

    private var resolvedDynamicSheetHeights: DynamicHeightResolutionResult? {
        let currentContext = ContentHeightResolutionContext(maximumHeight: maxSheetHeight - view.safeAreaInsets.bottom, containerTraitCollection: view.traitCollection)
        let cachedContext = cachedResolvedDynamicSheetHeights?.context

        if cachedContext?.maximumHeight != currentContext.maximumHeight
            || cachedContext?.containerTraitCollection.horizontalSizeClass != currentContext.containerTraitCollection.horizontalSizeClass
            || cachedContext?.containerTraitCollection.verticalSizeClass != currentContext.containerTraitCollection.verticalSizeClass {
            cachedResolvedDynamicSheetHeights = (context: currentContext,
                                            collapsedHeight: collapsedHeightResolver?(currentContext),
                                            partialHeight: partialHeightResolver?(currentContext))
        }

        return cachedResolvedDynamicSheetHeights
    }

    // Do not access directly. Use `resolvedDynamicSheetHeights` instead which wraps this cache.
    private var cachedResolvedDynamicSheetHeights: DynamicHeightResolutionResult?

    private var currentResizingHandleHeight: CGFloat {
        (isExpandable ? ResizingHandleView.height : 0.0)
    }

    private lazy var panGestureRecognizer: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))

    private var headerContentViewHeightConstraint: NSLayoutConstraint?

    private var currentStateChangeAnimator: UIViewPropertyAnimator?

    private var currentExpansionState: BottomSheetExpansionState = .collapsed

    private var targetExpansionState: BottomSheetExpansionState?

    private var isHiddenOrHiding: Bool { isHidden || targetExpansionState == .hidden }

    private var isHeightRestricted: Bool {
        maxSheetHeight - collapsedSheetHeight < Constants.heightRestrictedThreshold
    }

    private var supportsPartialExpansion: Bool {
        partialHeightResolver != nil
    }

    private var currentSheetVerticalOffset: CGFloat {
        bottomSheetView.frame.minY
    }

    // Only used for height change detection.
    // For all other cases you should probably directly use self.view.bounds.height.
    private var currentRootViewHeight: CGFloat = 0

    private let shouldShowDimmingView: Bool

    private let style: BottomSheetControllerStyle

    // Dynamic heights, resolved with the corresponding context.
    private typealias DynamicHeightResolutionResult = (context: ContentHeightResolutionContext, collapsedHeight: CGFloat?, partialHeight: CGFloat?)

    private struct Constants {
        // Maximum offset beyond the normal bounds with additional resistance
        static let maxRubberBandOffset: CGFloat = 20.0
        static let minRubberBandScaleFactor: CGFloat = 0.05

        // Swipes over this velocity ignore proximity to the collapsed / expanded offset and fly towards
        // the offset that makes sense given the swipe direction
        static let directionOverrideVelocityThreshold: CGFloat = 150

        // Minimum padding from top when the sheet is fully expanded
        static let minimumTopExpandedPadding: CGFloat = 25.0

        // The padding allocated to the space between the sheet and the edge when attached to the leading or trailing edge
        static let horizontalSheetPadding: CGFloat = GlobalTokens.spacing(.size80)

        static let expandedContentAlphaTransitionLength: CGFloat = 30

        static let maxSheetWidth: CGFloat = 610
        static let minSheetWidth: CGFloat = 300
        static let defaultMaxSheetHeight: CGFloat = 600

        // When the difference in collapsed height and max sheet height is less than this,
        // we go into height restricted mode which skips the collapsed state and adjusts dimming.
        static let heightRestrictedThreshold: CGFloat = 50

        struct Spring {
            // Spring used in slow swipes - no oscillation
            static let defaultDampingRatio: CGFloat = 1.0

            // Spring used in fast swipes - slight oscillation
            static let oscillatingDampingRatio: CGFloat = 0.8

            // Swipes over this velocity get slight spring oscillation
            static let flickVelocityThreshold: CGFloat = 800

            static let maxInitialVelocity: CGFloat = 40.0
            static let animationDuration: TimeInterval = 0.4

            // Off-screen overflow that can be partially revealed during spring oscillation or rubber banding (dragging the sheet beyond limits)
            static let overflowHeight: CGFloat = 50.0
        }
    }
}

extension BottomSheetController: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer == panGestureRecognizer && otherGestureRecognizer == hostedScrollView?.panGestureRecognizer
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Enables other gesture recognizers to occur inside the bottom sheet alongside the `panGestureRecognizer`.
        // The `otherGestureRecognizer` will be required to fail if it is not a tap gesture and it is not the `hostedScrollView` pan gesture.
        return !(otherGestureRecognizer is UITapGestureRecognizer) && (otherGestureRecognizer != hostedScrollView?.panGestureRecognizer)
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let scrollView = hostedScrollView,
              let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }
        // By default, the sheet pan gesture takes precedence.
        var shouldBegin = true

        // If we're sufficiently expanded, we give the scroll view an opportunity to take over.
        if currentSheetVerticalOffset <= offset(for: supportsPartialExpansion ? .partial : .expanded) {
            let scrolledToTop = scrollView.contentOffset.y <= 0
            let panningDown = panGesture.velocity(in: view).y > 0
            let panInHostedScrollView = scrollView.frame.contains(panGesture.location(in: scrollView.superview))
            shouldBegin = (scrolledToTop && panningDown) || !panInHostedScrollView
        }
        return shouldBegin
    }
}
