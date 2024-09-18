BIKESHED ?= bikeshed
BIKESHED_ARGS ?= --print=plain

.PHONY: lint watch

all: spec.html

spec.html: spec.bs
	$(BIKESHED) $(BIKESHED_ARGS) spec $<

lint: spec.bs
	$(BIKESHED) $(BIKESHED_ARGS) --dry-run --force spec --line-numbers $<

watch: spec.bs
	@echo 'Browse to file://${PWD}/spec.html'
	$(BIKESHED) $(BIKESHED_ARGS) watch $<


