SHELL=/bin/bash
TEMP := $(shell mktemp)

all:
	@vim -c "redir! > $(TEMP) | echo findfile('autoload/vunit.vim', escape(&rtp, ' ')) | quit"
	@if [ -n "$$(cat $(TEMP))" ] ; then \
			vunit=$$(dirname $$(dirname $$(cat $(TEMP)))) ; \
			if [ -e $$vunit/bin/vunit ] ; then \
				mkdir -p build/test/temp ; \
				tar -C build/test/temp -xf test/git.tar.gz ; \
				tar -C build/test/temp -xf test/mercurial.tar.gz ; \
				$$vunit/bin/vunit -d build/test -r $$PWD -p plugin/vcs.vim -t test/**/*.vim ; \
			else \
				echo "Unable to locate vunit script" ; \
			fi ; \
		else \
			echo "Unable to locate vunit in vim's runtimepath" ; \
		fi
	@rm $(TEMP)

clean:
	@rm -Rf build 2> /dev/null || true