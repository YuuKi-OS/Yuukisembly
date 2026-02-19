# ============================================================
# Makefile — Yuuki Chat Binary
# ============================================================

all: yuuki-arm64 yuuki-x86_64

yuuki-arm64: yuuki-arm64.s
	aarch64-linux-gnu-as -o yuuki-arm64.o yuuki-arm64.s
	aarch64-linux-gnu-ld -o yuuki-arm64 yuuki-arm64.o
	rm yuuki-arm64.o

yuuki-x86_64: yuuki-x86_64.s
	as -o yuuki-x86_64.o yuuki-x86_64.s
	ld -o yuuki-x86_64 yuuki-x86_64.o
	rm yuuki-x86_64.o

clean:
	rm -f *.o yuuki-arm64 yuuki-x86_64

.PHONY: all clean
