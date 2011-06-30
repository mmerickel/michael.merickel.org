all: clean build

clean:
	rm -rf _build

build:
	run-rstblog build

serve:
	run-rstblog serve

upload:
	s3put -b www.merickel.org -p `pwd`/_build _build
