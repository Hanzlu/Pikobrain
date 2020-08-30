	BITS 16

;**********
;BOOTLOADER
;**********

jmp bootloader

    db "Pikobrain v0.5.3", 0xd, 0xa
    db "Commands in Pikobrain:", 0xd, 0xa
    db "t : time", 0xd, 0xa
    db "d : date", 0xd, 0xa
    db "enter : enter", 0xd, 0xa
    db "r : return", 0xd, 0xa
    db "n : new", 0xd, 0xa
    db "i : info", 0xd, 0xa
    db "f [fold] : folder", 0xd, 0xa
    db "w [file] : write", 0xd, 0xa
    db "e [file] : edit", 0xd, 0xa
    db "a [file] : ascii", 0xd, 0xa
    db "m [file] : memory", 0xd, 0xa
    db "c [file] [fold] [file] : copy", 0xd, 0xa
    db "k [4hex] [4hex] [oper] : kalculator", 0xd, 0xa
    db "h [4hex] : hex", 0xd, 0xa
    db "p [file] [cons] : program", 0xd, 0xa
    db "b [disk] [file] [file] : bridge", 0xd, 0xa, 0

;74 byte effective bootloader
bootloader:
	mov ax, 0x9c0
	mov ss, ax      ;stack segment
    mov ax, 0x7c0
    mov ds, ax      ;data segment
	mov sp, 0x1000 

    ;read files
    ;set buffer
    mov ax, 0x1000
    mov es, ax
    mov bx, 0x0
    ;read
    mov ax, 0x203 ;files to read 3x
    mov cx, 1h
    int 13h
    cmp ah, 0h ;if error stop
    jne $

    cmp dl, 0x80 ;if drive boot
    je jmppb
    ;write files to hard drive
    mov ax, 0x303 ;3x files to write
    mov cx, 1h
    mov dx, 0x80
    int 13h
    mov dl, 0h ;since dl was changed
    cmp ah, 0h ;if error stop
    jne $

jmppb:
    cmp dl, 0x80
    jne success
    ;if drive boot
    ;await char and enter OS
    jmp 0x1020:0x0 ;pikobrain input
success:
    mov ax, 0xe53 ;S
    int 10h
    jmp $

    ;fill up space
    times 510-($-$$) db 0
    dw 0xAA55


;**********
;PIKOBRAIN
;**********    

    ;press any key
    mov ah, 0h
    int 16h
new:
    ;set color
    mov ax, 0x600
    mov bh, 0x3e
    mov cx, 0h
    mov dx, 0x184f
    int 10h
    jmp repage

input:
    ;char input
    mov ah, 0h
    int 16h

    cmp al, 0xd  ;enter
    je callenter  
    cmp al, 0x72 ;r
    je repage
    cmp al, 0x64 ;d
    je date
    cmp al, 0x74 ;t
    je time
    cmp al, 0x6d ;m
    je memory
    cmp al, 0x61 ;a
    je callascii
    cmp al, 0x77 ;w
    je write
    cmp al, 0x65 ;e
    je edit
    cmp al, 0x63 ;c
    je copy  
    cmp al, 0x6b ;k
    je kalc 
    cmp al, 0x70 ;p
    je program
    cmp al, 0x66 ;f
    je callfolder
    cmp al, 0x68 ;h
    je hex
    cmp al, 0x69 ;i
    je info
    cmp al, 0x6e ;n
    je new
    cmp al, 0x62 ;b
    je bridge
    jmp input

;**********
;FUNCTIONS
;**********

callenter:
    call enter
    jmp input
enter:
    mov ax, 0xe0d
    int 10h
    mov al, 0xa
    int 10h
    ret

readfile:
    call ramclear
    mov dl, 0x80 ;drive
    call setfolder
    ;get filenum
    call filenum
    and cl, 0x3f ;remove high order bits
    ;read file
    ;set buffer
    mov ax, 0x1200
    mov es, ax
    pop bx
    pop ax ;ax was pushed
    push bx ;automatic
    mov bx, 0x0
    int 13h
    ret

dxtod: ;decimalhex to dec
    ;ch is number to convert
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

xtox: ;hex to hex
    ;ch contains number
    ;output ch as hex
    mov bl, 0x10
    mov ah, 0h
    mov al, ch
    div bl
    ;output numbers
    call xtoasc
    mov bh, al
    mov al, ah
    call xtoasc
    mov bl, al
    mov ah, 0xe
    mov al, bh
    int 10h
    mov al, bl
    int 10h
    ret

atohex:
    ;ascii to hex
    sub al, 30h
    cmp al, 9h
    jle athback
    sub al, 7h
athback:
    ret

xtoasc:
    ;hex to ascii
    add al, 30h
    cmp al, 39h
    jle xtaback
    add al, 7h
