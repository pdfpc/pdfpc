FILE=pdfpc

all: validate

validate: build
	cd $(FILE); ctan-o-mat $(FILE).pkg

build-doc:
	cd $(FILE); pdflatex $(FILE)-doc.dtx; mv $(FILE)-doc.pdf $(FILE).pdf

build-src:
	cd $(FILE); latex $(FILE).ins

build: build-src build-doc
	cd $(FILE); ctanify $(FILE).ins $(FILE).pdf README.md
