SLIDES := $(patsubst %.markdown,%-slides-local.pdf,$(wildcard *.markdown))
HANDOUTS := $(patsubst %.markdown,%-handouts-local.pdf,$(wildcard *.markdown))
NOTES := $(patsubst %.markdown,%-notes-local.pdf,$(wildcard *.markdown))
export PATH := /Library/TeX/texbin:$(PATH)
PANDOC := /usr/local/bin/pandoc

COMMON_OPTS := --defaults=settings.yaml --listings
SLIDES_OPTS := $(COMMON_OPTS)
HANDOUT_OPTS := -V handout $(COMMON_OPTS)
NOTES_OPTS := $(COMMON_OPTS) --metadata=beameroption="show only notes"

all: $(SLIDES) $(HANDOUTS) $(NOTES)
#all: $(HANDOUTS) $(NOTES)

%-slides-local.pdf: %.markdown
	$(PANDOC) $(SLIDES_OPTS) $^ -o $@
%-handouts-local.pdf: %.markdown
	$(PANDOC) $(HANDOUT_OPTS) $^ -o $@
%-notes-local.pdf: %.markdown
	$(PANDOC) $(NOTES_OPTS) $^ -o $@

clean: 
	rm -f $(SLIDES) $(HANDOUTS) $(NOTES)
