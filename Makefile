SRC=org testOrg
COFFEE=$(SRC:%=src/%.coffee)
JS=$(SRC:%=lib/%.js)

all: $(JS)

$(JS): $(COFFEE)
	(cd src; coffee -m -c $(?:src/%=%))
	cp $(?:%.coffee=%).* lib
