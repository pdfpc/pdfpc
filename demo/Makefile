# Suffixes
.SUFFIXES : .tex .pdf

# Executables
PDFLATEX = pdflatex

RM = rm -f

# Rules
.tex.pdf :
	$(PDFLATEX) $< && $(PDFLATEX) $<

# Config
DEMO  = pdfpc-demo

PDFDOCS = $(DEMO).pdf

# Targets
all : $(PDFDOCS)

clean :
	$(RM) *.aux *.log *.toc *.nav *.out *.snm *.vrb
