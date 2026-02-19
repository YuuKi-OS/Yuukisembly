<div align="center">

<br>

<img src="https://img.shields.io/badge/%E2%9C%A6-YUUKISEMBLY-000000?style=for-the-badge&labelColor=000000" alt="Yuukisembly" height="50">

<br><br>

# Yuuki Chat — Binary Edition

**Chat con la API de Yuuki en assembly puro.**<br>
**Sin frameworks, sin lenguajes de alto nivel. Solo registros, syscalls y voluntad.**

<br>

<a href="#compilar"><img src="https://img.shields.io/badge/COMPILAR-000000?style=for-the-badge" alt="Compilar"></a>
&nbsp;&nbsp;
<a href="https://github.com/YuuKi-OS/Yuukisembly"><img src="https://img.shields.io/badge/REPOSITORIO-000000?style=for-the-badge" alt="Repositorio"></a>
&nbsp;&nbsp;
<a href="https://github.com/sponsors/aguitauwu"><img src="https://img.shields.io/badge/SPONSOR-000000?style=for-the-badge" alt="Sponsor"></a>

<br><br>

[![License](https://img.shields.io/badge/MIT-222222?style=flat-square&logo=opensourceinitiative&logoColor=white)](LICENSE)
&nbsp;
[![Assembly](https://img.shields.io/badge/Assembly-222222?style=flat-square&logo=assemblyscript&logoColor=white)](#)
&nbsp;
[![x86\_64](https://img.shields.io/badge/x86__64-222222?style=flat-square&logo=intel&logoColor=white)](#)
&nbsp;
[![ARM64](https://img.shields.io/badge/ARM64-222222?style=flat-square&logo=arm&logoColor=white)](#)
&nbsp;
[![Android](https://img.shields.io/badge/Android_(Termux)-222222?style=flat-square&logo=android&logoColor=white)](#)

<br>

---

<br>

<table>
<tr>
<td width="50%" valign="top">

**Chat directo con la API de Yuuki.**<br><br>
Tres targets de arquitectura.<br>
Sin dependencias de alto nivel.<br>
Syscalls directas al kernel.<br>
Conexión HTTP sobre sockets raw.<br>
Compatible con glibc y Bionic.<br>
Compila con GNU Assembler (`as`) y `ld`.

</td>
<td width="50%" valign="top">

**Multiplataforma real.**<br><br>
Linux x86\_64 (PC).<br>
Linux ARM64 (Raspberry Pi, Mac M1).<br>
Android ARM64 (Termux).<br>
<br>
Makefile incluido para compilación rápida.<br>
<br>
Cero frameworks. Cero intérpretes.

</td>
</tr>
</table>

<br>

</div>

---

<br>

<div align="center">

## ¿Qué es Yuukisembly?

</div>

<br>

**Yuukisembly** es un cliente de chat para la [API de Yuuki](https://github.com/YuuKi-OS/Yuuki-api) escrito completamente en **assembly puro**. Sin C, sin Python, sin Node.js — solo instrucciones de máquina, llamadas al sistema y acceso directo a sockets de red.

El proyecto incluye tres implementaciones independientes para cubrir los targets más relevantes: **x86\_64 Linux** para PCs convencionales, **ARM64 Linux** para servidores ARM y Raspberry Pi, y **ARM64 Android** para usar desde Termux. Cada versión adapta las diferencias de ABI, offsets de structs y requisitos del linker de cada plataforma.

Construido con **GNU Assembler (`as`)** y enlazado con **`ld`**. No se requiere nada más.

<br>

---

<br>

<div align="center">

## Versiones

</div>

<br>

| Archivo | Target | Plataforma |
|:--------|:-------|:-----------|
| `yuuki-x86_64.s` | Linux x86\_64 | PC Linux |
| `yuuki-arm64-linux.s` | Linux ARM64 | Raspberry Pi, Mac M1, servidor ARM |
| `yuuki-arm64-android.s` | Android ARM64 | Termux |

<br>

---

<br>

<div align="center">

## Compilar

</div>

<br>

### x86\_64 Linux

```bash
as -o yuuki-x86_64.o yuuki-x86_64.s
ld -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o yuuki-x86_64 yuuki-x86_64.o -lc
./yuuki-x86_64
```

<br>

### ARM64 Linux (Raspberry Pi, servidor)

```bash
as -o yuuki-arm64-linux.o yuuki-arm64-linux.s
ld -dynamic-linker /lib/ld-linux-aarch64.so.1 -o yuuki-arm64-linux yuuki-arm64-linux.o -lc
./yuuki-arm64-linux
```

<br>

### ARM64 Android (Termux)

```bash
pkg install binutils
as -o yuuki-arm64-android.o yuuki-arm64-android.s
ld -dynamic-linker /system/bin/linker64 --pie -o yuuki-arm64-android yuuki-arm64-android.o -lc
./yuuki-arm64-android
```

<br>

### Con Makefile

```bash
make        # compila el target detectado automáticamente
make x86    # fuerza x86_64
make arm    # fuerza ARM64 Linux
make android # fuerza ARM64 Android
```

<br>

---

<br>

<div align="center">

## Diferencias técnicas entre plataformas

</div>

<br>

<table>
<tr>
<td width="50%" valign="top">

<h3>Android (Bionic)</h3>

`struct addrinfo.ai_addr` está en **offset 32**.<br><br>
Requiere `--pie` (Position Independent Executable) al enlazar.<br><br>
El linker dinámico es `/system/bin/linker64` en lugar del estándar de glibc.

</td>
<td width="50%" valign="top">

<h3>Linux (glibc)</h3>

`struct addrinfo.ai_addr` está en **offset 24**.<br><br>
No requiere `--pie` para ejecutables estáticos simples.<br><br>
Linker estándar: `/lib64/ld-linux-x86-64.so.2` (x86\_64) o `/lib/ld-linux-aarch64.so.1` (ARM64).

</td>
</tr>
</table>

<br>

```
                        Yuukisembly
                             |
              +--------------+--------------+
              |              |              |
         x86_64          ARM64           ARM64
          Linux           Linux         Android
              |              |              |
              v              v              v
           glibc          glibc          Bionic
         offset 24      offset 24      offset 32
         no --pie        no --pie       + --pie
              |              |              |
              +--------------+--------------+
                             |
                        API de Yuuki
                       (HTTP / socket)
```

<br>

---

<br>

<div align="center">

## Estructura del repositorio

</div>

<br>

```
Yuukisembly/
    yuuki-x86_64.s          # implementación x86_64 Linux
    yuuki-arm64-linux.s     # implementación ARM64 Linux (glibc)
    yuuki-arm64-android.s   # implementación ARM64 Android (Bionic)
    Makefile                # compilación por target
    LICENSE                 # MIT
```

<br>

---

<br>

<div align="center">

## Proyectos relacionados

</div>

<br>

| Proyecto | Descripción |
|:---------|:------------|
| [Yuuki API](https://github.com/YuuKi-OS/Yuuki-api) | Plataforma de inferencia con gestión de claves y seguimiento de uso |
| [Yuuki Chat](https://github.com/YuuKi-OS/yuuki-chat) | Interfaz web de chat con estilo macOS |
| [yuy](https://github.com/YuuKi-OS/yuy) | CLI para descargar, gestionar y ejecutar modelos Yuuki |
| [yuy-chat](https://github.com/YuuKi-OS/yuy-chat) | Interfaz TUI para conversaciones locales con IA |
| [Yuuki-best](https://huggingface.co/OpceanAI/Yuuki-best) | Pesos del modelo flagship |
| [Yuuki Space](https://huggingface.co/spaces/OpceanAI/Yuuki) | Demo interactivo en la web |

<br>

---

<br>

<div align="center">

## Links

</div>

<br>

<div align="center">

[![Yuuki API](https://img.shields.io/badge/Yuuki_API-Vercel-000000?style=for-the-badge&logo=vercel&logoColor=white)](https://yuuki-api.vercel.app)
&nbsp;
[![Model Weights](https://img.shields.io/badge/Model_Weights-Hugging_Face-ffd21e?style=for-the-badge&logo=huggingface&logoColor=black)](https://huggingface.co/OpceanAI/Yuuki-best)
&nbsp;
[![Live Demo](https://img.shields.io/badge/Live_Demo-Spaces-ffd21e?style=for-the-badge&logo=huggingface&logoColor=black)](https://huggingface.co/spaces/OpceanAI/Yuuki)

<br>

[![YUY CLI](https://img.shields.io/badge/Yuy_CLI-GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/YuuKi-OS/yuy)
&nbsp;
[![YUY Chat](https://img.shields.io/badge/Yuy_Chat-GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/YuuKi-OS/yuy-chat)
&nbsp;
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub_Sponsors-ea4aaa?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/aguitauwu)

</div>

<br>

---

<br>

<div align="center">

## Licencia

</div>

<br>

```
MIT License

Copyright (c) 2026 Yuuki Project

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

<br>

---

<br>

<div align="center">

**Construido con paciencia, un ensamblador y cero abstracciones.**

<br>

[![Yuuki Project](https://img.shields.io/badge/Yuuki_Project-2026-000000?style=for-the-badge)](https://huggingface.co/OpceanAI)

<br>

</div>
