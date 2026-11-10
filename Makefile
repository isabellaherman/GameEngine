BEND ?= bend
SOURCES := main.bend $(wildcard engine/*.bend)

.PHONY: all run cpu check test clean

all: build/esfera

build:
	mkdir -p build

build/esfera: $(SOURCES) | build
	$(BEND) main.bend -o $@

build/test: test.bend $(wildcard engine/*.bend) | build
	$(BEND) test.bend -o $@

run: build/esfera
	./build/esfera

cpu: build/esfera
	./build/esfera +RTS --gpu off

check:
	$(BEND) main.bend --check-only
	$(BEND) test.bend --check-only

test: build/test
	./build/test
	./build/test +RTS --gpu off

clean:
	rm -rf build
