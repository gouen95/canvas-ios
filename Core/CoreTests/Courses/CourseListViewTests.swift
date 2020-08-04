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

import TestsFoundation
import SwiftUI
@testable import Core

@available(iOS 13.0, *)
extension CourseListView: CustomErasable {
    public var erased: ErasedView { ErasedView(self, body: body) }
}

@available(iOS 13.0, *)
class CourseListViewTests: CoreTestCase {
    lazy var allCourses = environment.subscribe(GetAllCourses())
    lazy var empty = view.erased.first(EmptyViewRepresentable.self)
    lazy var searchBar = view.erased.first(SearchBarView.self)

    lazy var view: CourseListView = {
        let view = CourseListView(allCourses: allCourses.exhaust()).environment(\.appEnvironment, environment)
            as! ModifiedContent<CourseListView, _EnvironmentKeyWritingModifier<AppEnvironment>>
        let controller = HostingController(rootView: view.content)
        window.rootViewController = controller
        return controller.rootView.rootView
    }()

    override func setUp() {
        super.setUp()
        api.mock(allCourses, value: [
            .make(),
            .make(id: "2"), // duplicate name
            .make(id: "3", name: "Course Two"),
            .make(id: "4", name: "Concluded 1", workflow_state: .completed),
            .make(id: "5", name: "Concluded 2", end_at: Clock.now.addDays(-10)),
            .make(id: "6", name: "Concluded 10", term: .make(end_at: Clock.now.addDays(-2))),
            .make(id: "7", name: "Future Course", term: .make(start_at: Clock.now.addDays(2))),
        ])
    }

    func testEmpty() throws {
        api.mock(allCourses, value: [])
        XCTAssertEqual(empty?.title, "No Courses")
        XCTAssertEqual(empty?.imageName, "PandaTeacher")
    }

    func testCoursesListed() throws {
        dump(view.erased)
        print(view.erased.unknownTypes)
        for view in view.erased.findAll(CourseListView.Cell.self) {
            print("\(view.course.id): \(view.course.name ?? "??")")
        }
    }

    func testSearchBar() throws {
        print(view.erased.first(SearchBarView.self)!)
//        let searchBar = try view.inspect().vStack().view(SearchBarView.self, 0).actualView()
//        print(try searchBar.uiView())
//        dump(try view.inspect().vStack()
//        print(erase(view))
    }
}
