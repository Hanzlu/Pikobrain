	BITS 16

;**********
;BOOTLOADER
;**********

jmp bootloader

    db "Pikobrain v1.1.5", 0xd, 0xa
    db "Hanzlu 2019-2020", 0xd, 0xa
    db "Commands:", 0xd, 0xa
    db "t time", 0xd, 0xa
    db "d date", 0xd, 0xa
    db "enter", 0xd, 0xa
    db "n new", 0xd, 0xa
    db "o os", 0xd, 0xa
    db "k [4h] [4h] [1d] kalc", 0xd, 0xa
    db "h [4h] hex", 0xd, 0xa
    db "x [5d] xdec", 0xd, 0xa
    db "f [fo] folder", 0xd, 0xa
    db "s [str] search", 0xd, 0xa
    db "i info", 0xd, 0xa
    db "z ['y'] zero", 0xd, 0xa
    db "w [fi] write", 0xd, 0xa
    db "e [fi] edit", 0xd, 0xa
    db "r [fi] read", 0xd, 0xa
    db "m [fi] memory", 0xd, 0xa
    db "c [fi] [fo] [fi] copy", 0xd, 0xa
    db "p [fi] [2h] program"

    ;variables
    bootdrive db 0h
    heads db 0h
    tracks dw 0h
    sectors db 0h    

bootloader:
	mov ax, 0x9c0
	mov ss, ax      ;stack segment
    mov ax, 0x7c0
    mov ds, ax      ;data segment
	mov sp, 0x1000 

    ;store dl
    mov [bootdrive], dl
    ;store drive information
    mov ah, 8h
    int 13h
    mov [heads], dh
    mov dh, cl
    and cl, 0x3f ;clear upper two bits
    mov [sectors], cl
    shr dh, 6h
    mov bh, dh
    mov bl, ch
    mov [tracks], bx
    ;reset dl
    mov dl, [bootdrive]

    ;print bootdrive
    mov ax, 0h
    mov al, dl
    mov bl, 0x10
    div bl
    mov bx, ax
    add bx, 0x3030
    cmp bl, 0x3a
    jl bootdl
    add bl, 7h ;make letter
bootdl:
    cmp bh, 0x3a
    jl bootdl2
    add bh, 7h ;make letter
bootdl2:
    mov ah, 0xe
    mov al, bl
    int 10h
    mov al, bh
    int 10h    
    
    ;read files
    ;set buffer
    mov ax, 0x1000
    mov es, ax
    mov bx, 0x0
    ;read
    mov ax, 0x204 ;files to read 4x
    mov cx, 1h
    mov dh, 0h ;dl set
    int 13h
    cmp ah, 0h ;if error stop
    jne $

    ;check if install has been made
    mov bx, 0x1fd
    mov al, [es:bx]
    cmp al, 1h
    jne jmppb
    ;mark as installed
    mov byte [es:bx], 0h ;set as 0
    cmp dl, 0x80 ;if USB boot
    je boot81
    mov dx, 0x80
    jmp install
boot81:
    mov dx, 0x81
install:
    ;write files to hard drive
    mov bx, 0h
    mov ax, 0x304 ;4x files to write
    mov cx, 1h
    int 13h
    mov dl, 0h ;since dl was changed
    cmp ah, 0h ;if error stop
    jne $

jmppb:
    ;check boot
    cmp dl, 0x80
    jne success
    jmp 0x1020:0x0 ;pikobrain input

success:
    mov ax, 0xe53 ;S
    int 10h
    jmp $

    ;fill up space
    times 509-($-$$) db 0
    db 1h ;boot true
    dw 0xAA55


;**********
;PIKOBRAIN
;**********    

new:
    ;set color
    mov ax, 0x600
    mov bh, 0x3e
    mov cx, 0h
    mov dx, 0x184f
    int 10h
    ;move cursor to top left
    mov ah, 2h
    mov bh, 0h
    mov dx, 0h
    int 10h

input:
    ;char input
    mov ah, 0h
    int 16h

    cmp al, 0xd  ;enter
    je callenter  
    cmp al, 0x64 ;d
    je date
    cmp al, 0x74 ;t
    je time
    cmp al, 0x6e ;n
    je new
    cmp al, 0x6b ;k
    je kalc 
    cmp al, 0x68 ;h
    je hex
    cmp al, 0x78 ;x
    je xdec
    cmp al, 0x6f ;o
    je os
    cmp al, 0x6d ;m
    je memory
    cmp al, 0x72 ;r
    je callread
    cmp al, 0x77 ;w
    je write
    cmp al, 0x65 ;e
    je edit
    cmp al, 0x63 ;c
    je copy  
    cmp al, 0x66 ;f
    je callfolder
    cmp al, 0x69 ;i
    je info
    cmp al, 0x7a ;z
    je zero
    cmp al, 0x73 ;s
    je search
    cmp al, 0x70 ;p
    je program
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
    ;set buffer
    mov ax, 0x1200
    mov es, ax
    mov bx, 0x0
    call filenum
    and cl, 0x3f ;remove high order bits
    call setfolder
    ;get filenum
    mov ax, 0x201
    mov dl, 0x80 ;drive
    int 13h
    ret

