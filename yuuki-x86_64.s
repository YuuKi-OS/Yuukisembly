// ============================================================
// Yuuki Chat Client — x86_64 Assembly + TLS
// Compilar:
//   as -o yuuki-x86_64.o yuuki-x86_64.s
//   ld -dynamic-linker /lib64/ld-linux-x86-64.so.2 \
//      -o yuuki-x86_64 yuuki-x86_64.o -lc -lssl -lcrypto
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

.section .data

banner:
.ascii "\033[2J\033[H"
.ascii "\033[38;2;244;114;182m\033[1m"
.ascii "  ╭─────────────────────────────────────────╮\n"
.ascii "  │                                         │\n"
.ascii "  │   ✦  Y U U K I  C H A T  ✦             │\n"
.ascii "  │   x86_64 Binary — Trained on a Phone    │\n"
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

.section .bss
.align 8
model_buf:      .space 64
input_buf:      .space 1024
input_len:      .quad 0
json_buf:       .space 2048
req_buf:        .space 4096
resp_buf:       .space 8192
len_buf:        .space 32
sock_fd:        .quad 0
ssl_ctx_ptr:    .quad 0
ssl_ptr:        .quad 0
addrinfo_ptr:   .quad 0
.align 8
hints_buf:      .space 48

// glibc struct addrinfo offsets
.equ AI_FLAGS,      0
.equ AI_FAMILY,     4
.equ AI_SOCKTYPE,   8
.equ AI_PROTOCOL,   12
.equ AI_ADDRLEN,    16
.equ AI_ADDR,       24
.equ AI_CANONNAME,  32
.equ AI_NEXT,       40

.section .text
.global _start

.equ SYS_read,      0
.equ SYS_write,     1
.equ SYS_close,     3
.equ SYS_socket,    41
.equ SYS_connect,   42
.equ SYS_exit,      60
.equ AF_INET,       2
.equ SOCK_STREAM,   1
.equ IPPROTO_TCP,   6

// ============================================================
_start:
    mov $1, %rdi
    lea banner(%rip), %rsi
    mov $banner_len, %rdx
    mov $SYS_write, %rax
    syscall

    call print_sep

    mov $1, %rdi
    lea model_prompt(%rip), %rsi
    mov $model_prompt_len, %rdx
    mov $SYS_write, %rax
    syscall

    xor %rdi, %rdi
    lea model_buf(%rip), %rsi
    mov $63, %rdx
    mov $SYS_read, %rax
    syscall

    cmp $1, %rax
    jle use_default

    lea model_buf(%rip), %rsi
    add %rax, %rsi
    dec %rsi
    movb $0, (%rsi)
    jmp model_ok

use_default:
    lea model_buf(%rip), %rdi
    lea default_model(%rip), %rsi
    mov $10, %rcx
    rep movsb

model_ok:
    call print_sep

chat_loop:
    mov $1, %rdi
    lea input_prompt(%rip), %rsi
    mov $input_prompt_len, %rdx
    mov $SYS_write, %rax
    syscall

    xor %rdi, %rdi
    lea input_buf(%rip), %rsi
    mov $1023, %rdx
    mov $SYS_read, %rax
    syscall

    cmp $1, %rax
    jle do_exit

    lea input_len(%rip), %rbx
    mov %rax, (%rbx)
    lea input_buf(%rip), %rsi
    add %rax, %rsi
    dec %rsi
    movb $0, (%rsi)
    decq input_len(%rip)

    mov $1, %rdi
    lea thinking(%rip), %rsi
    mov $thinking_len, %rdx
    mov $SYS_write, %rax
    syscall

    call build_json
    call do_https_request
    call print_sep
    jmp chat_loop

do_exit:
    mov $1, %rdi
    lea exit_msg(%rip), %rsi
    mov $exit_msg_len, %rdx
    mov $SYS_write, %rax
    syscall
    xor %rdi, %rdi
    mov $SYS_exit, %rax
    syscall

// ============================================================
build_json:
    push %rbp
    mov %rsp, %rbp
    push %r12
    push %r13

    lea json_buf(%rip), %r12
    mov %r12, %r13

    lea json_start(%rip), %rsi
    mov $json_start_len, %rcx
    call append_r12

    lea model_buf(%rip), %rdi
    call strlen_rdi
    mov %rax, %rcx
    lea model_buf(%rip), %rsi
    call append_r12

    lea json_mid(%rip), %rsi
    mov $json_mid_len, %rcx
    call append_r12

    lea input_buf(%rip), %rsi
    mov input_len(%rip), %rcx
    call append_escaped_r12

    lea json_end(%rip), %rsi
    mov $json_end_len, %rcx
    call append_r12

    movb $0, (%r12)

    pop %r13
    pop %r12
    pop %rbp
    ret

