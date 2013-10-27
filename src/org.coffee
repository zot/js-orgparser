###
Copyright (C) 2013, Bill Burdick, Tiny Concepts: https://github.com/zot/Leisure

(licensed with ZLIB license)

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
claim that you wrote the original software. If you use this software
in a product, an acknowledgment in the product documentation would be
appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not be
misrepresented as being the original software.

3. This notice may not be removed or altered from any source distribution.
###

#
# Parse orgmode files
#

todoKeywords = ['TODO', 'DONE']

buildHeadlineRE = ->
  new RegExp '(^|\\n)((\\*+) *(' + todoKeywords.join('|') + ')?(?: *(?:\\[#(A|B|C)\\]))?.*?(:.*:)? *(?:\\n|$))'
HL_LEAD = 1
HL_TEXT = 2
HL_LEVEL = 3
HL_TODO = 4
HL_PRIORITY = 5
HL_TAGS = 6
headlineRE = buildHeadlineRE()
todoRE = /(\*+) *(TODO|DONE)/
tagsRE = /:[^:]*/
KW_LEAD = 1
KW_NAME = 2
KW_INFO = 3
keywordRE = /(^|\n)#\+([^:].*): *(.*)(?:\n|$)/i
SRC_LEAD = 1
SRC_INFO = 2
srcStartRE = /(^|\n)#\+BEGIN_SRC *(.*)(?:\n|$)/i
END_LEAD = 1
srcEndRE = /(^|\n)#\+END_SRC( *)(?:\n|$)/i

class Node
  length: -> @text.length
  toJson: -> JSON.stringify @toJsonObject(), null, "  "
  allText: -> @text

class Headline extends Node
  constructor: (@text, @level, @todo, @priority, @tags, @children, @offset)->
  lowerThan: (l)-> l < @level
  length: ->
    if @children.length
      lastChild = @children[@children.length - 1]
      lastChild.offset + lastChild.length() - @offset
    else super.length()
  toJsonObject: ->
    type: 'headline'
    text: @text
    offset: @offset
    level: @level
    todo: @todo
    priority: @priority
    tags: @tags
    children: (c.toJsonObject() for c in @children)
  allText: -> @text + (c.allText() for c in @children).join ''

class Meat extends Node
  constructor: (@text, @offset)->
  lowerThan: (l)-> true
  type: 'meat'
  toJsonObject: ->
    type: @type
    text: @text
    offset: @offset

class Keyword extends Meat
  constructor: (@text, @offset, @name, @info)->
  toJsonObject: ->
    type: 'keyword'
    name: @name
    info: @info
    text: @text
    offset: @offset

class Source extends Meat
  constructor: (@text, @offset, @info, @content, @contentPos)->
  toJsonObject: ->
    type: 'source'
    info: @info
    content: @content
    contentPos: @contentPos
    text: @text
    offset: @offset

#
# Parse the content of an orgmode file
#
parseOrgMode = (text)->
  [res, rest] = parseHeadline '', 0, 0, undefined, undefined, undefined, text, text.length
  if rest.length then throw new Error("Text left after parsing: #{rest}")
  res

parseHeadline = (text, offset, level, todo, priority, tags, rest, totalLen)->
  children = []
  while true
    [child, rest] = parseOrgChunk rest, totalLen - rest.length, level
    if !child then break
    if child.lowerThan level
      children.push child
  tagArray = []
  for t in (if tags then tags.split ':' else [])
    if t then tagArray.push t
  [new Headline(text, level, todo, priority, (if tags then tagArray else undefined), children, offset), rest]

parseOrgChunk = (text, offset, level)->
  if !text then [null, text]
  else
    m = text.match headlineRE
    if m?.index == 0 && m[HL_LEAD].length == 0
      if m[HL_LEVEL].length <= level then [null, text]
      else
        parseHeadline m[HL_TEXT], offset + m[HL_LEAD].length, m[HL_LEVEL].length, m[HL_TODO], m[HL_PRIORITY], m[HL_TAGS], text.substring(m[0].length), offset + text.length
    else
      meat = text.substring 0, if m then m.index + m[HL_LEAD].length else text.length
      parseMeat meat, offset, text.substring meat.length

parseMeat = (meat, offset, rest)->
  srcStart = meat.match srcStartRE
  keyword = meat.match keywordRE
  if keyword?[KW_LEAD].length == 0 then parseKeyword keyword[0], offset, keyword[KW_NAME], keyword[KW_INFO], meat.substring(keyword[0].length) + rest
  else if srcStart?[SRC_LEAD].length == 0 then parseSrcBlock srcStart[0], offset, srcStart[SRC_INFO], meat.substring(srcStart[0].length) + rest
  else
    pat = keyword
    if srcStart && (!keyword || srcStart.index < keyword.index ) then pat = srcStart
    if pat
      rest = meat.substring(pat.index + pat[1].length) + rest
      meat = meat.substring 0, pat.index + pat[1].length
    [new Meat(meat, offset), rest]

parseKeyword = (text, offset, name, info, rest)-> [new Keyword(text, offset, name, info), rest]

parseSrcBlock = (text, offset, info, rest)->
  end = rest.match srcEndRE
  otherSrcStart = rest.match srcStartRE
  if !end then throw new Error("No end for source block at offset: #{offset}, rest: #{rest}")
  else if otherSrcStart && otherSrcStart.index < end.index then throw new Error("No end for first sourcestart at offset: #{offset}")
  else
    [new Source(text + rest.substring(0, end.index + end[0].length), offset, info, rest.substring(0, end.index + end[END_LEAD].length), offset + text.length), rest.substring end.index + end[0].length]

root.parseOrgMode = parseOrgMode
