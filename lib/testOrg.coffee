{
  parseOrgMode,
  Headline,
  Meat,
  headlineRE,
} = require './org'
assert = require 'assert'

test = """
|  a |  b | a + b |
|  4 | 34 |    38 |
| 21 | 31 |    52 |
|  5 |  8 |    13 |
#+TBLFM: $3=$1+$2

* thing :a
  1. test
  2. two
** subthing :b:
:RESULTS:
test
blah blah
:END:
  3. three

#+begin_src javascript
  console.log('duh')
  console.log('dur')
#+end_sr

- [ ] one
  - [X] two
- duh

* TODO [#B] test [2/2]                                                       :duh:
test *bold* word /italic/ fred _underline_
link [[duh]] [[dur][description *bold* +strike+ florp]]
duh
#+BEGIN_HTML
blah blah blah
#+END_HTML
* Blorfl
"""

#console.log "TEXT: #{parseOrgMode('duh').toJson()}"
node = parseOrgMode(test)
console.log "ORG: #{node.toJson()}"
#console.log "\n\nSAME: #{node.allText() == test}"

assertEq = (expected, actual, msg)->
  assert (expected == actual), msg || "Expected <#{expected}>, but got <#{actual}>"

assertInst = (inst, cl, msg)->
  assert (inst instanceof cl), msg || "Expected instance of #{cl} but got #{inst}"

assertInst node.children[2], Meat
assertInst node.children[3], Headline
#m = node.children[3].text.match headlineRE
#console.log "Headline match: #{JSON.stringify m, '  '}"
#console.log "main headline:\n#{node.children[3]}"
assertEq '["a"]', JSON.stringify(node.children[3].allTags().sort())
assertEq '["a","b"]', JSON.stringify(node.children[3].children[1].allTags().sort())
