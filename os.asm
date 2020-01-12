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
    je x80
    mov ax, 0x203
    mov cx, 1h
    jmp bootread
x80:
    mov ax, 0x202
    mov cx, 2h
bootread:
    int 13h
    cmp ah, 0h ;if error stop
    jne $

bootwrite:
    cmp dl, 0x80 ;if drive boot
    je drawlogo
    ;write OS to hard drive
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
    cmp ah, 0h ;if error stop
    jne $

drawlogo:
    ;paint logo
    mov ax, 0x7c0
    mov es, ax
    mov bx, 0x96 ;location of logo
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
    jne $
    ;if drive boot
    ;await char
    ;enter OS
    mov ah, 0h
    int 16h
    jmp 0x1000:0x0

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
    mov cx, 1h ;counter
    mov dl, 0x10 ;divisor
    ret
mbyte:
    ;get content of byte
    push bx
    mov ax, [es:bx]
    mov ah, 0h
    div dl
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
    push bx
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
    mov dx, 1h
typechar:
    ;get char to write    
    mov ah, 0h
    int 16h
    ;write character typed
    mov ah, 0xe
    int 10h
    ;special chars
    cmp al, 0x60 ;~
    je save    
    cmp al, 0x8
    je backspace
    cmp al, 0x7e
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

    ;fill up space
    times 660 db 0


;nasm -f bin -o myfirst.bin myfirst.asm
;dd status=noxfer conv=notrunc if=myfirst.bin of=myfirst.flp
