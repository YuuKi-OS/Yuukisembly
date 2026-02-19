// ============================================================
// Yuuki Chat Client — ARM64 Android Assembly + TLS
// Compilar en Termux:
//   pkg install binutils openssl
//   as -o yuuki-arm64-android.o yuuki-arm64-android.s
//   ld -dynamic-linker /lib/ld-linux-aarch64.so.1 \
//       \
//       \
//      -o yuuki-arm64-android yuuki-arm64-android.o -lc -lssl -lcrypto
// ============================================================

.extern getaddrinfo
.extern freeaddrinfo
.extern TLS_client_method
.extern SSL_CTX_new
.extern SSL_new
.extern SSL_set_fd
.extern SSL_connect
.extern SSL_write
.extern SSL_read
.extern SSL_free
.extern SSL_CTX_free

// ============================================================
// .data
// ============================================================
.section .data

banner:
.ascii "\033[2J\033[H"
.ascii "\033[38;2;244;114;182m\033[1m"
.ascii "  ╭─────────────────────────────────────────╮\n"
.ascii "  │                                         │\n"
.ascii "  │   ✦  Y U U K I  C H A T  ✦             │\n"
.ascii "  │   ARM64 Linux — Trained on a Phone    │\n"
.ascii "  │                                         │\n"
.ascii "  ╰─────────────────────────────────────────╯\n"
.ascii "\033[0m\n"
banner_len = . - banner

model_prompt:
.ascii "\033[38;2;244;114;182m\033[1m  ✦ Modelo [\033[0m\033[38;2;250;250;250myuuki-best\033[38;2;244;114;182m\033[1m/yuuki-3.7/yuuki-v0.1\033[0m\033[38;2;244;114;182m\033[1m]: \033[0m"
model_prompt_len = . - model_prompt

input_prompt:
.ascii "\033[38;2;244;114;182m\033[1m  ✦ tú  » \033[0m\033[38;2;250;250;250m"
input_prompt_len = . - input_prompt

yuuki_prompt:
.ascii "\033[0m\033[38;2;244;114;182m\033[1m  ✦ yuuki» \033[0m\033[38;2;250;250;250m"
yuuki_prompt_len = . - yuuki_prompt

newline:        .ascii "\n"

thinking:
.ascii "\033[38;2;115;115;115m  ✦ pensando...\033[0m\n"
thinking_len = . - thinking

exit_msg:
.ascii "\n\033[38;2;244;114;182m\033[1m  ✦ Hasta luego ~\033[0m\n\n"
exit_msg_len = . - exit_msg

error_dns:
.ascii "\033[38;2;244;114;182m  ✦ Error: DNS falló\033[0m\n"
error_dns_len = . - error_dns

error_connect:
.ascii "\033[38;2;244;114;182m  ✦ Error: conexión falló\033[0m\n"
error_connect_len = . - error_connect

error_tls:
.ascii "\033[38;2;244;114;182m  ✦ Error: TLS falló\033[0m\n"
error_tls_len = . - error_tls

sep:
.ascii "\033[38;2;60;60;60m  ─────────────────────────────────────────\033[0m\n"
sep_len = . - sep

api_host:       .asciz "opceanai-yuuki-api.hf.space"
api_port_str:   .asciz "443"
default_model:  .asciz "yuuki-best"

http_req_start:
.ascii "POST /generate HTTP/1.1\r\nHost: opceanai-yuuki-api.hf.space\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: "
http_req_start_len = . - http_req_start

http_req_mid:       .ascii "\r\n\r\n"
http_req_mid_len = . - http_req_mid

json_start:     .ascii "{\"model\":\""
json_start_len = . - json_start
json_mid:       .ascii "\",\"prompt\":\""
json_mid_len = . - json_mid
json_end:       .ascii "\",\"max_tokens\":512}"
json_end_len = . - json_end