xtox: ;hex to hex
    ;ch contains number
    ;output ch as hex
    mov al, ch
    and al, 0xf ;clear upper nibble
    call xtoasc
    mov ah, al ;store
    mov al, ch
    shr al, 4h
    call xtoasc ;convert
    mov ch, ah ;store
    mov ah, 0xe
    int 10h
    mov al, ch
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
    shl cl, 4h ;*16, upper nibble
    mov ah, 0h
    int 16h
    mov ah, 0xe
    int 10h
    call atohex
    add cl, al ;lower nibble
    ret

setfolder:
    ;set folder
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x7fd ;OS size depending
    mov al, [fs:si]
    shl al, 6h ;into right position
    add cl, al ;set cl
    inc si
    mov dh, [fs:si] ;head
    inc si
    mov ch, [fs:si]
    ret

callfolder:
    call folder
    jmp input
folder:
    ;change head and track
    ;dh and ch (cl) for int 13h
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x7fd ;OS size depending
    call filenum
    cmp cl, 0h ;double press enter to select current folder-> value will be negative
    jl fsame
    cmp cl, 0x3f ;double press letter to select home folder
    jg fhome
    and cl, 3h ;clear bits
    mov [fs:si], cl
    inc si
    ;dh head
    call filenum
    mov [fs:si], cl
    inc si
    ;ch track lower
    call filenum
    mov [fs:si], cl 
    call enter
    ret
fhome:
    mov byte [fs:si], 0h
    inc si
    mov byte [fs:si], 0h
    inc si
    mov byte [fs:si], 0h
    call enter
    ret
fsame:
    mov ax, 0xe2a ;*
    int 10h
    ret

;*********
;COMMANDS
;*********   

date:
    ;get date
    ;convert to decimal
    ;output
    mov ah, 4h
    int 1ah
    call xtox
    mov ch, cl
    call xtox
    mov ax, 0xe2f ;/
    int 10h
    mov ch, dh
    call xtox
    mov ax, 0xe2f ;/
    int 10h
    mov ch, dl
    call xtox
    jmp input
time:
    ;get time
    ;convert to decimal
    ;output
    mov ah, 2h
    int 1ah
    call xtox
    mov ax, 0xe3a ;:
    int 10h
    mov ch, cl
    call xtox
    mov ax, 0xe3a ;:
    int 10h
    mov ch, dh
    call xtox
    jmp input	

memory:
    call readfile
menter: ;check last line
    call enter
mbyte:
    ;get content of byte
    mov ch, [es:bx]
    call xtox
    mov al, 0x20 ;space
    int 10h
    inc bx
    cmp bx, 0x200 ;reading 512 bytes
    je input
    ;newline if row filled
    mov ax, bx
    mov dh, 0x19 ;25
    div dh
    cmp ah, 0h
    jne mbyte
    ;enter
    jmp menter

callread:
    call read
    jmp input
read:
    ;read file as ASCII chars
    call readfile
    call enter
nextread:
    mov al, [es:bx]
    mov ah, 0xe
    int 10h
    cmp al, 0h ;null char
    je readend
    cmp bx, 0x200 ;because of edit
    je readend
    inc bx
    jmp nextread
readend:
    ret

write:
    mov ax, 0x1200
    mov es, ax
    mov bx, 0h
    ;get file number
    call filenum
    push cx
    call enter
