SRC=org testOrg
COFFEE=$(SRC:%=src/%.coffee)
JS=$(SRC:%=lib/%.js)

all: $(JS)

$(JS): $(COFFEE)
	coffee -o lib -c $?