xtaback:
    ret

filenum:
    ;get 2 digit hex num input
    ;do not store stuff in ax
    ;convert and into cl
    mov ah, 0h
    int 16h
    mov ah, 0xe
    int 10h
    call atohex
    mov cl, al
    shl cl, 4h ;*16
    mov ah, 0h
    int 16h
    mov ah, 0xe
    int 10h
    call atohex
    add cl, al
    call enter
    ret

setfolder:
    ;set folder
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x5ff
    mov ax, [fs:si]
    mov dh, 0x10 ;for 8MB
    div dh
    mov ch, ah
    mov dh, al
    ret

callfolder:
    call folder
    jmp input
folder:
    ;change head and track
    ;set folder
    ;dh and ch for int 13h
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x5ff
    call filenum
    mov byte [fs:si], cl
    ret

ramclear:
    mov ax, 0x1200
    mov es, ax
    mov bx, 0h
ramloop:
    mov byte [es:bx], 0h
    inc bx
    cmp bx, 0x200
    jne ramloop
    ret

;*********
;COMMANDS
;*********

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
    call dxtod
    mov ch, cl
    call dxtod
    mov ax, 0xe2f ;/
    int 10h
    mov ch, dh
    call dxtod
    mov ax, 0xe2f ;/
    int 10h
    mov ch, dl
    call dxtod
    jmp input
time:
    ;get time
    ;convert to decimal
    ;output
    mov ah, 2h
    int 1ah
    call dxtod
    mov ax, 0xe3a ;:
    int 10h
    mov ch, cl
    call dxtod
    mov ax, 0xe3a ;:
    int 10h
    mov ch, dh
    call dxtod
    jmp input	

memory:
    mov ax, 0x201
    push ax
    call readfile
mbyte:
    ;get content of byte
    push bx ;pointer
    mov ch, byte [es:bx]
    call xtox
    mov al, 0x20 ;space
    int 10h
    pop bx ;byte pointer
    cmp bx, 0x1ff ;reading 512 bytes
    je input
    ;newline if row filled
    mov ax, bx
    inc ax
    mov dh, 0x19
    div dh
    cmp ah, 0h
    jne mdiv ;mod 25
    ;enter
    call enter
mdiv:
    inc bx
    jmp mbyte

callascii:
    call ascii
    jmp input
ascii:
    ;read file as ASCII chars
    mov ax, 0x201
    push ax
    call readfile
nextascii:
    mov ax, [es:bx]
    mov ah, 0xe
    int 10h
    cmp al, 0h
    je asciiend
    cmp bx, 0x1ff
    je asciiend
    inc bx
    jmp nextascii
asciiend:
    ret

write:
    ;clear ram
    call ramclear
    ;get file number
    call filenum
    ;move pointer
    mov ax, 0x1200
    mov es, ax
    mov bx, 0x0
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
    cmp al, 0x8 ;backspace
    je backspace
    cmp al, 0xd ;enter
    je wenter 
    cmp al, 0x9 ;tab cancel
    je input
    mov byte [es:bx], al   
    cmp bx, 0x1ff 
    je save   
    inc bx  
    jmp typechar
backspace:
    dec bx
    mov ax, 0xe00
    int 10h
    mov byte [es:bx], al
    mov al, 0x8 ;backspace
    int 10h
    jmp typechar
wenter:
    mov byte [es:bx], 0xd
    inc bx
    mov byte [es:bx], 0xa
    inc bx
    mov ax, 0xe0a
    int 10h
    jmp typechar ;can exceed 512 limit
