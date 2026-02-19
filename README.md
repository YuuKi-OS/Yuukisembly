# Yuuki Chat — Binary Edition

Chat con la API de Yuuki en assembly puro. Sin frameworks, sin lenguajes de alto nivel.

## Tres versiones

| Archivo | Target | Compilar en |
|---|---|---|
| `yuuki-x86_64.s` | Linux x86_64 | PC Linux |
| `yuuki-arm64-linux.s` | Linux ARM64 | RPi, Mac M1, servidor ARM |
| `yuuki-arm64-android.s` | Android ARM64 | Termux |

## Compilar

### x86_64 Linux
```bash
as -o yuuki-x86_64.o yuuki-x86_64.s
ld -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o yuuki-x86_64 yuuki-x86_64.o -lc
./yuuki-x86_64
```

### ARM64 Linux (Raspberry Pi, servidor)
```bash
as -o yuuki-arm64-linux.o yuuki-arm64-linux.s
ld -dynamic-linker /lib/ld-linux-aarch64.so.1 -o yuuki-arm64-linux yuuki-arm64-linux.o -lc
./yuuki-arm64-linux
```

### ARM64 Android (Termux)
```bash
pkg install binutils
as -o yuuki-arm64-android.o yuuki-arm64-android.s
ld -dynamic-linker /system/bin/linker64 --pie -o yuuki-arm64-android yuuki-arm64-android.o -lc
./yuuki-arm64-android
```

## Diferencias técnicas
- **Android (Bionic)**: `struct addrinfo.ai_addr` está en offset 32
- **Linux (glibc)**: `struct addrinfo.ai_addr` está en offset 24
- **Android**: requiere `--pie` (Position Independent Executable)
