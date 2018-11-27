PATH:=$(PATH):$(CURDIR)/bin
KLAB_EVMS_PATH:=$(CURDIR)/evm-semantics
export PATH
export KLAB_EVMS_PATH

LIBEXEC_DIR=$(CURDIR)/libexec
HASKELL_DIR=$(CURDIR)/haskell
GAS_SOLVER=$(HASKELL_DIR)/result/bin/k-gas-analyser

# shell output colouring:
red:=$(shell tput setaf 1)
green:=$(shell tput setaf 2)
yellow:=$(shell tput setaf 3)
bold:=$(shell tput bold)
reset:=$(shell tput sgr0)

default: deps

clean:
	rm -fdR out/* evm-semantics $(TMPDIR)/klab
	git submodule update --init -- evm-semantics

deps: deps-kevm deps-npm

deps-kevm:
	git submodule update --init -- evm-semantics
	cd evm-semantics \
		&& make k-deps tangle-deps -B \
		&& make build-java -B

deps-npm:
	npm install

deps-haskell:
	cd haskell/ && make
	ln -s $(GAS_SOLVER) $(LIBEXEC_DIR)/klab-gas-analyser

media: media/introduction.pdf

media/%.pdf: media/%.md
	pandoc --from markdown --to beamer --output $@ $<

KLAB = $(CURDIR)/bin/klab

start-server: server.PID
	$(info $(bold)STARTED$(reset) KLab server.)

server.PID:
	mkdir -p $(TMPDIR) && { nohup $(KLAB) server > nohup.out 2>&1 & echo $$! > $@; }

stop-server: server.PID
	kill -- -$$(ps -o pgid= `cat $<` | grep -o '[0-9]*') && rm $< && echo "$(bold)STOPPED$(reset) Klab server."

test_dir=examples
test_examples=$(wildcard $(test_dir)/*)

build-test: $(test_examples:=.build)

# this target builds specs with exact, exhaustive
# treatment of gas and can only be run after one pass of `klab run`
build-test-exactgas : $(test_examples:=.build-exactgas)

%.build:
	cd $* && $(KLAB) build

%.build-exactgas:
	cd $* && $(KLAB) solve-gas && $(KLAB) build --exact-gas

# workaround for patsubst in pattern matching target below
PERCENT := %

.SECONDEXPANSION:

test: $$(patsubst $$(PERCENT),$$(PERCENT).proof,$$(wildcard $(CURDIR)/examples/*/out/specs/*.k))
	$(info $(bold)CHECKED$(reset) all test specs.)

%.k.proof: %.k
	$(info Proof $(bold)STARTING$(reset): $<)
	@ cd $(dir $*)../../ && $(KLAB) run --headless --force --spec $< && echo "$(green)Proof $(bold)SUCCESS$(reset): $<"

SHELL = bash
DIRS = {bin,libexec}
PREFIX ?= /usr/local

DIRS:; mkdir -p $(PREFIX)/$(DIRS)
files = $(shell ls -d $(DIRS)/*)
link: uninstall DIRS; for x in $(files); do \
	ln -s `pwd`/$$x $(PREFIX)/$$x; done
uninstall:; rm -rf $(addprefix $(PREFIX)/,$(files))