save:
    mov ax, 0xe60 ;`
    int 10h
    ;set buffer and write
    mov ax, 0x1200
    mov es, ax
    mov bx, 0x0
    mov dl, 0x80
    ;set ch and dh
    call setfolder    
    ;cl is already set
    and cl, 0x3f ;remove high order bits
    mov ax, 0x301
    int 13h
    jmp input 

edit:
    ;edit file
    call ascii
    mov ax, 0xe08 ;backspace
    int 10h
    jmp typechar
    
copy:
    mov ax, 0x201
    push ax
    call readfile ;source
    call folder ;dest folder
    call filenum ;dest file
    jmp save 

kalc:
    call kgetint
    call kgetint
    ;2 integers stored on stack
    ;0000-FFFF
    ;return integers
    pop cx
    pop dx ;first integer
    ;get operator
    mov ah, 0h
    int 16h
    cmp al, 31h ;1=add
    je kadd
    cmp al, 32h ;2=subtract
    je ksub
    cmp al, 33h ;3=multiply
    je kmul
    cmp al, 34h ;4=divide
    je kdiv
    cmp al, 35h ;5=modulo
    je kmod
    jmp input ;if invalid
    ;answer stored in dx
kadd:
    add dx, cx
    jmp kanswer
ksub:
    sub dx, cx
    jmp kanswer
kmul:
    mov ax, dx
    mul cx
    mov dx, ax
    jmp kanswer
kdiv:
    mov ax, dx
    mov dx, 0h
    div cx
    mov dx, ax
    jmp kanswer
kmod:
    mov ax, dx
    mov dx, 0h
    div cx
    ;dx is remainder
kanswer:
    ;answer in dx
    mov ch, dh
    call xtox
    mov ch, dl
    call xtox
    ;answer outputted as hex
    jmp input
kgetint:
    call filenum
    mov ch, cl
    call filenum ;cl already set
    pop ax
    push cx ;store number
    push ax
    ret

program:
    ;read files
    ;buffer
    mov ax, 0x1300
    mov es, ax
    mov bx, 0h
    ;first file
    call filenum
    push cx ;filenum
    ;number of files
    call filenum
    mov dl, cl ;store for al
    ;set cx
    pop cx
    ;folder
    call setfolder
    mov ah, 2h
    mov al, dl
    mov dl, 0x80 ;drive
    int 13h ;read
    mov dx, 0x200
    mov ah, 0h
    mul dx
    mov si, ax ;number of bytes to read
    mov dl, 0x10 ;multplier
pconv:
    ;convert ascii hex to hex
    mov ax, [es:bx]
    ;make ascii into int
    call atohex
    mul dl
    mov cl, al
    inc bx
    mov ax, [es:bx]
    call atohex
    add cl, al
    ;div bx 2
    shr bx, 1h
    ;store
    mov byte [es:bx], cl
    inc bx
    shl bx, 1h ;mul bx 2
    cmp bx, si ;check bytes read
    jl pconv
    jmp 0x1300:0x0

hex:
    ;convert hex to dec
    mov ax, 0x30 ;end of result
    push ax
    ;get 4-digit hex
    call filenum
    mov bh, cl
    call filenum
    mov bl, cl
    mov dx, 0h ;dx ax / bx, else too large result
    mov ax, bx
    mov bx, 0xa ;divisor
hloop:
    ;convert
    div bx
    push dx ;store remainder
    cmp ax, 0h ;division ended
    je hend
    mov dx, 0h ;clear
    jmp hloop
hend:
    ;write result
    pop ax
    cmp al, 0x30 ;end of result
    je input
    ;output
    mov ah, 0xe
    add al, 30h ;printable
    int 10h
    jmp hend

info:  
    ;ouput folder number hex
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x5ff
    mov ch, byte [fs:si]
    call xtox
    call enter
    ;output files 
    mov di, 0h ;counter
    ;get file info in folder
    ;buffer
    mov ax, 0x1200
    mov es, ax
    mov bx, 0h
    ;other stuff
    call setfolder
    mov cl, 1h ;changes later
    mov dl, 0x80
    mov ax, 0x201
    int 13h ;read
iloop:
    push cx ;store
    mov al, byte [es:bx]
    cmp al, 0h
    je ilend
    ;output cl
    mov ch, cl
    call xtox
    mov ax, 0xe2e ;.
    int 10h
    mov cl, 0h ;char counter
    mov bx, 0h
iwloop:
    ;write 5 chars
    mov al, byte [es:bx]
    cmp al, 0x20
    jge iw
    mov al, 0x2a ;*
iw:
    mov ah, 0xe
    int 10h
    inc cl
    cmp cl, 5h
    je iwend
    inc bx
    jmp iwloop
iwend:
    mov ax, 0xe20 ;space
    int 10h
    int 10h
    int 10h ;3 times
    inc di
ilend:
    pop cx
    inc cl
    cmp cl, 0x40 ;last file
    je input
    ;prepare read
    call setfolder
    mov ax, 0x201
    mov bx, 0h
    int 13h 
    ;check di
    cmp di, 3h
    je idi3 
    jmp iloop
idi3:
    call enter
    mov di, 0h
    jmp iloop

bridge:
    ;buffer
    mov ax, 0x1200
    mov es, ax
    mov bx, 0h
    ;drive
    mov ax, 0x201
    push ax
    call filenum
    mov dl, cl
bset:
    ;rest of registers
    call setfolder
    call filenum
    pop ax
    push ax
breadwrite:
    int 13h ;r/w
    ;if read
    pop ax
    cmp ah, 3h
    je input
    ;prepare write
    mov ah, 3h
    push ax
    xor dl, 0x80 ;flip between 0 and 80
    jmp bset

    times 4 db 0
    db 0h ;0x1000:0x5ff -- hd head/track 

;nasm -f bin -o myfirst.bin myfirst.asm
;dd status=noxfer conv=notrunc if=myfirst.bin of=myfirst.flp
