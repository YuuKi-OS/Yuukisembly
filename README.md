<div align="center">

<br>

<img src="https://img.shields.io/badge/%E2%9C%A6-YUUKISEMBLY-000000?style=for-the-badge&labelColor=000000" alt="Yuukisembly" height="50">

<br><br>

# Yuuki Chat — Binary Edition

**Chat with the Yuuki API in pure assembly.**<br>
**No frameworks, no high-level languages. Just registers, syscalls, TLS, and willpower.**

<br>

<a href="#build"><img src="https://img.shields.io/badge/BUILD-000000?style=for-the-badge" alt="Build"></a>
&nbsp;&nbsp;
<a href="https://github.com/YuuKi-OS/Yuukisembly"><img src="https://img.shields.io/badge/REPOSITORY-000000?style=for-the-badge" alt="Repository"></a>
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
[![OpenSSL](https://img.shields.io/badge/OpenSSL_TLS-222222?style=flat-square&logo=openssl&logoColor=white)](#)
&nbsp;
[![Android](https://img.shields.io/badge/Android_(Termux)-222222?style=flat-square&logo=android&logoColor=white)](#)

<br>

---

<br>

<table>
<tr>
<td width="50%" valign="top">

**Direct chat with the Yuuki API.**<br><br>
Three independent architecture targets.<br>
Full TLS on all three platforms.<br>
Native OpenSSL calls from assembly registers.<br>
HTTP/1.1 over raw TLS sockets.<br>
DNS resolution via `getaddrinfo`.<br>
Builds with GNU Assembler (`as`) and `ld`.

</td>
<td width="50%" valign="top">

**Truly cross-platform.**<br><br>
Linux x86\_64 (PC).<br>
Linux ARM64 (Raspberry Pi, Mac M1).<br>
Android ARM64 (Termux).<br>
<br>
Makefile included for fast builds.<br>
<br>
Zero frameworks. Zero interpreters.

</td>
</tr>
</table>

<br>

</div>

---

<br>

<div align="center">

## What is Yuukisembly?

</div>

<br>

**Yuukisembly** is a chat client for the [Yuuki API](https://github.com/YuuKi-OS/Yuuki-api) written entirely in **pure assembly**. No C, no Python, no Node.js — just machine instructions, system calls, and direct access to network sockets.

Every version implements the full HTTPS stack from scratch in assembly: **DNS resolution** via `getaddrinfo`, **TCP socket** via syscall, **TLS handshake** by calling OpenSSL functions directly from registers (`SSL_CTX_new`, `SSL_connect`, `SSL_write`, `SSL_read`), and **HTTP/1.1** request construction and response parsing with manual `\r\n\r\n` header skipping — byte by byte, no stdlib.

The three implementations are not ports of each other. Each one is written from scratch for its target, adapting to a completely different ABI, syscall table, struct layout, and linker.

Built with **GNU Assembler (`as`)** and linked with **`ld`**, **`-lssl`**, and **`-lcrypto`**. Nothing else.

<br>

---

<br>

<div align="center">

## Targets

</div>

<br>

| File | Target | Platform | ABI | TLS |
|:-----|:-------|:---------|:----|:----|
| `yuuki-x86_64.s` | Linux x86\_64 | Linux PC | System V AMD64 | OpenSSL via glibc |
| `yuuki-arm64-linux.s` | Linux ARM64 | Raspberry Pi, Mac M1, ARM server | AAPCS64 / glibc | OpenSSL via glibc |
| `yuuki-arm64-android.s` | Android ARM64 | Termux | AAPCS64 / Bionic | OpenSSL via Bionic |

<br>

---

<br>

<div align="center">

## Build

</div>

<br>

### x86\_64 Linux

```bash
sudo apt install binutils libssl-dev
as -o yuuki-x86_64.o yuuki-x86_64.s
ld -dynamic-linker /lib64/ld-linux-x86-64.so.2 \
   -o yuuki-x86_64 yuuki-x86_64.o -lc -lssl -lcrypto
./yuuki-x86_64
```

<br>

### ARM64 Linux (Raspberry Pi, server)

```bash
sudo apt install binutils libssl-dev
as -o yuuki-arm64-linux.o yuuki-arm64-linux.s
ld -dynamic-linker /lib/ld-linux-aarch64.so.1 \
   -o yuuki-arm64-linux yuuki-arm64-linux.o -lc -lssl -lcrypto
./yuuki-arm64-linux
```

<br>

### ARM64 Android (Termux)

```bash
pkg install binutils openssl
as -o yuuki-arm64-android.o yuuki-arm64-android.s
ld -dynamic-linker /system/bin/linker64 --pie \
   -rpath /data/data/com.termux/files/usr/lib \
   -L/data/data/com.termux/files/usr/lib \
   -o yuuki-arm64-android yuuki-arm64-android.o -lc -lssl -lcrypto
./yuuki-arm64-android
```

<br>

### With Makefile

```bash
make         # auto-detects target
make x86     # force x86_64
make arm     # force ARM64 Linux
make android # force ARM64 Android
```

<br>

---

<br>

<div align="center">

## How the TLS Stack Works

</div>

<br>

There are no wrappers. Each version calls OpenSSL directly from assembly registers, following the platform ABI entirely by hand.

```
  input_buf (stdin)
       │
       ▼
  build_json          ← escape " and \ byte by byte (no stdlib)
       │
       ▼
  getaddrinfo         ← DNS resolution (libc extern)
       │
       ▼
  SYS_socket          ← raw TCP socket syscall
  SYS_connect         ← TCP connect syscall
       │
       ▼
  TLS_client_method   ┐
  SSL_CTX_new         │
  SSL_new             ├─ OpenSSL externs called directly from registers
  SSL_set_fd          │
  SSL_connect         ┘
       │
       ▼
  SSL_write           ← send HTTP/1.1 POST request
  SSL_read (loop)     ← receive full response
       │
       ▼
  skip_headers        ← find \r\n\r\n manually, byte by byte
       │
       ▼
  SYS_write           ← print response to stdout
```

<br>

---

<br>

<div align="center">

## Technical Differences Between Targets

</div>

<br>

<table>
<tr>
<td width="33%" valign="top">

<h3>x86_64 Linux</h3>

**Calling convention:** System V AMD64.<br>
Args in `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`.<br><br>

**Syscall instruction:** `syscall`<br><br>

**Syscall numbers:**<br>
`read=0`, `write=1`, `close=3`<br>
`socket=41`, `connect=42`, `exit=60`<br><br>

**Stack alignment:** 16 bytes required before any `call`. Managed manually with `sub $8, %rsp` after odd-count pushes.<br><br>

**`struct addrinfo.ai_addr`:** offset `24` (glibc).<br><br>

**`--pie`:** not required.

</td>
<td width="33%" valign="top">

<h3>ARM64 Linux</h3>

**Calling convention:** AAPCS64.<br>
Args in `x0`–`x7`. Callee-saved: `x19`–`x28`.<br><br>

**Syscall instruction:** `svc #0`<br><br>

**Syscall numbers:**<br>
`read=63`, `write=64`, `close=57`<br>
`socket=198`, `connect=203`, `exit=93`<br><br>

**Stack alignment:** 16 bytes. Frame managed with `stp x29, x30, [sp, #-N]!` / `ldp` pairs.<br><br>

**`struct addrinfo.ai_addr`:** offset `24` (glibc).<br><br>

**`--pie`:** not required.

</td>
<td width="33%" valign="top">

<h3>ARM64 Android</h3>

**Calling convention:** AAPCS64 (same registers as Linux ARM64).<br><br>

**Syscall instruction:** `svc #0`<br><br>

**Syscall numbers:** same as ARM64 Linux.<br><br>

**Stack alignment:** 16 bytes. Same frame convention.<br><br>

**`struct addrinfo.ai_addr`:** offset `32` (Bionic). This is the critical difference — using `24` here silently reads the wrong pointer.<br><br>

**`--pie`:** required by Android's linker.<br>
**`-rpath` / `-L`:** required to find Termux OpenSSL.

</td>
</tr>
</table>

<br>

### Syscall table comparison

| Operation | x86\_64 | ARM64 Linux | ARM64 Android |
|:----------|:--------|:------------|:--------------|
| `read` | `0` | `63` | `63` |
| `write` | `1` | `64` | `64` |
| `close` | `3` | `57` | `57` |
| `socket` | `41` | `198` | `198` |
| `connect` | `42` | `203` | `203` |
| `exit` | `60` | `93` | `93` |
| instruction | `syscall` | `svc #0` | `svc #0` |

<br>

### struct addrinfo offsets

| Field | x86\_64 (glibc) | ARM64 Linux (glibc) | ARM64 Android (Bionic) |
|:------|:----------------|:--------------------|:-----------------------|
| `ai_flags` | `0` | `0` | `0` |
| `ai_family` | `4` | `4` | `4` |
| `ai_socktype` | `8` | `8` | `8` |
| `ai_protocol` | `12` | `12` | `12` |
| `ai_addrlen` | `16` | `16` | `16` |
| `ai_addr` | `24` | `24` | **`32`** |
| `ai_canonname` | `32` | `32` | `24` |
| `ai_next` | `40` | `40` | `40` |

The swap between `ai_addr` and `ai_canonname` in Bionic is the single most common breakage point when porting network code from Linux to Android.

<br>

---

<br>

<div align="center">

## Repository Layout

</div>

<br>

```
Yuukisembly/
    yuuki-x86_64.s          # x86_64 Linux  — System V AMD64 ABI, TLS, HTTP
    yuuki-arm64-linux.s     # ARM64 Linux   — AAPCS64 / glibc, TLS, HTTP
    yuuki-arm64-android.s   # ARM64 Android — AAPCS64 / Bionic, TLS, HTTP, PIE
    Makefile                # per-target build rules
    LICENSE                 # MIT
```

<br>

---

<br>

<div align="center">

## Related Projects

</div>

<br>

| Project | Description |
|:--------|:------------|
| [Yuuki API](https://github.com/YuuKi-OS/Yuuki-api) | Inference platform with key management and usage tracking |
| [Yuuki Chat](https://github.com/YuuKi-OS/yuuki-chat) | macOS-styled web chat interface |
| [yuy](https://github.com/YuuKi-OS/yuy) | CLI for downloading, managing, and running Yuuki models |
| [yuy-chat](https://github.com/YuuKi-OS/yuy-chat) | TUI chat interface for local AI conversations |
| [Yuuki-best](https://huggingface.co/OpceanAI/Yuuki-best) | Flagship model weights |
| [Yuuki Space](https://huggingface.co/spaces/OpceanAI/Yuuki) | Web-based interactive demo |

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

## License

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

**Built with patience, an assembler, and zero abstractions.**

<br>

[![Yuuki Project](https://img.shields.io/badge/Yuuki_Project-2026-000000?style=for-the-badge)](https://huggingface.co/OpceanAI)

<br>

</div>
