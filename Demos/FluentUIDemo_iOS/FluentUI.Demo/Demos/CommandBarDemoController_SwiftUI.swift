//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import FluentUI
import SwiftUI
import UIKit

class CommandBarDemoControllerSwiftUI: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingController = UIHostingController(rootView: CommandBarSwiftUIDemoView())
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
}

// MARK: - CommandBarRepresentable

struct CommandBarRepresentable: UIViewRepresentable {
    var itemGroups: [CommandBarItemGroup]
    var leadingItemGroups: [CommandBarItemGroup]?
    var trailingItemGroups: [CommandBarItemGroup]?
    var isScrollable: Bool = true

    func makeUIView(context: Context) -> UIView {
        let commandBar = CommandBar(itemGroups: itemGroups,
                                    leadingItemGroups: leadingItemGroups,
                                    trailingItemGroups: trailingItemGroups)
        commandBar.isScrollable = isScrollable
        commandBar.setContentHuggingPriority(.required, for: .vertical)
        commandBar.setContentCompressionResistancePriority(.required, for: .vertical)

        commandBar.translatesAutoresizingMaskIntoConstraints = false

        let containerView = UIView()
        containerView.addSubview(commandBar)
        // Scrollable: fill the container so the scroll area has a full-width frame.
        // Non-scrollable: cap to container width so the bar shrinks to its natural content size.
        let widthConstraint = isScrollable
            ? commandBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            : commandBar.widthAnchor.constraint(lessThanOrEqualTo: containerView.widthAnchor)
        NSLayoutConstraint.activate([
            commandBar.topAnchor.constraint(equalTo: containerView.topAnchor),
            commandBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            widthConstraint,
            commandBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    func updateUIView(_ commandBarContiner: UIView, context: Context) {
        let commandBar = commandBarContiner.subviews.first as! CommandBar

        commandBar.itemGroups = itemGroups
        commandBar.leadingItemGroups = leadingItemGroups
        commandBar.trailingItemGroups = trailingItemGroups
        commandBar.isScrollable = isScrollable
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        let height = (uiView.subviews.first as? CommandBar)?.intrinsicContentSize.height ?? uiView.intrinsicContentSize.height
        let targetSize = CGSize(width: proposal.width ?? UIView.layoutFittingCompressedSize.width,
                                height: height)
//        let fittingSize = uiView.systemLayoutSizeFitting(targetSize,
//                                                         withHorizontalFittingPriority: .fittingSizeLevel,
//                                                         verticalFittingPriority: .required)
//        // Use the ideal (fitting) width, but cap to the proposed width so the bar
//        // accepts compression and truncates text when space is tight.
//        let width = if let proposedWidth = proposal.width {
//            min(fittingSize.width, proposedWidth)
//        } else {
//            fittingSize.width
//        }
        return targetSize
    }
}

// MARK: - Demo View

struct CommandBarSwiftUIDemoView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            HStack(spacing: 0) {
                CommandBarRepresentable(
                    itemGroups: itemGroups,
                    leadingItemGroups: leadingItemGroups
                )

                Spacer(minLength: 8)

                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 56, height: 56)
            }
            .frame(width: containerWidth)
            .border(.green)

            HStack(spacing: 0) {
                CommandBarRepresentable(
                    itemGroups: shortItemGroups,
                    isScrollable: false
                )

                Spacer(minLength: 8)

                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 56, height: 56)
            }
            .frame(width: containerWidth)
            .border(.green)

            HStack(spacing: 12) {
                Image(systemName: "star")
                Image(systemName: "circle")
                Rectangle()
                    .frame(width: 60, height: 60)
                Rectangle()
                    .frame(width: 60, height: 60)
                Image(systemName: "star")
                Image(systemName: "circle")
                Text("sdajlfgahdsjkf")
                    .truncationMode(.middle)
            }
            .frame(width: containerWidth)
            .border(.green)

            Spacer()

            VStack(spacing: 8) {
                Text("Container width: \(Int(containerWidth))pt")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Slider(value: $containerWidth, in: 100...600, step: 1)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
    }

    @State private var containerWidth: CGFloat = 400

    // MARK: - CommandBar Items

    private var itemGroups: [CommandBarItemGroup] {
        [
            [
                makeItem(icon: "textBold24Regular"),
                makeItem(icon: "textItalic24Regular"),
                makeItem(icon: "textUnderline24Regular"),
                makeItem(icon: "textStrikethrough24Regular")
            ],
            [
                makeItem(title: "Body", titleFont: .systemFont(ofSize: 15, weight: .regular))
            ],
            [
                makeItem(icon: "arrowUndo24Regular"),
                makeItem(icon: "arrowRedo24Filled")
            ]
        ]
    }

    private var shortItemGroups: [CommandBarItemGroup] {
        [
            [
              makeItem(icon: "textItalic24Regular"),
            ],
            [
              makeItem(icon: "textItalic24Regular"),
              makeItem(icon: "textBold24Regular", title: "BoldBoldBoldBoldBold"),
              makeItem(icon: "textUnderline24Regular")
            ]
        ]
    }

    private var leadingItemGroups: [CommandBarItemGroup] {
        [[makeItem(icon: "add24Regular")]]
    }

    private func makeItem(icon: String? = nil, title: String? = nil, titleFont: UIFont? = nil) -> CommandBarItem {
        CommandBarItem(
            iconImage: icon.flatMap { UIImage(named: $0) },
            title: title,
            titleFont: titleFont,
            isEnabled: true,
            isSelected: false,
            itemTappedHandler: { _, item in
                item.isSelected.toggle()
            }
        )
    }
}
