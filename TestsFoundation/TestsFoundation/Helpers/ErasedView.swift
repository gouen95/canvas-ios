//
// This file is part of Canvas.
// Copyright (C) 2020-present  Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import SwiftUI
@testable import ViewInspector

@available(iOS 13.0, *)
public enum ErasedView {
    case unknown(_ view: Any)
    case container(view: Any, elements: [ErasedView])

    public init<V: View, Body: View>(_ view: V, body: Body) {
        self = .container(view: view, elements: [ErasedView(body)])
    }

    public init(_ view: Any) {
        self = (view as? CustomErasable)?.erased ?? .unknown(view)
    }

    public init(_ view: Any, _ type: SingleViewContent.Type) {
        try! self.init(type.child(Content(view)).view)
    }

    public init(_ view: Any, _ type: MultipleViewContent.Type) {
        let children = try! type.children(Content(view))
        self = .container(view: view, elements: children.map { ErasedView($0.view) })
    }

    public func lazilyFindAll<V: View>(_: V.Type = V.self) -> AnySequence<V> {
        switch self {
        case let .unknown(view):
            return AnySequence([view].lazy.compactMap { $0 as? V })
        case let .container(view, elements):
            return AnySequence([
                [view].lazy.compactMap { $0 as? V },
                elements.lazy.flatMap { element in
                    element.lazilyFindAll()
                },
            ].joined())
        }
    }

    public func findAll<V: View>(_: V.Type = V.self) -> [V] {
        Array(lazilyFindAll())
    }

    public func first<V: View>(_: V.Type = V.self) -> V? {
        lazilyFindAll().first { _ in true }
    }

    public func forEach(_ callback: (ErasedView) -> Void) {
        callback(self)
        switch self {
        case let .container(_, elements):
            for view in elements {
                view.forEach(callback)
            }
        default: ()
        }
    }

    public var unknownTypes: Set<String> {
        var types = Set<String>()
        forEach { view in
            if case let .unknown(view) = view {
                types.insert("\(type(of: view))")
            }
        }
        return types
    }
}

@available(iOS 13.0, *)
public protocol CustomErasable {
    var erased: ErasedView { get }
}

@available(iOS 13.0, *)
extension _ConditionalContent: CustomErasable {
    public var erased: ErasedView {
        ErasedView(self, ViewType.ConditionalContent.self)
    }
}

@available(iOS 13.0, *)
extension HStack: CustomErasable {
    public var erased: ErasedView {
        ErasedView(self, ViewType.HStack.self)
    }
}

@available(iOS 13.0, *)
extension VStack: CustomErasable {
    public var erased: ErasedView {
        ErasedView(self, ViewType.VStack.self)
    }
}

@available(iOS 13.0, *)
extension ZStack: CustomErasable {
    public var erased: ErasedView {
        ErasedView(self, ViewType.ZStack.self)
    }
}

@available(iOS 13.0, *)
extension Form: CustomErasable {
    public var erased: ErasedView {
        ErasedView(self, ViewType.Form.self)
    }
}

@available(iOS 13.0, *)
extension Section: CustomErasable {
    public var erased: ErasedView {
        ErasedView(self, ViewType.Section.self)
    }
}

@available(iOS 13.0, *)
extension ForEach: CustomErasable {
    public var erased: ErasedView {
        typealias Builder = (Data.Element) -> Content
        let data = try! Inspector.attribute(label: "data", value: self, type: Data.self)
        let builder = try! Inspector.attribute(label: "content", value: self, type: Builder.self)
        let elements = data.map { ErasedView(builder($0)) }
        return .container(view: self, elements: elements)
    }
}

@available(iOS 13.0, *)
extension ModifiedContent: CustomErasable {
    public var erased: ErasedView {
        ErasedView(content)
    }
}

// fallback
@available(iOS 13.0, *)
extension View {
    var erased: ErasedView {
        ErasedView(self)
    }
}
