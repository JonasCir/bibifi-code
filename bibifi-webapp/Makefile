.PHONY: deploy

dev:
	stack exec yesod devel

build:
	stack build

deploy: 
	rm -rf /fs/mc2-application/config; rm -rf /fs/mc2-application/webapp/static; rm -rf /fs/mc2-application/webapp/dist;
	cp -rf ../config /fs/mc2-application/; cp -rf static /fs/mc2-application/webapp; mkdir -p /fs/mc2-application/webapp/dist; cp -rf .stack-work/dist/x86_64-linux/Cabal-1.22.5.0/build /fs/mc2-application/webapp/dist;
	chmod -R o+w /fs/mc2-application/webapp/static/tmp;

clean:
	stack exec cabal clean && stack clean

psql:
	psql -h mc2contest04.umiacs.umd.edu -U mc2contest