// ============================================================
do_https_request:
    push %rbp
    mov %rsp, %rbp
    push %r12
    push %r13
    push %r14
    push %r15
    // 4 pushes + rbp = 5*8=40, necesitamos 16-byte align
    // rsp actual: 40 extra → no alineado, añadir 8 bytes
    sub $8, %rsp

    // --- DNS ---
    lea hints_buf(%rip), %rdi
    xor %eax, %eax
    mov $48, %rcx
    rep stosb

    lea hints_buf(%rip), %rbx
    movl $AF_INET, AI_FAMILY(%rbx)
    movl $SOCK_STREAM, AI_SOCKTYPE(%rbx)

    lea api_host(%rip), %rdi
    lea api_port_str(%rip), %rsi
    lea hints_buf(%rip), %rdx
    lea addrinfo_ptr(%rip), %rcx
    call getaddrinfo
    test %eax, %eax
    jnz err_dns

    mov addrinfo_ptr(%rip), %rbx
    mov AI_ADDR(%rbx), %r12       // sockaddr*
    movl AI_ADDRLEN(%rbx), %r13d  // addrlen

    // --- TCP ---
    mov $AF_INET, %rdi
    mov $SOCK_STREAM, %rsi
    mov $IPPROTO_TCP, %rdx
    mov $SYS_socket, %rax
    syscall
    test %rax, %rax
    js err_connect
    mov %rax, sock_fd(%rip)
    mov %rax, %r15

    mov %r15, %rdi
    mov %r12, %rsi
    movslq %r13d, %rdx
    mov $SYS_connect, %rax
    syscall
    test %rax, %rax
    js err_connect

    mov addrinfo_ptr(%rip), %rdi
    call freeaddrinfo

    // --- TLS ---
    call TLS_client_method
    mov %rax, %rdi
    call SSL_CTX_new
    test %rax, %rax
    jz err_tls
    mov %rax, ssl_ctx_ptr(%rip)
    mov %rax, %r14   // ctx

    mov %r14, %rdi
    call SSL_new
    test %rax, %rax
    jz err_tls
    mov %rax, ssl_ptr(%rip)
    mov %rax, %r13   // ssl

    mov %r13, %rdi
    mov %r15, %rsi   // fd
    call SSL_set_fd
    cmp $1, %rax
    jne err_tls

    mov %r13, %rdi
    call SSL_connect
    cmp $1, %rax
    jne err_tls

    // --- construir request ---
    lea req_buf(%rip), %r12
    push %r12   // guardar inicio

    lea json_buf(%rip), %rdi
    call strlen_rdi
    mov %rax, %rbx   // json_len

    lea http_req_start(%rip), %rsi
    mov $http_req_start_len, %rcx
    call append_r12

    mov %rbx, %rdi
    lea len_buf(%rip), %rsi
    call int_to_str_x86
    mov %rax, %rcx
    lea len_buf(%rip), %rsi
    call append_r12

    lea http_req_mid(%rip), %rsi
    mov $http_req_mid_len, %rcx
    call append_r12

    lea json_buf(%rip), %rsi
    mov %rbx, %rcx
    call append_r12

    pop %rbx         // inicio del req
    sub %rbx, %r12   // req len → r12

    // --- SSL_write ---
    mov %r13, %rdi
    mov %rbx, %rsi
    mov %r12, %rdx
    call SSL_write
    test %rax, %rax
    jle err_tls

    // yuuki prompt
    mov $1, %rdi
    lea yuuki_prompt(%rip), %rsi
    mov $yuuki_prompt_len, %rdx
    mov $SYS_write, %rax
    syscall

    // primer SSL_read
    mov %r13, %rdi
    lea resp_buf(%rip), %rsi
    mov $8191, %rdx
    call SSL_read
    test %rax, %rax
    jle recv_done

    // saltar headers
    lea resp_buf(%rip), %rdi
    mov %rax, %rsi
    call skip_headers   // → rax=body ptr, rdx=body len

    mov %rax, %rsi
    mov $1, %rdi
    mov $SYS_write, %rax
    syscall

recv_loop:
    mov %r13, %rdi
    lea resp_buf(%rip), %rsi
    mov $8191, %rdx
    call SSL_read
    test %rax, %rax
    jle recv_done

    mov %rax, %rdx
    mov $1, %rdi
    lea resp_buf(%rip), %rsi
    mov $SYS_write, %rax
    syscall
    jmp recv_loop

