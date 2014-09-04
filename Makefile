COFFEE = ./node_modules/.bin/coffee

all: lib/bs.js lib/main.js

install-modules:
	npm install

clean:
	rm -f lib/*.js
	rm -f lib/*.map

.PHONY: all install-modules clean

lib/%.js lib/%.map: src/%.coffee
	@echo "[coffee] $< → $@"
	@mkdir -p lib
	@$(COFFEE) -j \
		-i $< \
		-o $@ \
		--source-map-file $(@:.js=.map)
