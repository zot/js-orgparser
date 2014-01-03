SRC=org testOrg
COFFEE=$(SRC:%=src/%.coffee)
JS=$(SRC:%=lib/%.js)

all: $(JS) tests

$(JS): $(COFFEE)
	(cd src; coffee -m -c $(?:src/%=%))
	cp $(?:%.coffee=%.*) lib

tests:
	node lib/testOrg
