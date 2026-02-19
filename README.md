<div align="center">

<br>

<img src="https://img.shields.io/badge/%E2%9C%A6-YUUKISEMBLY-000000?style=for-the-badge&labelColor=000000" alt="Yuukisembly" height="50">

<br><br>

# Yuuki Chat — Binary Edition

**Chat with the Yuuki API in pure assembly.**<br>
**No frameworks, no high-level languages. Just registers, syscalls, and willpower.**

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
[![Android](https://img.shields.io/badge/Android_(Termux)-222222?style=flat-square&logo=android&logoColor=white)](#)

<br>

---

<br>

<table>
<tr>
<td width="50%" valign="top">

**Direct chat with the Yuuki API.**<br><br>
Three architecture targets.<br>
No high-level dependencies.<br>
Direct syscalls to the kernel.<br>
HTTP over raw sockets.<br>
Compatible with glibc and Bionic.<br>
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

The project includes three independent implementations covering the most relevant targets: **x86\_64 Linux** for conventional PCs, **ARM64 Linux** for ARM servers and Raspberry Pi, and **ARM64 Android** for use from Termux. Each version adapts to the ABI differences, struct offsets, and linker requirements of each platform.

Built with **GNU Assembler (`as`)** and linked with **`ld`**. Nothing else required.

<br>

---

<br>

<div align="center">

## Targets

</div>

<br>

| File | Target | Platform |
|:-----|:-------|:---------|
| `yuuki-x86_64.s` | Linux x86\_64 | Linux PC |
| `yuuki-arm64-linux.s` | Linux ARM64 | Raspberry Pi, Mac M1, ARM server |
| `yuuki-arm64-android.s` | Android ARM64 | Termux |

<br>

---

<br>

<div align="center">

## Build

</div>

<br>

### x86\_64 Linux

```bash
as -o yuuki-x86_64.o yuuki-x86_64.s
ld -dynamic-linker /lib64/ld-linux-x86-64.so.2 -o yuuki-x86_64 yuuki-x86_64.o -lc
./yuuki-x86_64
```

<br>

### ARM64 Linux (Raspberry Pi, server)

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

## Technical Differences

</div>

<br>

<table>
<tr>
<td width="50%" valign="top">

<h3>Android (Bionic)</h3>

`struct addrinfo.ai_addr` is at **offset 32**.<br><br>
Requires `--pie` (Position Independent Executable) at link time.<br><br>
Dynamic linker is `/system/bin/linker64` instead of the standard glibc one.

</td>
<td width="50%" valign="top">

<h3>Linux (glibc)</h3>

`struct addrinfo.ai_addr` is at **offset 24**.<br><br>
`--pie` is not required for simple executables.<br><br>
Standard linker: `/lib64/ld-linux-x86-64.so.2` (x86\_64) or `/lib/ld-linux-aarch64.so.1` (ARM64).

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
                        Yuuki API
                       (HTTP / socket)
```

<br>

---

<br>

<div align="center">

## Repository Layout

</div>

<br>

```
Yuukisembly/
    yuuki-x86_64.s          # x86_64 Linux implementation
    yuuki-arm64-linux.s     # ARM64 Linux implementation (glibc)
    yuuki-arm64-android.s   # ARM64 Android implementation (Bionic)
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
