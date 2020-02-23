FILE=pdfpc

all: validate

validate: build
	cd $(FILE); ctan-o-mat $(FILE).pkg

build:
	cd $(FILE); latex $(FILE).ins; ctanify $(FILE).ins README.md
