// ============================================================
// Yuuki Chat Client — x86_64 Assembly
// Chat con la API de Yuuki en opcodes x86_64 puros
// ============================================================

.section .data

// ANSI colors — sakura pink theme
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

thinking:
.ascii "\033[38;2;115;115;115m  ✦ pensando...\033[0m\r"
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

newline:    .ascii "\n"

// HTTP
http_req_start:
.ascii "POST /generate HTTP/1.1\r\nHost: opceanai-yuuki-api.hf.space\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: "
http_req_start_len = . - http_req_start

http_req_mid:   .ascii "\r\n\r\n"
http_req_mid_len = . - http_req_mid

json_start:     .ascii "{\"model\":\""
json_start_len = . - json_start

json_mid:       .ascii "\",\"prompt\":\""
json_mid_len = . - json_mid

json_end:       .ascii "\",\"max_tokens\":200}"
json_end_len = . - json_end

default_model:  .asciz "yuuki-best"

.section .bss
.align 8
model_buf:      .space 64
input_buf:      .space 1024
json_buf:       .space 2048
req_buf:        .space 4096
resp_buf:       .space 8192
len_buf:        .space 32
sock_fd:        .quad 0
input_len:      .quad 0

// sockaddr_in
.align 8
sockaddr:
.space 16

.section .text
.global _start

// syscalls x86_64
.equ SYS_read,      0
.equ SYS_write,     1
.equ SYS_close,     3
.equ SYS_socket,    41
.equ SYS_connect,   42
.equ SYS_sendto,    44
.equ SYS_recvfrom,  45
.equ SYS_exit,      60

.equ AF_INET,       2
.equ SOCK_STREAM,   1
.equ IPPROTO_TCP,   6

// ============================================================
// _start
// ============================================================
_start:
    // Banner
    mov $1, %rdi
    lea banner(%rip), %rsi
    mov $banner_len, %rdx
    mov $SYS_write, %rax
    syscall

    call print_sep

    // Pedir modelo
    mov $1, %rdi
    lea model_prompt(%rip), %rsi
    mov $model_prompt_len, %rdx
    mov $SYS_write, %rax
    syscall

    // Leer modelo
    xor %rdi, %rdi
    lea model_buf(%rip), %rsi
    mov $63, %rdx
    mov $SYS_read, %rax
    syscall

    cmp $1, %rax
    jle use_default

    // quitar newline
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

// ============================================================
// chat loop
// ============================================================
chat_loop:
    // input prompt
    mov $1, %rdi
    lea input_prompt(%rip), %rsi
    mov $input_prompt_len, %rdx
    mov $SYS_write, %rax
    syscall

    // leer input
    xor %rdi, %rdi
    lea input_buf(%rip), %rsi
    mov $1023, %rdx
    mov $SYS_read, %rax
    syscall

    cmp $1, %rax
    jle do_exit

    // guardar len
    lea input_len(%rip), %rbx
    mov %rax, (%rbx)

    // quitar newline
    lea input_buf(%rip), %rsi
    mov %rax, %rcx
    add %rcx, %rsi
    dec %rsi
    movb $0, (%rsi)
    lea input_len(%rip), %rbx
    decq (%rbx)

    // pensando
    mov $1, %rdi
    lea thinking(%rip), %rsi
    mov $thinking_len, %rdx
    mov $SYS_write, %rax
    syscall

    call build_json
    call do_http_request
    call print_sep

    jmp chat_loop

do_exit:
    mov $1, %rdi
    lea exit_msg(%rip), %rsi
    mov $exit_msg_len, %rdx
    mov $SYS_write, %rax
    syscall

    mov $0, %rdi
    mov $SYS_exit, %rax
    syscall