recv_done:
    mov $1, %rdi
    lea newline(%rip), %rsi
    mov $1, %rdx
    mov $SYS_write, %rax
    syscall

    mov %r13, %rdi
    call SSL_free
    mov %r14, %rdi
    call SSL_CTX_free
    mov %r15, %rdi
    mov $SYS_close, %rax
    syscall

    add $8, %rsp
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbp
    ret

err_dns:
    mov $1, %rdi
    lea error_dns(%rip), %rsi
    mov $error_dns_len, %rdx
    mov $SYS_write, %rax
    syscall
    add $8, %rsp
    pop %r15; pop %r14; pop %r13; pop %r12; pop %rbp
    ret

err_connect:
    mov $1, %rdi
    lea error_connect(%rip), %rsi
    mov $error_connect_len, %rdx
    mov $SYS_write, %rax
    syscall
    add $8, %rsp
    pop %r15; pop %r14; pop %r13; pop %r12; pop %rbp
    ret

err_tls:
    mov $1, %rdi
    lea error_tls(%rip), %rsi
    mov $error_tls_len, %rdx
    mov $SYS_write, %rax
    syscall
    add $8, %rsp
    pop %r15; pop %r14; pop %r13; pop %r12; pop %rbp
    ret

// ============================================================
// Helpers
// ============================================================

print_sep:
    push %rbp
    mov %rsp, %rbp
    mov $1, %rdi
    lea sep(%rip), %rsi
    mov $sep_len, %rdx
    mov $SYS_write, %rax
    syscall
    pop %rbp
    ret

strlen_rdi:
    xor %rax, %rax
1:  movzbl (%rdi, %rax), %ecx
    test %cl, %cl
    jz 2f
    inc %rax
    jmp 1b
2:  ret

append_r12:
    test %rcx, %rcx
    jz 2f
1:  movzbl (%rsi), %eax
    movb %al, (%r12)
    inc %rsi
    inc %r12
    dec %rcx
    jnz 1b
2:  ret

append_escaped_r12:
    test %rcx, %rcx
    jz 3f
1:  movzbl (%rsi), %eax
    inc %rsi
    cmp $0x22, %al
    je 2f
    cmp $0x5c, %al
    je 2f
    movb %al, (%r12)
    inc %r12
    jmp 4f
2:  movb $0x5c, (%r12)
    inc %r12
    movb %al, (%r12)
    inc %r12
4:  dec %rcx
    jnz 1b
3:  ret

skip_headers:
    push %rbp
    mov %rsp, %rbp
    push %rbx
    push %r8

    mov %rdi, %rbx
    mov %rsi, %r8
    xor %rcx, %rcx

scan:
    mov %r8, %rax
    sub $3, %rax
    cmp %rcx, %rax
    jle no_hdr

    movzbl (%rbx, %rcx), %eax
    cmp $0x0d, %al
    jne next_b
    movzbl 1(%rbx, %rcx), %eax
    cmp $0x0a, %al
    jne next_b
    movzbl 2(%rbx, %rcx), %eax
    cmp $0x0d, %al
    jne next_b
    movzbl 3(%rbx, %rcx), %eax
    cmp $0x0a, %al
    jne next_b

    add $4, %rcx
    lea (%rbx, %rcx), %rax
    mov %r8, %rdx
    sub %rcx, %rdx
    jmp done_h

next_b:
    inc %rcx
    jmp scan

no_hdr:
    mov %rbx, %rax
    mov %r8, %rdx

done_h:
    pop %r8
    pop %rbx
    pop %rbp
    ret

int_to_str_x86:
    push %rbp
    mov %rsp, %rbp
    push %rbx
    push %r12
    push %r13
    sub $32, %rsp

    mov %rsi, %r12
    mov %rsi, %r13
    mov %rdi, %rbx
    mov $10, %r9

    test %rbx, %rbx
    jnz 1f
    movb $0x30, (%r13)
    inc %r13
    jmp 4f

1:  lea (%rsp), %rcx
    xor %r8, %r8
2:  test %rbx, %rbx
    jz 3f
    mov %rbx, %rax
    xor %rdx, %rdx
    idiv %r9
    mov %rax, %rbx
    add $0x30, %dl
    movb %dl, (%rcx, %r8)
    inc %r8
    jmp 2b
3:  dec %r8
5:  movzbl (%rcx, %r8), %eax
    movb %al, (%r13)
    inc %r13
    dec %r8
    jns 5b

4:  sub %r12, %r13
    mov %r13, %rax

    add $32, %rsp
    pop %r13; pop %r12; pop %rbx; pop %rbp
    ret
