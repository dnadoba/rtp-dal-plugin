//
//  SetDiff.swift
//  Lightning
//
//  Created by David Nadoba on 06.04.19.
//  Copyright © 2019 David Nadoba. All rights reserved.
//

import Foundation

public struct SetDifference<Element: Hashable>: Hashable {
    public var added: Set<Element>
    public var removed: Set<Element>
    @inlinable
    public init(added: Set<Element>, removed: Set<Element>) {
        self.added = added
        self.removed = removed
    }
}

extension Set {
    /// Returns the difference needed to produce the receiver's state from the
    /// parameter's state, using the provided closure to establish equivalence
    /// between elements.
    ///
    /// - Parameters:
    ///   - other: The base state.
    ///   - areEquivalent: A closure that returns whether the two
    ///     parameters are equivalent.
    ///
    /// - Returns: The difference needed to produce the reciever's state from
    ///   the parameter's state.
    @inlinable
    public func difference(
        from other: Set<Element>,
        by areEquivalent: (Element, Element) -> Bool = (==)
    ) -> SetDifference<Element> {
        
        return SetDifference<Element>(
            added: self.subtracting(other),
            removed: other.subtracting(self))
    }
}