// ============================================================
// build_json
// ============================================================
build_json:
    push %rbp
    mov %rsp, %rbp
    push %r12
    push %r13

    lea json_buf(%rip), %r12   // dst ptr
    mov %r12, %r13             // start

    // {"model":"
    lea json_start(%rip), %rsi
    mov $json_start_len, %rcx
    call append_bytes_r12

    // model name
    lea model_buf(%rip), %rdi
    call strlen_rdi
    mov %rax, %rcx
    lea model_buf(%rip), %rsi
    call append_bytes_r12

    // ","prompt":"
    lea json_mid(%rip), %rsi
    mov $json_mid_len, %rcx
    call append_bytes_r12

    // prompt (escaped)
    lea input_buf(%rip), %rsi
    lea input_len(%rip), %rcx
    mov (%rcx), %rcx
    call append_escaped_r12

    // ","max_tokens":200}
    lea json_end(%rip), %rsi
    mov $json_end_len, %rcx
    call append_bytes_r12

    movb $0, (%r12)

    pop %r13
    pop %r12
    pop %rbp
    ret

// ============================================================
// do_http_request
// ============================================================
do_http_request:
    push %rbp
    mov %rsp, %rbp
    push %r12
    push %r13
    push %r14
    push %r15

    // json len
    lea json_buf(%rip), %rdi
    call strlen_rdi
    mov %rax, %r14   // json_len

    // socket
    mov $AF_INET, %rdi
    mov $SOCK_STREAM, %rsi
    mov $IPPROTO_TCP, %rdx
    mov $SYS_socket, %rax
    syscall
    test %rax, %rax
    js http_err
    lea sock_fd(%rip), %rbx
    mov %rax, (%rbx)
    mov %rax, %r15   // fd

    // sockaddr_in
    lea sockaddr(%rip), %rdi
    mov $16, %rcx
    xor %al, %al
    rep stosb

    lea sockaddr(%rip), %rbx
    movw $AF_INET, (%rbx)
    movw $0x5000, 2(%rbx)    // port 80 big endian
    // IP: 104.21.96.1 (Cloudflare — HF usa Cloudflare)
    // 104=0x68, 21=0x15, 96=0x60, 1=0x01 → little endian: 0x01601568
    movl $0x01601568, 4(%rbx)

    // connect
    mov %r15, %rdi
    lea sockaddr(%rip), %rsi
    mov $16, %rdx
    mov $SYS_connect, %rax
    syscall
    test %rax, %rax
    js http_err

    // construir request en req_buf
    lea req_buf(%rip), %r12
    mov %r12, %r13

    lea http_req_start(%rip), %rsi
    mov $http_req_start_len, %rcx
    call append_bytes_r12

    // content-length como string
    mov %r14, %rdi
    lea len_buf(%rip), %rsi
    call int_to_str_func
    mov %rax, %rcx
    lea len_buf(%rip), %rsi
    call append_bytes_r12

    lea http_req_mid(%rip), %rsi
    mov $http_req_mid_len, %rcx
    call append_bytes_r12

    lea json_buf(%rip), %rsi
    mov %r14, %rcx
    call append_bytes_r12

    sub %r13, %r12
    mov %r12, %r14   // req total len

    // send
    mov %r15, %rdi
    mov %r13, %rsi
    mov %r14, %rdx
    xor %r10, %r10
    xor %r8, %r8
    xor %r9, %r9
    mov $SYS_sendto, %rax
    syscall
    test %rax, %rax
    js http_err

    // yuuki prompt
    mov $1, %rdi
    lea yuuki_prompt(%rip), %rsi
    mov $yuuki_prompt_len, %rdx
    mov $SYS_write, %rax
    syscall

    // Recibir respuesta completa (primer chunk con headers)
    mov %r15, %rdi
    lea resp_buf(%rip), %rsi
    mov $8191, %rdx
    xor %r10, %r10
    xor %r8, %r8
    xor %r9, %r9
    mov $SYS_recvfrom, %rax
    syscall
    test %rax, %rax
    jle recv_done

    // Saltar headers HTTP — buscar \r\n\r\n
    lea resp_buf(%rip), %rdi
    mov %rax, %rsi      // total bytes
    call skip_http_headers  // retorna: rax=body ptr, rdx=body len

    // Mostrar body
    mov %rax, %rsi
    mov %rdx, %rdx
    mov $1, %rdi
    mov $SYS_write, %rax
    syscall

