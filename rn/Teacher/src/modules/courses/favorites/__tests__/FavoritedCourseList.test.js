/* @flow */

import 'react-native'
import React from 'react'
import { FavoritedCourseList } from '../FavoritedCourseList.js'
import explore from '../../../../../test/helpers/explore'
import type { CourseProps } from '../../course-prop-types'

// Note: test renderer must be required after react-native.
import renderer from 'react-test-renderer'

const template = {
  ...require('../../../../api/canvas-api/__templates__/course'),
  ...require('../../../../__templates__/helm'),
}

jest.mock('TouchableOpacity', () => 'TouchableOpacity')
jest.mock('TouchableHighlight', () => 'TouchableHighlight')
jest.mock('../../../../routing')

const colors = {
  '1': '#27B9CD',
  '2': '#8F3E97',
  '3': '#8F3E99',
}

const courses: Array<CourseProps> = [
  template.course({
    name: 'Biology 101',
    course_code: 'BIO 101',
    short_name: 'BIO 101',
    id: '1',
    is_favorite: true,
  }),
  template.course({
    name: 'American Literature Psysicks foobar hello world 401',
    course_code: 'LIT 401',
    short_name: 'LIT 401',
    id: '2',
    is_favorite: false,
  }),
  template.course({
    name: 'Foobar 102',
    course_code: 'FOO 102',
    id: '3',
    short_name: 'FOO 102',
    is_favorite: true,
  }),
].map(course => ({ ...course, color: colors[course.id] }))

let defaultProps = {
  navigator: template.navigator(),
  courses,
  customColors: colors,
  refreshCourses: () => {},
  pending: 0,
  refresh: jest.fn(),
  refreshing: false,
}

test('render', () => {
  let tree = renderer.create(
    <FavoritedCourseList {...defaultProps} />
  ).toJSON()
  expect(tree).toMatchSnapshot()
})

test('render without courses', () => {
  let tree = renderer.create(
    <FavoritedCourseList {...defaultProps} courses={[]} />
  ).toJSON()
  expect(tree).toMatchSnapshot()
})

test('select course', () => {
  const course: CourseProps = { ...template.course({ id: 1, is_favorite: true }), color: '#112233' }
  const props = {
    ...defaultProps,
    courses: [course],
    navigator: template.navigator({
      show: jest.fn(),
    }),
  }
  let tree = renderer.create(
    <FavoritedCourseList {...props} />
  ).toJSON()

  const courseCard = explore(tree).selectByID(course.course_code) || {}
  courseCard.props.onPress()
  expect(props.navigator.show).toHaveBeenCalledWith('/courses/1', { modal: true, modalPresentationStyle: 'currentContext', modalTransitionStyle: 'push' })
})

test('opens course preferences', () => {
  const course = template.course({ id: 1, is_favorite: true })
  const props = {
    ...defaultProps,
    courses: [{ ...course, color: '#fff' }],
    navigator: template.navigator({
      show: jest.fn(),
    }),
  }
  let tree = renderer.create(
    <FavoritedCourseList {...props} />
  ).toJSON()

  const kabob = explore(tree).selectByID(`courseCard.kabob_${course.id}`) || {}
  kabob.props.onPress()
  expect(props.navigator.show).toHaveBeenCalledWith(
    '/courses/1/user_preferences',
    { modal: true, modalPresentationStyle: 'formsheet' },
  )
})

test('go to all courses', () => {
  const course = template.course({ id: 1, is_favorite: true })
  const props = {
    ...defaultProps,
    courses: [{ ...course, color: '#fff' }],
    navigator: template.navigator({
      show: jest.fn(),
    }),
  }
  let tree = renderer.create(
    <FavoritedCourseList {...props} />
  ).toJSON()

  const allButton = explore(tree).selectByID('fav-courses.see-all-btn') || {}
  allButton.props.onPress()
  expect(props.navigator.show).toHaveBeenCalledWith('/courses')
})

test('calls navigator.push when a course is selected', () => {
  const props = {
    ...defaultProps,
    navigator: template.navigator({
      show: jest.fn(),
    }),
  }
  let tree = renderer.create(
    <FavoritedCourseList {...props} />
  ).toJSON()

  const allButton = explore(tree).selectByID('fav-courses.see-all-btn') || {}
  allButton.props.onPress()
  expect(props.navigator.show).toHaveBeenCalledWith('/courses')
})

test('calls navigator.show when the edit button is pressed', () => {
  let navigator = template.navigator({
    show: jest.fn(),
  })
  let tree = renderer.create(
    <FavoritedCourseList {...defaultProps} navigator={navigator} />
  )

  tree.getInstance().showFavoritesList()
  expect(navigator.show).toHaveBeenCalledWith(
    '/course_favorites',
    { modal: true, modalPresentationStyle: 'formsheet' }
  )
})

test('press beta feedback button presents feedback modally', () => {
  const props = {
    ...defaultProps,
    navigator: template.navigator({
      show: jest.fn(),
    }),
  }

  let tree = renderer.create(
    <FavoritedCourseList {...props} />
  )

  tree.getInstance().presentBetaFeedback()
  expect(props.navigator.show).toHaveBeenCalledWith(
    '/beta-feedback',
    { modal: true }
  )
})
