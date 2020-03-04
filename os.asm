	BITS 16

;**********
;BOOTLOADER
;**********

loader:
	mov ax, 0x9c0
	mov ss, ax      ;stack segment
    mov ax, 0x7c0
    mov ds, ax      ;data segment
	mov sp, 0x1000 

    ;read files
    ;reset
    mov ah, 0h
    int 13h
    ;set buffer
    mov ax, 0x1000
    mov es, ax
    mov bx, 0x0
    ;read
    ;check dl
    cmp dl, 0x80 ;floppy or drive
    je dldrive
    mov ax, 0x203
    mov cx, 1h
    jmp bootread
dldrive:
    mov ax, 0x202
    mov cx, 2h
bootread:
    int 13h
    cmp ah, 0h ;if error stop
    jne $

bootwrite:
    cmp dl, 0x80 ;if drive boot
    je drawlogo
    ;write files to hard drive
    ;reset
    mov ah, 0h
    mov dl, 0h
    int 13h
    ;set buffer and write
    mov ax, 0x1000
    mov es, ax
    mov bx, 0x0
    mov ax, 0x303
    mov cx, 1h
    mov dx, 0x80
    int 13h
    mov dl, 0h ;floppy boot
    cmp ah, 0h ;if error stop
    jne $

drawlogo:
    ;paint logo
    mov ax, 0x7c0
    mov es, ax
    mov bx, 0x9d ;location of logo
nextbox:
    mov ax, [es:bx]
    cmp al, 0h
    je logo0
    cmp al, 1h
    je logo1
    cmp al, 2h
    je logo2
    cmp al, 3h
    je jmppb
logo0:
    mov al, 0x20 ;space
    jmp paintbox
logo1:
    mov al, 0xb2 ;box
    jmp paintbox
logo2:
    ;newline
    mov ah, 0xe
    mov al, 0xa
    int 10h
    mov al, 0xd
paintbox:
    mov ah, 0xe
    int 10h
    inc bx
    jmp nextbox

jmppb:
    cmp dl, 0x80
    jne success
    ;if drive boot
    ;await char and enter OS
    mov ah, 0h
    int 16h
    jmp 0x1000:0x0

success:
    mov ax, 0xe53 ;S
    int 10h

    ;logo
    db 1,1,1,0,1,0,1,0,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,0,1,1,1,2 
    db 1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,2
    db 1,1,1,0,1,0,1,1,0,0,1,0,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,0,1,0,1,2
    db 1,0,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1,0,0,1,0,1,0,1,0,1,0,1,2
    db 1,0,0,0,1,0,1,0,1,0,1,1,1,0,1,1,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,3

    ;fill up space
    times 510-($-$$) db 0
    dw 0xAA55


;**********
;PIKOBRAIN
;**********

input:
    ;char input
    mov ah, 0h
    int 16h

    cmp al, 0xd  ;enter
    je enter  
    cmp al, 0x72 ;r
    je repage
    cmp al, 0x64 ;d
    je date
    cmp al, 0x74 ;t
    je time
    cmp al, 0x6d ;m
    je memory
    cmp al, 0x61 ;a
    je ascii
    cmp al, 0x77 ;w
    je write
    cmp al, 0x63 ;c
    je copy  
    cmp al, 0x6b ;k
    je kalc 
    cmp al, 0x62 ;b
    je brainfuck
    jmp input

enter:
    ;get cursor location
    mov ah, 3h
    mov bh, 0h
    int 10h
    ;move to next line start
    mov ah, 2h
    inc dh
    mov dl, 0h
    int 10h
    jmp input

repage:
    ;move cursor to top left
    mov ah, 2h
    mov bh, 0h
    mov dh, 0h
    mov dl, 0h
    int 10h
    jmp input    

date:
    ;get date
    ;convert to decimal
    ;output
    mov ah, 4h
    int 1ah
    call tdout
    mov ch, cl
    call tdout
    mov ch, dh
    call tdout
    mov ch, dl
    call tdout
    jmp input