recv_loop:
    mov %r15, %rdi
    lea resp_buf(%rip), %rsi
    mov $8191, %rdx
    xor %r10, %r10
    xor %r8, %r8
    xor %r9, %r9
    mov $SYS_recvfrom, %rax
    syscall
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

    mov %r15, %rdi
    mov $SYS_close, %rax
    syscall

    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbp
    ret

http_err:
    mov $1, %rdi
    lea error_msg(%rip), %rsi
    mov $error_msg_len, %rdx
    mov $SYS_write, %rax
    syscall
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbp
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

// skip_http_headers(rdi: buf, rsi: len) → rax: body ptr, rdx: body len
skip_http_headers:
    push %rbp
    mov %rsp, %rbp
    push %rbx
    push %r12

    mov %rdi, %rbx   // buf
    mov %rsi, %r12   // len
    xor %rcx, %rcx   // index

1:  cmp %rcx, %r12
    jge 2f
    movzbl (%rbx, %rcx), %eax
    cmp $0x0d, %al
    jne 5f
    inc %rcx
    movzbl (%rbx, %rcx), %eax
    cmp $0x0a, %al
    jne 5f
    inc %rcx
    movzbl (%rbx, %rcx), %eax
    cmp $0x0d, %al
    jne 5f
    inc %rcx
    movzbl (%rbx, %rcx), %eax
    cmp $0x0a, %al
    jne 5f
    inc %rcx
    // encontrado
    lea (%rbx, %rcx), %rax    // body ptr
    mov %r12, %rdx
    sub %rcx, %rdx             // body len
    jmp 3f
5:  inc %rcx
    jmp 1b

2:  // no encontró — devolver todo
    mov %rbx, %rax
    mov %r12, %rdx

3:  pop %r12
    pop %rbx
    pop %rbp
    ret

// strlen_rdi(rdi: ptr) → rax: len
strlen_rdi:
    xor %rax, %rax
1:  movzbl (%rdi, %rax), %ecx
    test %cl, %cl
    jz 2f
    inc %rax
    jmp 1b
2:  ret

// append_bytes_r12: rsi=src, rcx=len
append_bytes_r12:
    test %rcx, %rcx
    jz 2f
1:  movzbl (%rsi), %eax
    movb %al, (%r12)
    inc %rsi
    inc %r12
    dec %rcx
    jnz 1b
2:  ret

// append_escaped_r12: rsi=src, rcx=len
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

// int_to_str_func(rdi: num, rsi: buf) → rax: len
int_to_str_func:
    push %rbp
    mov %rsp, %rbp
    push %rbx
    push %r12
    push %r13

    mov %rsi, %r12    // buf start
    mov %rsi, %r13    // current
    mov %rdi, %rbx    // number

    test %rbx, %rbx
    jnz 1f
    movb $0x30, (%r13)
    inc %r13
    jmp 4f

1:  // generar dígitos en reverso en stack
    sub $32, %rsp
    lea (%rsp), %rcx
    xor %r8, %r8

2:  test %rbx, %rbx
    jz 3f
    mov %rbx, %rax
    xor %rdx, %rdx
    mov $10, %r9
    idiv %r9          // rax = rbx/10, rdx = rbx%10
    mov %rax, %rbx    // rbx = cociente
    add $0x30, %dl    // dl = dígito ASCII
    movb %dl, (%rcx, %r8)
    inc %r8
    jmp 2b

3:  // invertir
    dec %r8
5:  movzbl (%rcx, %r8), %eax
    movb %al, (%r13)
    inc %r13
    dec %r8
    jns 5b
    add $32, %rsp

4:  sub %r12, %r13
    mov %r13, %rax

    pop %r13
    pop %r12
    pop %rbx
    pop %rbp
    ret
