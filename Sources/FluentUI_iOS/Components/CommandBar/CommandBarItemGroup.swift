//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

/// A group of `CommandBarItem`s to display together in a `CommandBar`.
@objc(MSFCommandBarItemGroup)
public class CommandBarItemGroup: NSObject, RandomAccessCollection, ExpressibleByArrayLiteral {
	public typealias Element = CommandBarItem
	public typealias Index = Int
	public typealias ArrayLiteralElement = CommandBarItem

	/// When `true`, a separator is rendered after this group inside the `CommandBar`.
	public var showsSeparatorAfter: Bool {
		didSet {
			if showsSeparatorAfter != oldValue {
				separatorChangedHandler?()
			}
		}
	}

	/// Called when `showsSeparatorAfter` changes so the owning view can update its layout.
	@objc public var separatorChangedHandler: (() -> Void)?

	@objc public init(_ items: [CommandBarItem] = [], showsSeparatorAfter: Bool = false) {
		self.items = items
		self.showsSeparatorAfter = showsSeparatorAfter
	}

	public required convenience init(arrayLiteral elements: CommandBarItem...) {
		self.init(Array(elements))
	}

	public var startIndex: Int { items.startIndex }
	public var endIndex: Int { items.endIndex }
	public subscript(index: Int) -> CommandBarItem { items[index] }

	public override func isEqual(_ object: Any?) -> Bool {
		guard let other = object as? CommandBarItemGroup else { return false }
		return showsSeparatorAfter == other.showsSeparatorAfter && items == other.items
	}

	private var items: [CommandBarItem]
}
