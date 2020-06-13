FILE=pdfpc

all: validate

validate: build
	cd $(FILE); ctan-o-mat $(FILE).pkg

build-doc:
	cd $(FILE); pdflatex $(FILE)-doc.tex; pdflatex $(FILE)-doc.tex

build: build-doc
	cd $(FILE); ctanify --no-tds $(FILE).sty $(FILE)-doc.tex $(FILE)-doc.pdf README.md
