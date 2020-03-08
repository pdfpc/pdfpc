FILE=pdfpc

all: validate

validate: build
	cd $(FILE); ctan-o-mat $(FILE).pkg

build-doc:
	cd $(FILE); pdflatex $(FILE)-doc.dtx; mv $(FILE)-doc.pdf $(FILE).pdf

build-src:
	cd $(FILE); latex $(FILE).ins

build: build-src build-doc
	cd $(FILE); ctanify --no-tds $(FILE).ins $(FILE)-doc.dtx $(FILE).pdf README.md
