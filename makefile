PREFIX?=/usr/local

.PHONY: install
install: subgine-pkg
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp subgine-pkg.cmake $(DESTDIR)$(PREFIX)/bin/
	sed 's|{%CMAKEPATH%}|""|g' subgine-pkg > $(DESTDIR)$(PREFIX)/bin/subgine-pkg
	chmod 755 $(DESTDIR)$(PREFIX)/bin/subgine-pkg
	
.PHONY: uninstall
uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/subgine-pkg
	rm -f $(DESTDIR)$(PREFIX)/bin/subgine-pkg.cmake
