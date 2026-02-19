# ============================================================
# Makefile — Yuuki Chat Binary (TLS Edition)
# ============================================================

all: yuuki-x86_64 yuuki-arm64-linux yuuki-arm64-android

# x86_64 Linux
yuuki-x86_64: yuuki-x86_64.s
	as -o yuuki-x86_64.o yuuki-x86_64.s
	ld -dynamic-linker /lib64/ld-linux-x86-64.so.2 \
	   -o yuuki-x86_64 yuuki-x86_64.o -lc -lssl -lcrypto
	rm yuuki-x86_64.o

# ARM64 Linux (Raspberry Pi, servidor, Mac M1 con Linux)
yuuki-arm64-linux: yuuki-arm64-linux.s
	as -o yuuki-arm64-linux.o yuuki-arm64-linux.s
	ld -dynamic-linker /lib/ld-linux-aarch64.so.1 \
	   -o yuuki-arm64-linux yuuki-arm64-linux.o -lc -lssl -lcrypto
	rm yuuki-arm64-linux.o

# ARM64 Android (Termux)
yuuki-arm64-android: yuuki-arm64-android.s
	as -o yuuki-arm64-android.o yuuki-arm64-android.s
	ld -dynamic-linker /system/bin/linker64 --pie \
	   -rpath /data/data/com.termux/files/usr/lib \
	   -L/data/data/com.termux/files/usr/lib \
	   -o yuuki-arm64-android yuuki-arm64-android.o -lc -lssl -lcrypto
	rm yuuki-arm64-android.o

clean:
	rm -f *.o yuuki-x86_64 yuuki-arm64-linux yuuki-arm64-android

.PHONY: all clean