typechar:
    ;get char to write    
    mov ah, 0h
    int 16h
    ;check if backspace
    cmp al, 0x8 ;backspace
    je backspace
    ;write character typed
    mov ah, 0xe
    int 10h
    ;special chars
    cmp al, 0x60 ;` save
    je saveram    
    cmp al, 0xd ;enter
    je wenter 
    cmp al, 0x9 ;tab cancel
    je input
    cmp al, 0x5c ;\ special char
    je wspecial
    mov byte [es:bx], al   
    cmp bx, 0x1ff 
    je save   
    inc bx  
    jmp typechar
backspace:
    ;get cursor position
    mov ah, 3h
    int 10h
    ;output backspace
    mov ax, 0xe08
    int 10h
    dec bx
    mov ch, byte [es:bx] ;store
    mov byte [es:bx], 0h ;clear byte (and 0xa in case \n)
    cmp dl, 0h ;newline erase? (cursor pos)
    je wbnl
wbauto: ;epic hack jump from wbnl
    mov ax, 0xa20 ;for backspace newline
    int 10h
    jmp typechar
wbnl:
    ;move cursor
    mov ah, 2h
    dec dh
    mov dl, 0x4f ;79
    int 10h
    cmp ch, 0xa ;was stored, check if newline
    jne wbauto
    ;remove newline
    dec bx
    mov byte [es:bx], 0h ;clear 0xd
wbnloop:
    ;get cursor char
    mov ah, 8h
    int 10h
    cmp al, 0x20 ;space apparently
    jne wbnlend
    ;get cursor position
    mov ah, 3h
    int 10h
    cmp dl, 0h ;beginning of line
    je typechar
    ;mov cursor left
    dec ah ;2h
    dec dl
    int 10h
    jmp wbnloop
wbnlend:
    ;cursor right
    mov ah, 2h
    inc dl
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
wspecial:
    ;get special char code
    mov ax, 0xe08 ;backspace
    int 10h
    ;get charcode
    call filenum
    mov byte [es:bx], cl
    ;clear filenum chars
    mov ax, 0xe08
    int 10h
    mov ax, 0xa20 ;space for backspace
    int 10h
    mov ax, 0xe08
    int 10h
    ;output special char
    mov al, cl
    int 10h
    inc bx
    jmp typechar
saveram:
    mov byte [es:bx], 0h
    inc bx
    cmp bx, 0x200
    jne saveram
save:
    ;set buffer and write
    mov bx, 0x0 ;reset
    mov dl, 0x80   
    and cl, 0x3f ;remove high order bits
    ;set ch and dh
    call setfolder 
    mov ax, 0x301
    int 13h
    mov ax, 0xe60 ;`
    int 10h
    jmp input  

edit:
    ;edit file
    call read
    mov ax, 0xe08 ;backspace
    int 10h
    jmp typechar
    
copy:
    call readfile ;source
    call enter
    call folder ;dest folder
    call filenum ;dest file
    jmp save 

kalc:
    call kgetint
    push cx ;store number
    call kgetint
    ;2 integers stored on stack
    ;0000-FFFF
    ;return integers
    pop dx ;first integer, 2nd already in cx
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
    cmp al, 36h ;6=and
    je kand
    cmp al, 37h ;7=or
    je kor
    cmp al, 38h ;8=xor
    je kxor
    cmp al, 39h ;9=not
    je knot    
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
    jmp kanswer
kand:
    and dx, cx
    jmp kanswer
kor:
    or dx, cx
    jmp kanswer
kxor:
    xor dx, cx
    jmp kanswer
knot:
    not dx
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
    call enter
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
    mov dx, 0x200 ;multiplier
    mov ah, 0h
    mul dx ;number of bytes to read
    mov si, ax
pconv:
    ;convert ascii hex to hex
    mov al, [es:bx]
    ;make ascii into int
    call atohex
    shl al, 4h ;*16
    mov cl, al
    inc bx
    mov al, [es:bx]
    call atohex
    add cl, al
    ;div bx 2
    shr bx, 1h
    ;store
    mov [es:bx], cl
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
    call enter
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
    mov dl, 0h ;clear
    jmp hloop
hend:
    ;write result
    pop ax
    cmp al, 0x30 ;end of result
    je input
    ;output
    add ax, 0xe30 ;printable, ah=0
    int 10h
    jmp hend

info:  
    ;ouput folder number hex
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x7fd
    mov ch, [fs:si]
    call xtox
    inc si
    mov ch, [fs:si]
    call xtox
    inc si
    mov ch, [fs:si]
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
    mov cl, 1h ;changes later
    call setfolder
    mov dl, 0x80
    mov ax, 0x201
    int 13h ;read
    and cl, 0x3f ;clear upper bits
iloop:
    mov al, [es:bx]
    cmp al, 0h ;is empty?
    je ilend
    ;output filenum
    mov ch, cl
    call xtox
    mov ax, 0xe2e ;.
    int 10h
    mov ch, 0h ;char counter
iwloop:
    ;write 5 chars
    mov al, [es:bx]
    cmp al, 0x20 ;space
    jge iw
    mov al, 0x2a ;*
iw:
    mov ah, 0xe
    int 10h
    inc ch
    cmp ch, 5h
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
    inc cl
    cmp cl, 0x40 ;last file
    je input
    ;prepare read
    call setfolder
    mov ax, 0x201
    mov bx, 0h
    int 13h
    and cl, 0x3f ;clear upper bits 
    ;check di
    cmp di, 3h
    je idi3 
    jmp iloop
idi3:
    call enter
    mov di, 0h
    jmp iloop

