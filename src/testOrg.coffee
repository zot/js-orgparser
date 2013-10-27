require './org.coffee'

test = """
|  a |  b | a + b |
|  4 | 34 |    38 |
| 21 | 31 |    52 |
|  5 |  8 |    13 |
#+TBLFM: $3=$1+$2

* thing
  1. test
  2. two
** subthing
:RESULTS:
test
blah blah
:END:
  3. three

#+begin_src javascript
  console.log('duh')
  console.log('dur')
#+end_src

* TODO [#B] test [2/2]                                                       :duh:
  - [X] one
  - [X] two
"""

#console.log "TEXT: #{parseOrgMode('duh').toJson()}"
node = parseOrgMode(test)
console.log "TEXT: #{node.toJson()}"
console.log "\n\nSAME: #{node.allText() == test}"

#root.parseOrgmode = parseOrgmode
