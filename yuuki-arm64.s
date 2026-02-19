// ============================================================
// Yuuki Chat Client — ARM64 Assembly
// Chat con la API de Yuuki en opcodes ARM64 puros
// ============================================================

.section .data

// ANSI colors — sakura pink theme
ansi_reset:     .ascii "\033[0m"
ansi_pink:      .ascii "\033[38;2;244;114;182m"
ansi_white:     .ascii "\033[38;2;250;250;250m"
ansi_gray:      .ascii "\033[38;2;115;115;115m"
ansi_bold:      .ascii "\033[1m"
ansi_dim:       .ascii "\033[2m"

// Banner
banner:
.ascii "\033[2J\033[H"  // clear screen
.ascii "\033[38;2;244;114;182m\033[1m"
.ascii "  ╭─────────────────────────────────────────╮\n"
.ascii "  │                                         │\n"
.ascii "  │   ✦  Y U U K I  C H A T  ✦             │\n"
.ascii "  │   ARM64 Binary — Trained on a Phone     │\n"
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
newline_len = . - newline

thinking:
.ascii "\033[38;2;115;115;115m  ✦ pensando...\033[0m\n"
thinking_len = . - thinking

exit_msg:
.ascii "\n\033[38;2;244;114;182m\033[1m  ✦ Hasta luego ~\033[0m\n\n"
exit_msg_len = . - exit_msg

error_msg:
.ascii "\033[38;2;244;114;182m  ✦ Error conectando a la API\033[0m\n"
error_msg_len = . - error_msg

sep:
.ascii "\033[38;2;30;30;30m  ─────────────────────────────────────────\033[0m\n"
sep_len = . - sep

// API config
api_host:       .asciz "opceanai-yuuki-api.hf.space"
api_port:       .word 80

// HTTP request template
http_req_start:
.ascii "POST /generate HTTP/1.1\r\nHost: opceanai-yuuki-api.hf.space\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: "
http_req_start_len = . - http_req_start

http_req_mid:
.ascii "\r\n\r\n"
http_req_mid_len = . - http_req_mid

json_start:     .ascii "{\"model\":\""
json_start_len = . - json_start

json_mid:       .ascii "\",\"prompt\":\""
json_mid_len = . - json_mid

json_end:       .ascii "\",\"max_tokens\":200}"
json_end_len = . - json_end

// Default model
default_model:  .asciz "yuuki-best"

.section .bss
.align 8
model_buf:      .space 64
input_buf:      .space 1024
json_buf:       .space 2048
req_buf:        .space 4096
resp_buf:       .space 8192
len_str_buf:    .space 32
sock_fd:        .space 8

// sockaddr_in structure
.align 8
sockaddr:
sa_family:      .space 2
sa_port:        .space 2
sa_addr:        .space 4
sa_zero:        .space 8

// DNS resolve buffer
.align 8
hints:          .space 48
res_ptr:        .space 8

.section .text
.global _start

// ============================================================
// Syscall numbers ARM64
// ============================================================
.equ SYS_read,          63
.equ SYS_write,         64
.equ SYS_exit,          93
.equ SYS_socket,        198
.equ SYS_connect,       203
.equ SYS_sendto,        206
.equ SYS_recvfrom,      207
.equ SYS_close,         57
.equ SYS_getaddrinfo,   202  // via libc, usaremos IP directa

.equ AF_INET,           2
.equ SOCK_STREAM,       1
.equ IPPROTO_TCP,       6

// ============================================================
// _start
// ============================================================
_start:
    // Mostrar banner
    mov x0, #1
    adr x1, banner
    mov x2, #banner_len
    mov x8, #SYS_write
    svc #0

    // Mostrar separador
    bl print_sep

    // Pedir modelo
    mov x0, #1
    adr x1, model_prompt
    mov x2, #model_prompt_len
    mov x8, #SYS_write
    svc #0

    // Leer modelo
    mov x0, #0
    adr x1, model_buf
    mov x2, #63
    mov x8, #SYS_read
    svc #0

    // Si solo enter, usar default
    cmp x0, #1
    b.le use_default_model
    // Quitar newline
    adr x1, model_buf
    add x1, x1, x0
    sub x1, x1, #1
    strb wzr, [x1]
    b model_done

use_default_model:
    adr x0, model_buf
    adr x1, default_model
    mov x2, #10
    bl memcpy

model_done:
    bl print_sep

