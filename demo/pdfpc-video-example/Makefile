# Suffixes
.SUFFIXES : .tex .pdf

# Executables
PDFLATEX = pdflatex

RM = rm -f

# Rules
.tex.pdf :
	$(PDFLATEX) $< && $(PDFLATEX) $<

# Config
DEMO  = video-example

PDFDOCS = $(DEMO).pdf

zipfile: $(PDFDOCS)
	zip -j $(DEMO).zip $(PDFDOCS) $(DEMO).tex apollo17.avi apollo17.jpg

# Targets
all : $(PDFDOCS) zipfile

clean :
	$(RM) *.aux *.log *.toc *.nav *.out *.snm *.vrb
