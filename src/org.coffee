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

root = module.exports

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
RES_LEAD = 1
resultsRE = /(^|\n)#\+RESULTS: *(?:\n|$)/i
resultsLineRE = /^([:|] .*)(?:\n|$)/i

matchLine = (txt)->
  checkMatch(txt, srcStartRE, 'srcStart') ||
  checkMatch(txt, srcEndRE, 'srcEnd') ||
  checkMatch(txt, resultsRE, 'results') ||
  checkMatch(txt, keywordRE, 'keyword') ||
  checkMatch(txt, headlineRE, (m)-> "headline-#{m[HL_LEVEL].length}")

checkMatch = (txt, pat, result)->
  m = txt.match pat
  if m?.index == 0
    if typeof result == 'string' then result else result m
  else false

class Node
  length: -> @text.length
  end: -> @offset + @text.length
  toJson: -> JSON.stringify @toJsonObject(), null, "  "
  allText: -> @text
  block: false
  findNodeAt: (pos)-> if @offset <= pos && pos < @offset + @text.length then this else null
  linkNodes: -> this
  next: null
  prev: null
  top: -> if !@parent then this else @parent.top()

class Headline extends Node
  constructor: (@text, @level, @todo, @priority, @tags, @children, @offset)->
  block: true
  lowerThan: (l)-> l < @level
  length: -> @end() - @offset
  end: ->
    if @children.length
      lastChild = @children[@children.length - 1]
      lastChild.offset + lastChild.length()
    else super()
  type: 'headline'
  toJsonObject: ->
    type: @type
    text: @text
    offset: @offset
    level: @level
    todo: @todo
    priority: @priority
    tags: @tags
    children: (c.toJsonObject() for c in @children)
  allText: -> @text + (c.allText() for c in @children).join ''
  findNodeAt: (pos)->
    if pos < @offset  || @offset + @length() < pos then null
    else if pos < @offset + @text.length then this
    else
      # could binary search this
      for child in @children
        if res = child.findNodeAt pos then return res
      null
  linkNodes: ->
    prev = null
    for c in @children
      c.linkNodes()
      c.parent = this
      c.prev = prev
      if prev then prev.next = c
      prev = c
    this

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
  block: true
  type: 'keyword'
  toJsonObject: ->
    type: @type
    name: @name
    info: @info
    text: @text
    offset: @offset

class Source extends Keyword
  constructor: (@text, @offset, @info, @content, @contentPos)->
  type: 'source'
  toJsonObject: ->
    type: @type
    info: @info
    content: @content
    contentPos: @contentPos
    text: @text
    offset: @offset

class Results extends Keyword
  constructor: (@text, @offset, @contentPos)->
  type: 'results'
  toJsonObject: ->
    type: @type
    text: @text
    offset: @offset
    contentPos: @contentPos

#
# Parse the content of an orgmode file
#
parseOrgMode = (text)->
  [res, rest] = parseHeadline '', 0, 0, undefined, undefined, undefined, text, text.length
  if rest.length then throw new Error("Text left after parsing: #{rest}")
  res.linkNodes()

parseHeadline = (text, offset, level, todo, priority, tags, rest, totalLen)->
  children = []
  while true
    [child, rest] = parseOrgChunk rest, totalLen - rest.length, level
    if !child then break
    if child.lowerThan level
      children.push child
  tagArray = parseTags tags
  [new Headline(text, level, todo, priority, (if tags then tagArray else undefined), children, offset), rest]

parseTags = (text)->
  tagArray = []
  for t in (if text then text.split ':' else [])
    if t then tagArray.push t
  tagArray

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
  results = meat.match resultsRE
  if results?[RES_LEAD].length == 0 then parseResults results[0], offset, meat.substring(results[0].length) + rest
  else if srcStart?[SRC_LEAD].length == 0 then parseSrcBlock srcStart[0], offset, srcStart[SRC_INFO], meat.substring(srcStart[0].length) + rest
  else if keyword?[KW_LEAD].length == 0 then parseKeyword keyword[0], offset, keyword[KW_NAME], keyword[KW_INFO], meat.substring(keyword[0].length) + rest
  else
    pat = keyword
    if srcStart && (!keyword || srcStart.index < keyword.index ) then pat = srcStart
    if pat
      rest = meat.substring(pat.index + pat[1].length) + rest
      meat = meat.substring 0, pat.index + pat[1].length
    [new Meat(meat, offset), rest]

parseResults = (text, offset, rest)->
  oldRest = rest
  while m = rest.match resultsLineRE
    rest = rest.substring m[0].length
  lines = oldRest.substring 0, oldRest.length - rest.length
  [new Results(text + lines, offset, offset + text.length), rest]

parseKeyword = (text, offset, name, info, rest)-> [new Keyword(text, offset, name, info), rest]

parseSrcBlock = (text, offset, info, rest)->
  end = rest.match srcEndRE
  otherSrcStart = rest.match srcStartRE
  if !end then throw new Error("No end for source block at offset: #{offset}, rest: #{rest}")
  else if otherSrcStart && otherSrcStart.index < end.index then throw new Error("No end for first sourcestart at offset: #{offset}")
  else
    [new Source(text + rest.substring(0, end.index + end[0].length), offset, info, rest.substring(0, end.index + end[END_LEAD].length), offset + text.length), rest.substring end.index + end[0].length]

root.parseOrgMode = parseOrgMode
root.Headline = Headline
root.Meat = Meat
root.Keyword = Keyword
root.Source = Source
root.Results = Results
root.headlineRE = headlineRE
root.HL_TAGS = HL_TAGS
root.parseTags = parseTags
root.matchLine = matchLine