zero:
    mov ax, 0xe21 ;!
    int 10h
    ;get y for yes
    mov ah, 0h
    int 16h
    cmp al, 0x79 ;y
    jne input
    ;buffer
    mov ax, 0x1200
    mov es, ax
    mov dl, 80h
    mov cl, 1h
zloop:   
    ;read
    call setfolder
    mov ax, 0x201
    mov bx, 0h ;must be here! reset
    int 13h
    and cl, 0x3f ;clear upper bits
zread:
    mov al, [es:bx]
    cmp al, 0h ;end of content
    je zwrite
zzero:
    mov byte [es:bx], 0h
    inc bx
    cmp bx, 0x200
    jne zzero
zwrite:
    cmp bx, 0h ;empty file
    je zend
    call setfolder
    mov bx, 0h
    ;write
    mov ax, 0x301
    int 13h
    and cl, 0x3f ;clear upper bits
zend:
    inc cl
    cmp cl, 0x40 ;end of folder
    jne zloop
    mov ax, 0xe79 ;y
    int 10h
    jmp input

search:
    mov ax, 0x1110
    mov gs, ax
    mov di, 0x0 ;gs:di search word
sword:
    ;get char
    mov ah, 0h
    int 16h
    mov [gs:di], al ;store
    ;if enter=end
    cmp al, 0xd
    je sstart
    ;output
    mov ah, 0xe
    int 10h  
    inc di
    jmp sword
sstart:
    call enter
    ;buffer
    mov ax, 0x1200
    mov es, ax
    mov bx, 0h
    mov cl, 1h ;will change
sloop:
    call setfolder
    mov di, 0h ;reset
    ;read
    mov dl, 80h
    mov bx, 0h ;must be here! reset
    mov ax, 0x201
    int 13h
    and cl, 0x3f ;clear upper bits
scomp:
    mov al, [es:bx]
    mov dl, [gs:di]
    cmp dl, 0xd
    je sfind
    cmp al, dl
    je snext
    jmp snot
snext:
    inc bx
    inc di
    jmp scomp
sfind:
    ;print file number
    mov ch, cl
    call xtox
    mov ax, 0xe2e ;.
    int 10h
    jmp sfile
snot:
    inc bx
    cmp bx, 0x200
    je sfile
    jmp scomp
sfile:
    inc cl
    cmp cl, 0x40
    je input
    jmp sloop

xdec:
    mov ax, 0x30 ;end of ans
    push ax
    mov dx, 0x2710 ;mul 10000
    mov bx, 0h ;store
    mov cx, 0xa ;dx ax / cx
    mov si, 0h ;counter
xget:
    ;get number
    mov ah, 0h
    int 16h
    ;print
    mov ah, 0xe
    int 10h
    mov ah, 0h
    sub al, 30h
    push dx ;store
    mul dx
    add bx, ax ;store answer in bx
    ;div dx 10
    pop dx
    mov ax, dx
    mov dx, 0h
    div cx
    mov dx, ax
    inc si
    cmp si, 5h ;5 digit number
    jne xget
    mov cx, 0x10 ;div
    mov ax, bx ;answer in bx
xconv:
    mov dx, 0h
    div cx
    push dx ;remainder
    cmp ax, 0h
    jne xconv
    call enter
xout:
    pop ax
    cmp al, 0x30 ;end
    je input
    call xtoasc
    mov ah, 0xe
    int 10h
    jmp xout

os:
    ;display ram
    ;check if extended ram
    mov ah, 88h
    int 15h
    cmp ax, 0h ;no extended
    je osrams
    add ax, 0x400 ;1k
    mov dx, ax
    mov ch, dh
    call xtox
    mov ch, dl
    call xtox
    jmp oskb
osrams:
    ;less than 1MB ram
    int 12h
    mov dx, ax
    mov ch, dh
    call xtox
    mov ch, dl
    call xtox    
oskb:
    mov ax, 0xe6b ;k
    int 10h
    mov al, 0x42 ;B
    int 10h
    call enter
osboot:
    ;display bootdrive
    mov ch, [bootdrive]
    call xtox
    call enter
osfolder:
    ;display largest folder
    ;get upper bits track
    mov dx, [tracks]
    mov ch, dh
    call xtox
    ;rest for folder
    mov ch, [heads]
    call xtox
    mov ch, dl
    call xtox
    call enter
    ;display max file num
    ;get sectors
    mov ch, [sectors]
    call xtox
    jmp input

    times 16 db 0
    db 0h ;upper 2 bits cl -- track
    dw 0h ;0x1000:0x7ff -- hd head/track

;nasm -f bin -o myfirst.bin myfirst.asm
;dd status=noxfer conv=notrunc if=myfirst.bin of=myfirst.flp
