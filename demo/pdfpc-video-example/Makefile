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

# Targets
all : $(PDFDOCS)

clean :
	$(RM) *.aux *.log *.toc *.nav *.out *.snm *.vrb
