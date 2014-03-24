SRC=org testOrg
COFFEE=$(SRC:%=src/%.coffee)
JS=$(SRC:%=lib/%.js)

all: alljs tests

alljs:
	coffee --compile --output lib src

tests:
	#node lib/testOrg
