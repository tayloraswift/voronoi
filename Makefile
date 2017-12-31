# OS specific differences
UNAME = ${shell uname}
ifeq ($(UNAME), Darwin)
CC_FLAGS =
LINKER_FLAGS =
endif
ifeq ($(UNAME), Linux)
CC_FLAGS = -Xcc -I/usr/local/include
LINKER_FLAGS = -Xlinker -L/usr/local/lib

endif

debug:
	swift build -c debug -Xswiftc "-D" -Xswiftc "DEBUG" $(CC_FLAGS) $(LINKER_FLAGS)

build:
	swift build -c release $(CC_FLAGS) $(LINKER_FLAGS)

clean:
	swift build --clean

distclean:
	rm -rf Packages
	swift build --clean

.PHONY: build test distclean init
