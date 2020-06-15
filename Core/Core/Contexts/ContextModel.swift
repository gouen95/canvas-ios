//
// This file is part of Canvas.
// Copyright (C) 2018-present  Instructure, Inc.
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

import Foundation

public struct ContextModel: Codable, Context, Equatable, Hashable {
    public let contextType: ContextType
    public let id: String

    public static var currentUser: ContextModel {
        return ContextModel(.user, id: "self")
    }

    public init(_ contextType: ContextType, id: String) {
        self.contextType = contextType
        self.id = ID.expandTildeID(id)
    }

    private init?(parts: [Substring]) {
        guard parts.count >= 2 else { return nil }
        let rawValue = parts[0].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "s"))
        guard let contextType = ContextType(rawValue: rawValue) else { return nil }
        self.init(contextType, id: String(parts[1]))
    }

    public init?(canvasContextID: String) {
        self.init(parts: canvasContextID.split(separator: "_"))
    }

    public init?(path: String) {
        self.init(parts: path.split(separator: "/").filter({ (s: Substring) in s != "api" && s != "v1" }))
    }

    public init?(url: URL) {
        self.init(path: url.path)
    }
}