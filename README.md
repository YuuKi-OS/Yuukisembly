# Yuuki Chat — Binary Edition

Chat con la API de Yuuki escrito en assembly puro.
Sin frameworks, sin lenguajes de alto nivel. Solo opcodes.

## Compilar

### Requisitos
```bash
# x86_64 (Linux)
sudo apt install binutils

# ARM64 cross-compile desde x86_64
sudo apt install binutils-aarch64-linux-gnu
```

### Build
```bash
make all          # compila ambos
make yuuki-x86_64 # solo x86_64
make yuuki-arm64  # solo ARM64
```

## Usar

```bash
# x86_64
./yuuki-x86_64

# ARM64 (en hardware ARM o emulado)
./yuuki-arm64
```

## Archivos
- `yuuki-arm64.s`  — opcodes ARM64
- `yuuki-x86_64.s` — opcodes x86_64
- `Makefile`       — compilación

## Nota
El binario se conecta a `opceanai-yuuki-api.hf.space` en el puerto 80.
Necesita resolución DNS y conexión a internet.
