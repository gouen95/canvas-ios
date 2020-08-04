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
public struct ErasedView {
    let view: Any
    let viewType: KnownViewType.Type
    let subViews: [ErasedView]?
    var isUnknown: Bool { subViews == nil }

    public init(_ view: Any, viewType: KnownViewType.Type = ViewType.ClassifiedView.self, subViews: [ErasedView]?) {
        self.view = view
        self.viewType = viewType
        self.subViews = subViews
    }

    public init<V: View, Body: View>(_ view: V, body: Body) throws {
        self.init(view, subViews: [try ErasedView(body)])
    }

    public init(_ view: Any) throws {
        if let view = view as? CustomErasable {
            self = try view.erased()
        } else {
            self.view = view
            self.viewType = ViewType.ClassifiedView.self
            self.subViews = nil
        }
    }

    public init<T: SingleViewContent>(_ view: Any, _ viewType: T.Type) throws {
        try self.init(viewType.child(Content(view)).view)
    }

    public init<T: KnownViewType>(_ view: Any, _ viewType: T.Type) throws where T: MultipleViewContent {
        self.view = view
        self.viewType = viewType
        self.subViews = try viewType.children(Content(view)).map { try ErasedView($0.view) }
    }

    public var lazy: AnySequence<ErasedView> {
        AnySequence<ErasedView>([
            [self],
            (subViews ?? []).flatMap { $0.lazy },
        ].lazy.joined())
    }

    public func findAll<V: View>(_: V.Type = V.self) -> [V] {
        Array(compactMap { $0.view as? V })
    }

    public func findAll<V: KnownViewType>(_ type: V.Type) -> [ErasedView] {
        filter { $0.viewType == type }
    }

    public func first<V: View>(_: V.Type = V.self) -> V? {
        compactMap { $0.view as? V }.first
    }

    public func forEach(_ callback: (ErasedView) -> Void) {
        callback(self)
        for view in subViews ?? [] {
            view.forEach(callback)
        }
    }

    public var unknownTypes: Set<String> {
        var types = Set<String>()
        forEach { view in
            if view.isUnknown {
                types.insert("\(type(of: view))")
            }
        }
        return types
    }
}

@available(iOS 13.0, *)
extension ErasedView: Sequence {
    public typealias Element = ErasedView
    public typealias Iterator = AnySequence<ErasedView>.Iterator

    public __consuming func makeIterator() -> AnySequence<ErasedView>.Iterator {
        lazy.makeIterator()
    }
}

@available(iOS 13.0, *)
public protocol CustomErasable {
    func erased() throws -> ErasedView
}

@available(iOS 13.0, *)
extension _ConditionalContent: CustomErasable {
    public func erased() throws -> ErasedView {
        try ErasedView(self, ViewType.ConditionalContent.self)
    }
}

@available(iOS 13.0, *)
extension HStack: CustomErasable {
    public func erased() throws -> ErasedView {
        try ErasedView(self, ViewType.HStack.self)
    }
}

@available(iOS 13.0, *)
extension VStack: CustomErasable {
    public func erased() throws -> ErasedView {
        try ErasedView(self, ViewType.VStack.self)
    }
}

@available(iOS 13.0, *)
extension ZStack: CustomErasable {
    public func erased() throws -> ErasedView {
        try ErasedView(self, ViewType.ZStack.self)
    }
}

@available(iOS 13.0, *)
extension Form: CustomErasable {
    public func erased() throws -> ErasedView {
        try ErasedView(self, ViewType.Form.self)
    }
}

@available(iOS 13.0, *)
extension Section: CustomErasable {
    public func erased() throws -> ErasedView {
        try ErasedView(self, ViewType.Section.self)
    }
}

@available(iOS 13.0, *)
extension ForEach: CustomErasable {
    public func erased() throws -> ErasedView {
        typealias Builder = (Data.Element) -> Content
        let data = try Inspector.attribute(label: "data", value: self, type: Data.self)
        let builder = try! Inspector.attribute(label: "content", value: self, type: Builder.self)
        return try ErasedView(self, viewType: ViewType.ForEach.self, subViews: data.map { try ErasedView(builder($0)) })
    }
}

@available(iOS 13.0, *)
extension ModifiedContent: CustomErasable {
    public func erased() throws -> ErasedView {
        try ErasedView(content)
    }
}

// fallback
@available(iOS 13.0, *)
extension View {
    public func erased() throws -> ErasedView {
        try ErasedView(self)
    }
}