// ============================================================
// .bss
// ============================================================
.section .bss
.align 8
model_buf:      .space 64
input_buf:      .space 1024
input_len_var:  .space 8
json_buf:       .space 2048
req_buf:        .space 4096
resp_buf:       .space 8192
len_str_buf:    .space 32
sock_fd:        .space 8
ssl_ctx_ptr:    .space 8
ssl_ptr:        .space 8
addrinfo_ptr:   .space 8
.align 8
hints_buf:      .space 48

// Bionic (Android) struct addrinfo offsets
.equ AI_FLAGS,      0
.equ AI_FAMILY,     4
.equ AI_SOCKTYPE,   8
.equ AI_PROTOCOL,   12
.equ AI_ADDRLEN,    16
.equ AI_CANONNAME,  32   // glibc
.equ AI_ADDR,       24   // glibc
.equ AI_NEXT,       40

// syscalls
.equ SYS_read,      63
.equ SYS_write,     64
.equ SYS_exit,      93
.equ SYS_socket,    198
.equ SYS_connect,   203
.equ SYS_close,     57
.equ AF_INET,       2
.equ SOCK_STREAM,   1
.equ IPPROTO_TCP,   6

// ============================================================
// .text
// ============================================================
.section .text
.global _start

_start:
    mov x0, #1
    adr x1, banner
    mov x2, #banner_len
    mov x8, #SYS_write
    svc #0

    bl print_sep

    mov x0, #1
    adr x1, model_prompt
    mov x2, #model_prompt_len
    mov x8, #SYS_write
    svc #0

    mov x0, #0
    adr x1, model_buf
    mov x2, #63
    mov x8, #SYS_read
    svc #0

    cmp x0, #1
    b.le use_default
    adr x1, model_buf
    add x2, x1, x0
    sub x2, x2, #1
    strb wzr, [x2]
    b model_done

use_default:
    adr x0, model_buf
    adr x1, default_model
    mov x2, #10
    bl memcpy

model_done:
    bl print_sep

// ============================================================
// Chat loop
// ============================================================
chat_loop:
    mov x0, #1
    adr x1, input_prompt
    mov x2, #input_prompt_len
    mov x8, #SYS_write
    svc #0

    mov x0, #0
    adr x1, input_buf
    mov x2, #1023
    mov x8, #SYS_read
    svc #0

    mov x19, x0
    cmp x0, #1
    b.le chat_exit

    adr x1, input_buf
    add x2, x1, x19
    sub x2, x2, #1
    strb wzr, [x2]
    sub x19, x19, #1
    adr x1, input_len_var
    str x19, [x1]

    mov x0, #1
    adr x1, thinking
    mov x2, #thinking_len
    mov x8, #SYS_write
    svc #0

    bl build_json
    bl do_https_request
    bl print_sep
    b chat_loop

chat_exit:
    mov x0, #1
    adr x1, exit_msg
    mov x2, #exit_msg_len
    mov x8, #SYS_write
    svc #0
    mov x0, #0
    mov x8, #SYS_exit
    svc #0

