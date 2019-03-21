#!/usr/bin/env node
/*
Downloads and generates all the icons from instructure.design.

Depends on node & cairosvg
 brew install node cairo libffi python
 pip3 install cairosvg

Run this script from the repo root directory
 yarn build-icons
*/

const fs = require('fs')
const path = require('path')
const { execSync } = require('child_process')

const echo = (out) => console.log(out)
const run = (cmd) => execSync(cmd, { stdio: 'inherit' })

// List of all icons we want to export from
// https://github.com/instructure/instructure-ui/tree/master/packages/ui-icons/src/__svg__/Line
// https://github.com/instructure/instructure-ui/tree/master/packages/ui-icons/src/__svg__/Solid
const whitelist = [
  'add',
  'alerts',
  'announcement',
  'arrow-open-left',
  'arrow-open-right',
  'assignment',
  'audio',
  'box',
  'calendar-month',
  'check',
  'complete',
  'courses',
  'dashboard',
  'discussion',
  'document',
  'email',
  'empty',
  'folder',
  'gradebook',
  'group',
  'hamburger',
  'highlighter',
  'instructure',
  'link',
  'lock',
  'lti',
  'marker',
  'mini-arrow-down',
  'mini-arrow-up',
  'module',
  'more',
  'no',
  'outcomes',
  'paint',
  'pdf',
  'prerequisite',
  'question',
  'quiz',
  'refresh',
  'rubric',
  'settings',
  'star',
  'strikethrough',
  'text',
  'trash',
  'trouble', // cancel
  'unlock',
  'user',
  'video',
  'x',
]

const overrides = {
  star: { Line: 'star-light' },
}

const assetsFolder = './Core/Core/Assets.xcassets/InstIcons'

echo('Building Icons...')
run(`rm -rf ${assetsFolder}/*.imageset`)
run(`mkdir -p tmp`)
const icons = new Set()
for (const icon of whitelist) {
  for (const type of [ 'Line', 'Solid' ]) {
    const name = icon.replace(/\W+(\w)/g, (_, c) => c.toUpperCase())
    echo(name + type)
    icons.add(name)
    let slug = (overrides[icon] || {})[type] || icon
    const filepath = `tmp/${name}${type}.svg`
    const folder = `${assetsFolder}/${name}${type}.imageset`
    run(`curl -sSL https://raw.githubusercontent.com/instructure/instructure-ui/master/packages/ui-icons/src/__svg__/${type}/${slug}.svg > ${filepath}`)
    run(`mkdir -p ${folder}`)
    // Icons in tab & nav bar need intrinsic size of 24x24
    run(`cairosvg "${filepath}" -d72 -W24 -H24 -o "${folder}/${name}.pdf"`)
    run(`LC_ALL=C sed -i '' 's/cairo [^ ]* (http:\\/\\/cairographics.org)//' "${folder}/${name}.pdf"`)
    fs.writeFileSync(`${folder}/Contents.json`, `{
  "images" : [
    {
      "idiom" : "universal",
      "filename" : "${name}.pdf"${ !/right|left/i.test(name) ? '' : `,
      "language-direction" : "left-to-right"` }
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  },
  "properties" : {
    "template-rendering-intent" : "template",
    "preserves-vector-representation" : true
  }
}\n`)
  }
}

let lineLength = 12
fs.writeFileSync('./Core/Core/Extensions/UIImageInstIconsExtensions.swift', `//
// Copyright (C) ${new Date().getFullYear()}-present Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

// DO NOT EDIT: this file was generated by build_icons.js

import Foundation

extension UIImage {
    public enum InstIconType: String {
        case line = "Line"
        case solid = "Solid"
    }

    public enum InstIconName: String, CaseIterable {
        case${Array.from(icons).sort().map(name => {
          if (name === 'import') { name = `\`${name}\`` }
          name = ` ${name}`
          lineLength += 1 + name.length
          if (lineLength > 100) {
            name = `\n           ${name}`
            lineLength = name.length
          }
          return name
        }).join(',')}
    }

    public static func icon(_ name: InstIconName, _ type: InstIconType = .line) -> UIImage {
        let named = name.rawValue + type.rawValue
        return UIImage(named: named, in: .core, compatibleWith: nil)!
    }
}
`)

lineLength = 1
fs.writeFileSync('./rn/Teacher/src/images/inst-icons.js', `//
// Copyright (C) ${new Date().getFullYear()}-present Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

// DO NOT EDIT: this file was generated by build_icons.js
// @flow

export type InstIconName =
 ${Array.from(icons).sort().map(name => {
  name = ` '${name}'`
  lineLength += 2 + name.length
  if (lineLength > 100) {
    name = `\n ${name}`
    lineLength = name.length
  }
  return name
}).join(' |')}

export default function icon (name: InstIconName, type: 'line' | 'solid' = 'line') {
  return { uri: \`\${name}\${type[0].toUpperCase()}\${type.slice(1)}\` }
}
`)
