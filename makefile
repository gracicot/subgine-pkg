PREFIX?=/usr/local

.PHONY: install
install: subgine-pkg
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp subgine-pkg.cmake $(DESTDIR)$(PREFIX)/bin/
	cp subgine-pkg /tmp/
	sed -i "" 's|{%CMAKEPATH%}|""|g' /tmp/subgine-pkg
	rm -f $(DESTDIR)$(PREFIX)/bin/subgine-pkg
	mv /tmp/subgine-pkg $(DESTDIR)$(PREFIX)/bin/
	chmod 755 $(DESTDIR)$(PREFIX)/bin/subgine-pkg
	
.PHONY: uninstall
uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/subgine-pkg
	rm -f $(DESTDIR)$(PREFIX)/bin/subgine-pkg.cmake