time:
    ;get time
    ;convert to decimal
    ;output
    mov ah, 2h
    int 1ah
    call tdout
    mov ch, cl
    call tdout
    mov ch, dh
    call tdout
    jmp input
tdout:
    ;set ax to ch
    ;divide by 16
    mov ah, 0h
    mov al, ch
    mov bl, 0x10
    div bl
    ;output current numbers
    mov bx, ax
    add bx, 0x3030
    mov ah, 0xe
    mov al, bl
    int 10h
    mov al, bh
    int 10h
    ret	

memory:
    call readfile
    mov cx, 1h ;counter
    mov dl, 0x10 ;divisor
    jmp mbyte
readfile:
    ;get file number
    mov ah, 0h
    int 16h
    mov ch, 0h
    mov cl, al
    sub cl, 30h
    ;read file
    ;reset drive
    mov ah, 0h
    mov dl, 0x80
    int 13h
    ;set buffer
    mov ax, 0x1200
    mov es, ax
    mov bx, 0x0
    ;read
    mov ax, 0x201
    mov dx, 0x80
    int 13h
    ret
mbyte:
    ;get content of byte
    push bx
    mov ax, [es:bx]
    mov ah, 0h
    div dl ;make HEX
    cmp ah, 0xa
    jl skip1
    add ah, 7h ;make it a letter HEX
skip1:
    mov bh, ah
    add bh, 30h
    cmp al, 0xa
    jl skip2
    add al, 7h
skip2:
    mov bl, al
    add bl, 30h
    ;output content of byte
    mov ah, 0xe
    mov al, bl    
    int 10h
    mov al, bh
    int 10h
    mov al, 0x20 ;space
    int 10h
    pop bx
    cmp cx, 0x200 ;reading 512 bytes
    je input
    inc bx
    inc cx
    jmp mbyte

ascii:
    ;read file as ASCII chars
    call readfile
nextascii:
    mov ax, [es:bx]
    mov ah, 0xe
    int 10h
    cmp cx, 0x200
    je input
    inc bx
    inc cx
    jmp nextascii

write:
    ;get file number
    mov ah, 0h
    int 16h
    sub al, 30h
    mov cl, al
    ;move pointer
    mov ax, 0x1200
    mov es, ax
    mov bx, 0x0
    mov dx, 1h ;char counter