// ============================================================
// build_json
// ============================================================
build_json:
    stp x29, x30, [sp, #-32]!
    stp x20, x21, [sp, #16]
    mov x29, sp

    adr x20, json_buf
    mov x21, x20

    adr x1, json_start
    mov x2, #json_start_len
    bl append_bytes

    adr x1, model_buf
    bl strlen_x1
    mov x2, x0
    adr x1, model_buf
    bl append_bytes

    adr x1, json_mid
    mov x2, #json_mid_len
    bl append_bytes

    adr x1, input_buf
    adr x2, input_len_var
    ldr x2, [x2]
    bl append_bytes_escaped

    adr x1, json_end
    mov x2, #json_end_len
    bl append_bytes

    strb wzr, [x20]
    sub x0, x20, x21

    ldp x20, x21, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ============================================================
// do_https_request — DNS + TCP + TLS + HTTP
// ============================================================
do_https_request:
    stp x29, x30, [sp, #-80]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    mov x29, sp

    // --- DNS ---
    adr x0, hints_buf
    mov x1, #48
    bl memzero

    adr x0, hints_buf
    mov w1, #AF_INET
    str w1, [x0, #AI_FAMILY]
    mov w1, #SOCK_STREAM
    str w1, [x0, #AI_SOCKTYPE]

    adr x0, api_host
    adr x1, api_port_str
    adr x2, hints_buf
    adr x3, addrinfo_ptr
    bl getaddrinfo
    cbnz x0, err_dns

    adr x0, addrinfo_ptr
    ldr x19, [x0]               // addrinfo*
    ldr x20, [x19, #AI_ADDR]    // sockaddr* (Bionic: offset 32)
    ldr w21, [x19, #AI_ADDRLEN] // addrlen

    // --- TCP socket ---
    mov x0, #AF_INET
    mov x1, #SOCK_STREAM
    mov x2, #IPPROTO_TCP
    mov x8, #SYS_socket
    svc #0
    cmp x0, #0
    b.lt err_connect
    adr x1, sock_fd
    str x0, [x1]
    mov x22, x0   // fd

    // --- connect ---
    mov x0, x22
    mov x1, x20
    mov x2, x21
    mov x8, #SYS_connect
    svc #0
    cmp x0, #0
    b.lt err_connect

    // liberar addrinfo
    mov x0, x19
    bl freeaddrinfo

    // --- TLS handshake ---
    bl TLS_client_method         // → x0 = method
    mov x0, x0
    bl SSL_CTX_new               // → x0 = ctx
    cbz x0, err_tls
    adr x1, ssl_ctx_ptr
    str x0, [x1]
    mov x23, x0   // ctx

    mov x0, x23
    bl SSL_new                   // → x0 = ssl
    cbz x0, err_tls
    adr x1, ssl_ptr
    str x0, [x1]
    mov x24, x0   // ssl

    mov x0, x24
    mov x1, x22              // fd
    bl SSL_set_fd
    cmp x0, #1
    b.ne err_tls

    mov x0, x24
    bl SSL_connect
    cmp x0, #1
    b.ne err_tls

    // --- construir HTTP request ---
    adr x20, req_buf
    mov x21, x20

    adr x1, json_buf
    bl strlen_x1
    mov x25, x0   // json_len

    adr x1, http_req_start
    mov x2, #http_req_start_len
    bl append_bytes

    mov x0, x25
    adr x1, len_str_buf
    bl int_to_str
    mov x2, x0
    adr x1, len_str_buf
    bl append_bytes

    adr x1, http_req_mid
    mov x2, #http_req_mid_len
    bl append_bytes

    adr x1, json_buf
    mov x2, x25
    bl append_bytes

    sub x25, x20, x21   // req len

    // --- SSL_write ---
    mov x0, x24
    mov x1, x21
    mov x2, x25
    bl SSL_write
    cmp x0, #0
    b.le err_tls

    // yuuki prompt
    mov x0, #1
    adr x1, yuuki_prompt
    mov x2, #yuuki_prompt_len
    mov x8, #SYS_write
    svc #0

    // primer SSL_read (con headers)
    mov x0, x24
    adr x1, resp_buf
    mov x2, #8191
    bl SSL_read
    cmp x0, #0
    b.le recv_done
    mov x26, x0   // bytes leídos

    // saltar headers
    adr x1, resp_buf
    mov x2, x26
    bl skip_headers
    mov x2, x1
    mov x1, x0
    mov x0, #1
    mov x8, #SYS_write
    svc #0

recv_loop:
    mov x0, x24
    adr x1, resp_buf
    mov x2, #8191
    bl SSL_read
    cmp x0, #0
    b.le recv_done
    mov x2, x0
    mov x0, #1
    adr x1, resp_buf
    mov x8, #SYS_write
    svc #0
    b recv_loop

recv_done:
    mov x0, #1
    adr x1, newline
    mov x2, #1
    mov x8, #SYS_write
    svc #0

    // liberar SSL
    mov x0, x24
    bl SSL_free
    mov x0, x23
    bl SSL_CTX_free

    // cerrar socket
    mov x0, x22
    mov x8, #SYS_close
    svc #0

    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

err_dns:
    mov x0, #1
    adr x1, error_dns
    mov x2, #error_dns_len
    mov x8, #SYS_write
    svc #0
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

err_connect:
    mov x0, #1
    adr x1, error_connect
    mov x2, #error_connect_len
    mov x8, #SYS_write
    svc #0
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

err_tls:
    mov x0, #1
    adr x1, error_tls
    mov x2, #error_tls_len
    mov x8, #SYS_write
    svc #0
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// ============================================================
// Helpers
// ============================================================

print_sep:
    stp x29, x30, [sp, #-16]!
    mov x0, #1
    adr x1, sep
    mov x2, #sep_len
    mov x8, #SYS_write
    svc #0
    ldp x29, x30, [sp], #16
    ret

strlen_x1:
    mov x0, #0
1:  ldrb w2, [x1, x0]
    cbz w2, 2f
    add x0, x0, #1
    b 1b
2:  ret

memcpy:
    cbz x2, 2f
1:  ldrb w3, [x1], #1
    strb w3, [x0], #1
    subs x2, x2, #1
    b.ne 1b
2:  ret

memzero:
    cbz x1, 2f
1:  strb wzr, [x0], #1
    subs x1, x1, #1
    b.ne 1b
2:  ret

append_bytes:
    cbz x2, 2f
1:  ldrb w3, [x1], #1
    strb w3, [x20], #1
    subs x2, x2, #1
    b.ne 1b
2:  ret

append_bytes_escaped:
    cbz x2, 3f
1:  ldrb w3, [x1], #1
    cmp w3, #0x22
    b.eq 2f
    cmp w3, #0x5c
    b.eq 2f
    strb w3, [x20], #1
    b 4f
2:  mov w4, #0x5c
    strb w4, [x20], #1
    strb w3, [x20], #1
4:  subs x2, x2, #1
    b.ne 1b
3:  ret

skip_headers:
    mov x3, x1
    mov x4, x2
    mov x5, #0
1:  add x6, x5, #3
    cmp x6, x4
    b.ge no_hdr
    ldrb w6, [x3, x5]
    cmp w6, #0x0d
    b.ne next
    add x7, x5, #1
    ldrb w6, [x3, x7]
    cmp w6, #0x0a
    b.ne next
    add x7, x5, #2
    ldrb w6, [x3, x7]
    cmp w6, #0x0d
    b.ne next
    add x7, x5, #3
    ldrb w6, [x3, x7]
    cmp w6, #0x0a
    b.ne next
    add x5, x5, #4
    add x0, x3, x5
    sub x1, x4, x5
    ret
next:
    add x5, x5, #1
    b 1b
no_hdr:
    mov x0, x3
    mov x1, x4
    ret

int_to_str:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    mov x19, x1
    mov x20, x1
    mov x21, x0
    mov x22, #10
    cbnz x21, 1f
    mov w3, #0x30
    strb w3, [x20], #1
    b 4f
1:  sub sp, sp, #32
    mov x4, sp
    mov x5, #0
2:  cbz x21, 3f
    udiv x6, x21, x22
    mul x8, x6, x22
    sub x7, x21, x8
    mov x21, x6
    add w7, w7, #0x30
    strb w7, [x4, x5]
    add x5, x5, #1
    b 2b
3:  sub x5, x5, #1
5:  ldrb w7, [x4, x5]
    strb w7, [x20], #1
    subs x5, x5, #1
    b.ge 5b
    add sp, sp, #32
4:  sub x0, x20, x19
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