// ============================================================
// Chat loop principal
// ============================================================
chat_loop:
    // Mostrar prompt de input
    mov x0, #1
    adr x1, input_prompt
    mov x2, #input_prompt_len
    mov x8, #SYS_write
    svc #0

    // Leer input del usuario
    mov x0, #0
    adr x1, input_buf
    mov x2, #1023
    mov x8, #SYS_read
    svc #0

    // Guardar longitud
    mov x19, x0

    // Si 0 bytes o solo newline → salir
    cmp x0, #1
    b.le chat_exit

    // Quitar newline del input
    adr x1, input_buf
    add x2, x1, x19
    sub x2, x2, #1
    strb wzr, [x2]
    sub x19, x19, #1

    // Mostrar "pensando..."
    mov x0, #1
    adr x1, thinking
    mov x2, #thinking_len
    mov x8, #SYS_write
    svc #0

    // Construir JSON body
    bl build_json

    // Hacer request HTTP
    bl do_http_request

    // Mostrar respuesta
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
// build_json — construye el JSON body en json_buf
// retorna longitud en x0
// ============================================================
build_json:
    stp x29, x30, [sp, #-32]!
    stp x20, x21, [sp, #16]
    mov x29, sp

    adr x20, json_buf
    mov x21, x20  // puntero inicio

    // {"model":"
    adr x1, json_start
    mov x2, #json_start_len
    bl append_bytes

    // nombre del modelo
    adr x1, model_buf
    bl strlen_func
    mov x2, x0
    adr x1, model_buf
    bl append_bytes

    // ","prompt":"
    adr x1, json_mid
    mov x2, #json_mid_len
    bl append_bytes

    // el prompt (escapar comillas básico)
    adr x1, input_buf
    mov x2, x19
    bl append_bytes_escaped

    // ","max_tokens":200}
    adr x1, json_end
    mov x2, #json_end_len
    bl append_bytes

    // null terminator
    strb wzr, [x20]

    // calcular longitud
    sub x0, x20, x21

    ldp x20, x21, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ============================================================
// do_http_request — abre socket, envía request, imprime respuesta
// ============================================================
do_http_request:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp

    // Calcular Content-Length del JSON
    adr x1, json_buf    // strlen_func lee de x1, no x0
    bl strlen_func
    mov x22, x0  // json_len

    // Crear socket TCP
    mov x0, #AF_INET
    mov x1, #SOCK_STREAM
    mov x2, #IPPROTO_TCP
    mov x8, #SYS_socket
    svc #0
    cmp x0, #0
    b.lt http_error
    adr x1, sock_fd
    str x0, [x1]
    mov x19, x0  // fd

    // Setup sockaddr_in para opceanai-yuuki-api.hf.space
    // IP de HF spaces: resolvemos en tiempo de compilación como fallback
    // Usamos 104.21.0.0 como placeholder — en práctica necesitaría getaddrinfo
    // Nota: esto requiere que el binario se ejecute en un sistema con resolución DNS
    adr x0, sockaddr
    mov x1, #16
    bl memzero

    adr x0, sockaddr
    mov w1, #AF_INET
    strh w1, [x0]           // sa_family = AF_INET
    // Port 80 en big endian
    mov w1, #0x5000         // 80 = 0x0050, big endian = 0x5000
    strh w1, [x0, #2]       // sa_port
    // IP: 104.21.96.104 (Cloudflare/HF) en little endian
    // 104=0x68, 21=0x15, 96=0x60, 104=0x68 → 0x68601568
    mov w1, #0x1568
    movk w1, #0x6860, lsl #16
    str w1, [x0, #4]

    // Connect
    mov x0, x19
    adr x1, sockaddr
    mov x2, #16
    mov x8, #SYS_connect
    svc #0
    cmp x0, #0
    b.lt http_error

    // Construir HTTP request completo en req_buf
    adr x20, req_buf
    mov x21, x20

    // POST /generate HTTP/1.1\r\nHost: ...\r\nContent-Type: ...\r\nContent-Length: 
    adr x1, http_req_start
    mov x2, #http_req_start_len
    bl append_bytes

    // Content-Length value (número como string)
    mov x0, x22
    adr x1, len_str_buf
    bl int_to_str
    mov x2, x0
    adr x1, len_str_buf
    bl append_bytes

    // \r\n\r\n
    adr x1, http_req_mid
    mov x2, #http_req_mid_len
    bl append_bytes

    // JSON body
    adr x1, json_buf
    mov x2, x22
    bl append_bytes

    // Calcular longitud total del request
    sub x22, x20, x21

    // Enviar request
    mov x0, x19
    mov x1, x21
    mov x2, x22
    mov x3, #0
    mov x4, #0
    mov x5, #0
    mov x8, #SYS_sendto
    svc #0
    cmp x0, #0
    b.lt http_error

    // Mostrar prompt de respuesta
    mov x0, #1
    adr x1, yuuki_prompt
    mov x2, #yuuki_prompt_len
    mov x8, #SYS_write
    svc #0

    // Recibir respuesta completa
    mov x0, x19
    adr x1, resp_buf
    mov x2, #8191
    mov x3, #0
    mov x4, #0
    mov x5, #0
    mov x8, #SYS_recvfrom
    svc #0
    cmp x0, #0
    b.le recv_done
    mov x23, x0        // total bytes recibidos

    // Buscar fin de headers HTTP (\r\n\r\n)
    adr x1, resp_buf
    mov x2, x23
    bl skip_http_headers   // retorna puntero al body en x0, longitud en x1

    // Mostrar solo el body
    mov x2, x1
    mov x1, x0
    mov x0, #1
    mov x8, #SYS_write
    svc #0

recv_loop:
    mov x0, x19
    adr x1, resp_buf
    mov x2, #8191
    mov x3, #0
    mov x4, #0
    mov x5, #0
    mov x8, #SYS_recvfrom
    svc #0
    cmp x0, #0
    b.le recv_done

    mov x2, x0
    mov x0, #1
    adr x1, resp_buf
    mov x8, #SYS_write
    svc #0
    b recv_loop

recv_done:
    // Newline final
    mov x0, #1
    adr x1, newline
    mov x2, #1
    mov x8, #SYS_write
    svc #0

    // Cerrar socket
    adr x0, sock_fd
    ldr x0, [x0]
    mov x8, #SYS_close
    svc #0

    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

http_error:
    mov x0, #1
    adr x1, error_msg
    mov x2, #error_msg_len
    mov x8, #SYS_write
    svc #0

    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ============================================================
// Helpers
// ============================================================

// print_sep
print_sep:
    stp x29, x30, [sp, #-16]!
    mov x0, #1
    adr x1, sep
    mov x2, #sep_len
    mov x8, #SYS_write
    svc #0
    ldp x29, x30, [sp], #16
    ret

// skip_http_headers(x1: buf, x2: len) → x0: body ptr, x1: body len
// Busca \r\n\r\n y retorna puntero al body
skip_http_headers:
    mov x3, x1      // ptr actual
    mov x4, x2      // len restante
    mov x5, #0      // índice
1:  cmp x5, x4
    b.ge 2f
    ldrb w6, [x3, x5]
    cmp w6, #0x0d   // \r
    b.ne 4f
    add x5, x5, #1
    ldrb w6, [x3, x5]
    cmp w6, #0x0a   // \n
    b.ne 4f
    add x5, x5, #1
    ldrb w6, [x3, x5]
    cmp w6, #0x0d   // \r
    b.ne 4f
    add x5, x5, #1
    ldrb w6, [x3, x5]
    cmp w6, #0x0a   // \n
    b.ne 4f
    // encontrado \r\n\r\n en posición x5-3
    add x5, x5, #1
    add x0, x3, x5          // body ptr
    sub x1, x4, x5          // body len
    ret
4:  add x5, x5, #1
    b 1b
2:  // no encontró headers, devolver buffer completo
    mov x0, x3
    mov x1, x4
    ret

// strlen_func(x1: ptr) → x0: len
strlen_func:
    mov x0, #0
1:  ldrb w2, [x1, x0]
    cbz w2, 2f
    add x0, x0, #1
    b 1b
2:  ret

// memcpy(x0: dst, x1: src, x2: len)
memcpy:
    cbz x2, 2f
1:  ldrb w3, [x1], #1
    strb w3, [x0], #1
    subs x2, x2, #1
    b.ne 1b
2:  ret

// memzero(x0: ptr, x1: len)
memzero:
    cbz x1, 2f
1:  strb wzr, [x0], #1
    subs x1, x1, #1
    b.ne 1b
2:  ret

// append_bytes — añade bytes al buffer x20
// x1: src, x2: len
append_bytes:
    cbz x2, 2f
1:  ldrb w3, [x1], #1
    strb w3, [x20], #1
    subs x2, x2, #1
    b.ne 1b
2:  ret

// append_bytes_escaped — igual pero escapa " y \ para JSON
// x1: src, x2: len
append_bytes_escaped:
    cbz x2, 3f
1:  ldrb w3, [x1], #1
    cmp w3, #0x22   // "
    b.eq 2f
    cmp w3, #0x5c   // backslash
    b.eq 2f
    strb w3, [x20], #1
    b 4f
2:  mov w4, #0x5c
    strb w4, [x20], #1
    strb w3, [x20], #1
4:  subs x2, x2, #1
    b.ne 1b
3:  ret

// int_to_str(x0: num, x1: buf) → x0: len
int_to_str:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp

    mov x19, x1     // buf start
    mov x20, x1     // current ptr
    mov x21, x0     // número
    mov x22, #10    // divisor

    // caso especial 0
    cbnz x21, 1f
    mov w3, #0x30
    strb w3, [x20], #1
    b 4f

1:  // temp buffer en stack para dígitos en reverso
    sub sp, sp, #32
    mov x4, sp
    mov x5, #0     // contador

2:  cbz x21, 3f
    udiv x6, x21, x22   // x6 = x21 / 10
    mul x8, x6, x22     // x8 = x6 * 10
    sub x7, x21, x8     // x7 = x21 mod 10
    mov x21, x6
    add w7, w7, #0x30
    strb w7, [x4, x5]
    add x5, x5, #1
    b 2b

3:  // invertir dígitos
    sub x5, x5, #1
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