typechar:
    ;get char to write    
    mov ah, 0h
    int 16h
    ;write character typed
    mov ah, 0xe
    int 10h
    ;special chars
    cmp al, 0x60 ;` save
    je save    
    cmp al, 0x8
    je backspace
    cmp al, 0x7e ;~ cancel
    je input
    mov byte [es:bx], al   
    cmp dx, 0x200 
    je save   
    inc bx  
    inc dx
    jmp typechar
backspace:
    dec bx
    dec dx
    jmp typechar
save:
    ;write file to hard drive
    ;reset drive
    mov ah, 0h
    mov dl, 0x80
    int 13h
    ;set buffer and write
    mov ax, 0x1200
    mov es, ax
    mov bx, 0x0
    mov ax, 0x301
    mov ch, 0h ;cl is already set
    mov dx, 0x80
    int 13h
    jmp input 
    
copy:
    call readfile
    mov ah, 0h ;number of destination file
    int 16h
    sub al, 30h
    mov cl, al
    jmp save 

kalc:
    mov ax, 0x61 ;end of answer
    push ax
    mov bx, 0h  ;int storage
    mov cx, 0h  ;power counter
    push cx ;necessary for "nextint"
    mov dx, 0xa ;divisor
nextnum:
    ;get number
    mov ah, 0h
    int 16h
    cmp al, 0xd ;enter
    je nextint
    mov ah, 0xe
    int 10h
    mov ah, 0h
    sub al, 30h
    cmp cl, 0h ;special case
    je cl0
    ;multiplicate with relevant power
    push ax
    mov ax, dx
    mul cx
    mov dx, ax
    pop ax
    mul dx
    add bx, ax
    inc cl
    jmp nextnum
cl0:
    add bx, ax
    inc cl
    jmp nextnum
nextint:
    pop cx
    cmp ch, 1h ;if both ints inputted
    je kalcop
    push bx ;store int1
    mov ch, 1h
    push cx
    mov bx, 0h
    mov cx, 0h
    mov dx, 0xa
    jmp nextnum
kalcop:
    pop cx ;first int
    mov ah, 0h
    int 16h
    cmp al, 0x31 ;add
    je kalcadd
    cmp al, 0x32 ;subtract
    je kalcsub
    cmp al, 0x33 ;multiplicate
    je kalcmul
    cmp al, 0x34 ;divide
    je kalcdiv
    cmp al, 0x35 ;modulo
    je kalcmod
    mov ah, 0xe
    int 10h
    jmp kalcop ;if wrong redo
kalcadd:
    mov ax, bx 
    add ax, cx
    jmp kalcans
kalcsub:
    mov ax, bx
    sub cx, ax
    mov ax, cx
    jmp kalcans
kalcmul:
    mov ax, bx
    mul cx
    jmp kalcans
kalcdiv:
    mov dx, 0h ;(dx ax) / cx
    mov ax, cx
    mov cx, bx
    div cx
    jmp kalcans
kalcmod:
    mov dx, 0h
    mov ax, cx
    mov cx, bx
    div cx
    mov ax, dx
kalcans:    
    ;answer stored in ax
    mov dx, 0h  ;(dx ax) / cx
    mov cx, 0xa ;divisor
kalcnext:
    div cx
    push dx ;store reversed order
    cmp ax, 0h
    je kalcout
    mov dx, 0h
    jmp kalcnext
kalcout:
    mov ah, 0xe
    mov al, 0x3d ;=
    int 10h
ansnext:
    pop ax
    cmp ax, 0x61 ;end of ans
    je input
    add ah, 0xe
    add al, 30h
    int 10h ;output answer
    jmp ansnext

brainfuck:
    call readfile ;es:bx
    mov ax, 0x1300
    mov fs, ax
    mov si, 0x0 ;fs:si, operate onto
bfnext:
    cmp byte [es:bx], 0x31 ;+
    je bf1
    cmp byte [es:bx], 0x32 ;-
    je bf2
    cmp byte [es:bx], 0x33 ;<
    je bf3
    cmp byte [es:bx], 0x34 ;>
    je bf4
    cmp byte [es:bx], 0x35 ;.
    je bf5
    cmp byte [es:bx], 0x36 ;,
    je bf6
    cmp byte [es:bx], 0x37 ;[
    je bf7
    cmp byte [es:bx], 0x38 ;]
    je bf8
    cmp byte [es:bx], 0x0 ;code end
    je input
    jmp bfend
bf1:
    inc byte [fs:si]
    jmp bfend
bf2:
    dec byte [fs:si]
    jmp bfend
bf3:
    inc si
    jmp bfend
bf4:
    dec si
    jmp bfend
bf5:
    mov ax, [fs:si]
    mov ah, 0xe
    int 10h
    jmp bfend
bf6:
    mov ah, 0h
    int 16h
    mov [fs:bx], al
bf7:
    mov cx, 1h ;inc or dec
    cmp byte [fs:si], 0h
    jne bfend
    jmp bf78
bf8:
    mov cx, -1h
    cmp byte [fs:si], 0h
    je bfend
bf78:
    mov dx, 1h ;nested loops
bf78cmp:
    cmp dx, 0h
    je bfend
bf78next:
    add bx, cx
    cmp byte [es:bx], 0x37 ;[
    je bf7837
    cmp byte [es:bx], 0x38 ;]
    je bf7838
    jmp bf78next
bf7837:
    add dx, cx
    jmp bf78cmp
bf7838:
    sub dx, cx
    jmp bf78cmp
bfend:
    inc bx ;next char
    jmp bfnext

    ;fill up space
    times 296 db 0


;nasm -f bin -o myfirst.bin myfirst.asm
;dd status=noxfer conv=notrunc if=myfirst.bin of=myfirst.flp
