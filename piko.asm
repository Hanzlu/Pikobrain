	BITS 16

;***********
;BOOTLOADER
;***********

jmp bootloader

    db "Pikobrain v1.2.8", 0xd, 0xa
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
    db "c [fi] [2h] [fo] [fi] copy", 0xd, 0xa
    db "a [fi] [2h] [fi] assembly", 0xd, 0xa
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
    mov ax, 0x208 ;files to read 8x
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
    mov ax, 0x308 ;8x files to write
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


callnew:
    call new
    jmp input
new:
    ;set graphics mode
    mov ax, 3h
    int 10h
    ;set color
    mov ax, 0x600
    mov bh, 2h ;black-green
    mov cx, 0h
    mov dx, 0x184f
    int 10h
    ;move cursor to top left
    mov ah, 2h
    mov bh, 0h
    mov dx, 0h
    int 10h
    ret

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
    je callnew
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
    cmp al, 0x61 ;a
    je assembly
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

xtox: ;hex to ascii-hex
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
    ;ascii-hex to hex
    sub al, 30h
    cmp al, 9h
    jle athback
    sub al, 7h
athback:
    ret

xtoasc:
    ;hex to ascii-hex
    add al, 30h
    cmp al, 39h
    jle xtaback
    add al, 7h
xtaback:
    ret

filenum:
    ;get 2 digit hex num input
    ;changes ax and cl
    ;convert and into cl
    mov ah, 0h
    int 16h
    cmp al, 0x8 ;backspace
    je input
    mov ah, 0xe
    int 10h
    call atohex
    mov cl, al
    shl cl, 4h ;*16, upper nibble
    mov ah, 0h
    int 16h
    cmp al, 0x8 ;backspace
    je input
    mov ah, 0xe
    int 10h
    call atohex
    add cl, al ;lower nibble
    ret

setfolder:
    ;set folder
    mov ax, 0x1000
    mov fs, ax
    mov si, 0xffd ;OS size depending
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
    call enter
    jmp input
folder:
    ;change head and track
    ;dh and ch (cl) for int 13h
    mov ax, 0x1000
    mov fs, ax
    mov si, 0xffd ;OS size depending
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
    ret
fhome:
    mov byte [fs:si], 0h
    inc si
    mov byte [fs:si], 0h
    inc si
    mov byte [fs:si], 0h
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
    mov dh, 0h
    call enter
mbyte:
    ;read file as hex
    ;get content of byte
    mov ch, [es:bx]
    call xtox
    mov al, 0x20 ;space
    int 10h
    inc bx
    cmp bx, 0x200 ;reading 512 bytes
    je input
    ;newline if row filled
    inc dh
    cmp dh, 0x19 ;25
    jne mbyte
    ;enter
    jmp menter

callread:
    call read
    jmp input
read:
    ;read file as ASCII chars
    call readfile
    push cx
    call new
    pop cx ;store
nextread:
    mov al, [es:bx]
    cmp al, 0h ;null char
    je readend
    mov ah, 0xe ;due to write
    int 10h
    inc bx
    cmp bx, 0x200 ;because of edit
    je readend
    jmp nextread
readend:
    ret

write:
    ;buffer
    mov ax, 0x1200
    mov es, ax
    ;get file number
    call filenum
    push cx ;store for save
    mov cx, 0h ;due to edit after writeram
    ;set cursor position
    call new
    ;clear ram
    mov bx, 0h
writeram:
    mov byte [es:bx], 0h
    inc bx
    cmp bx, 0x200
    jl writeram ;less due to edit
    mov di, cx
typechar:
    mov bx, 0h
    ;get cursor position
    mov ah, 3h
    int 10h
    push dx ;store
    call new ;clear screen
    mov bx, 0h
    call nextread
    mov bh, 0h
    ;reset cursor
    mov ah, 2h
    pop dx
    int 10h
    ;get char to write
    mov ah, 0h
    int 16h
    ;check if backspace or arrow
    cmp al, 0x8 ;backspace
    je backspace
    cmp ah, 0x4b ;left arrow
    je wleft
    cmp ah, 0x4d ;right arrow
    je wright
    cmp ah, 0x50 ;down arrow
    je wcopy
    cmp ah, 0x48 ;up arrow
    je wpaste
    ;write character typed
    mov ah, 0xe
    int 10h
    ;special chars
    cmp al, 0x60 ;` save
    je save   
    cmp al, 0xd ;enter
    je wenter 
    cmp al, 0x9 ;tab cancel
    je input
    cmp al, 0x5c ;\ special char
    je wspecial 
    cmp al, 0x7e ;~ char count
    je wchar 
    call wloopstart
    cmp si, 0x200
    jge save
    jmp typechar
wloopstart:
    mov si, di
wloop:
    mov ah, [es:si]
    mov [es:si], al
    mov al, ah
    inc si
    cmp si, 0x200
    jge wloopend
    cmp al, 0h
    jne wloop
    inc di
wloopend:
    ret
wleft:
    dec di
    ;get cursor location
    mov ah, 3h
    int 10h
    cmp dl, 0h ;beginning of line
    je wleftnl
    mov ax, 0xe08 ;backspace
    int 10h
    jmp typechar
wleftnl:
    ;move cursor
    dec ah ;2h
    dec dh
    mov dl, 0x4f ;end of line
    int 10h
    cmp byte [es:di], 0xa ;newline
    jne typechar
    dec di
    jmp wbnloop
wright:
    ;get cursor location
    mov ah, 3h
    int 10h
    cmp dl, 0x4f ;end of line
    je wrightnl
    cmp byte [es:di], 0xd ;newline as well
    je wrightnl
    inc di
    ;move cursor right
    dec ah ;2h
    inc dl
    int 10h
    jmp typechar
wrightnl:
    inc di
    ;move cursor
    dec ah ;2h
    inc dh
    mov dl, 0h
    int 10h
    cmp byte [es:di], 0xa ;newline
    jne typechar
    inc di
    jmp typechar
backspace:
    ;get cursor position
    mov ah, 3h
    int 10h
    ;output backspace
    mov ax, 0xe08
    int 10h
    dec di
    mov ch, [es:di] ;must store
    call wbloopstart ;erase
    cmp dl, 0h ;newline erase? (cursor pos)
    je wbnl
wbauto:
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
    dec di
    call wbloopstart
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
wbloopstart:
    mov si, di
wbloop:
    inc si
    mov al, [es:si]
    dec si
    mov [es:si], al
    cmp al, 0h
    je wbloopend
    inc si
    jmp wbloop
wbloopend:
    ret
wenter:
    ;remove spaces before newline
    dec di
    cmp byte [es:di], 0x20 ;space
    jne wenterspace
    call wbloopstart ;remove space
    jmp wenter ;check if multiple spaces
wenterspace:
    inc di
    mov al, 0xd
    call wloopstart
    ;di already increased
    mov ax, 0xe0a
    int 10h
    call wloopstart
    jmp typechar
wspecial:
    ;get special char code
    mov ax, 0xe08 ;backspace
    int 10h
    ;get charcode
    call filenum
    mov al, cl
    call wloopstart
    mov ax, 0xe08 ;backspace
    int 10h ;for cursor
    jmp typechar
wchar:
    push dx
    dec di ;else ~ will be saved
    mov al, [es:di]
    mov byte [es:di], 0h
    call wloopstart
    mov cx, si ;number of chars written in file
    call xtox
    mov ch, cl
    call xtox
    ;char press
    mov ah, 0h
    int 16h
    pop dx
    mov ah, 2h ;reset cursor
    int 10h
    jmp typechar
wcopy:
    mov ax, 0x1150
    mov gs, ax
    mov si, 0h
    cmp byte [gs:si], 0h
    jne wccopy
    mov byte [gs:si], 1h ;start copying
    inc si
    mov [gs:si], di ;location of current char
    jmp typechar
wccopy:
    mov byte [gs:si], 0h ;end of copying
    inc si
    mov bx, [gs:si] ;first limit
    mov cx, di
    cmp bx, cx
    jle wcsave
    mov ax, cx ;cx should be higher than bx
    mov cx, bx
    mov bx, ax
wcsave:
    mov al, [es:bx]
    mov byte [gs:si], al
    cmp bx, cx
    je wcsavend ;all characters copied
    inc bx
    inc si
    jmp wcsave
wcsavend:
    inc si
    mov byte [gs:si], 0h ;end of copy
    jmp typechar
wpaste:
    mov si, 1h
wcsi:
    push si
    mov al, [gs:si]
    cmp al, 0h ;end of copy
    je wpastend
    call wloopstart ;write character
    mov ax, 0xe30 ;move cursor
    int 10h
    pop si
    inc si
    jmp wcsi
wpastend:
    pop si
    jmp typechar
save:
    ;set buffer and write
    mov bx, 0x0 ;reset
    mov dl, 0x80   
    pop cx
    and cl, 0x3f ;remove high order bits
    ;set ch and dh
    call setfolder 
    mov ax, 0x301
    int 13h
saved:
    mov ax, 0xe60 ;`
    int 10h
    jmp input  

edit:
    ;edit file
    call read
    push cx ;for write save
    mov cx, bx ;for writeram
    jmp writeram
    
copy:
    ;buffer
    mov ax, 0x1200
    mov es, ax
    mov bx, 0h
    ;read
    call filenum ;filenum
    and cl, 0x3f ;remove upper bits
    push cx
    call filenum ;number of files
    mov al, cl
    mov ah, 2h 
    pop cx
    push ax
    call setfolder
    pop ax ;set ax
    push ax
    int 13h
    mov ax, 0xe77 ;w
    int 10h
    ;write
    call folder ;set dest folder
    call filenum
    and cl, 0x3f ;remove upper bits
    call setfolder
    pop ax ;same number
    inc ah
    int 13h
    jmp saved   

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

xdec:
    ;convert dec to hex
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

info: 
    ;pikobrain dir command 
    ;ouput folder number hex
    mov ax, 0x1000
    mov fs, ax
    mov si, 0xffd
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
    ;deletes folder
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
    inc bx ;next char
    cmp bx, 0x200
    jge sfile
    mov di, 0h ;reset
    jmp scomp
sfile:
    inc cl
    cmp cl, 0x40
    je input
    jmp sloop

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

assembly:
    ;read files
    ;buffer
    mov ax, 0x1200
    mov es, ax
    mov ax, 0x2200
    mov gs, ax ;gs:di writes opcodes
    mov bx, 0h
    mov di, 0h
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
    mov si, 0h ;fs:si stores labels and jmp
    push si ;store for labels
aconv:
    ;get char
    mov al, [es:bx]
    ;check char
    cmp al, 0x4d ;Mov
    je aM
    cmp al, 0x41 ;Add
    je aA
    cmp al, 0x53 ;Sub
    je aS
    cmp al, 0x54 ;Mul times
    je aaT
    cmp al, 0x44 ;Div
    je aD
    cmp al, 0x48 ;Inc high
    je aaH
    cmp al, 0x4c ;Dec less
    je aaL
    cmp al, 0x51 ;Shl q
    je aQ
    cmp al, 0x57 ;Shr w
    je aW
    cmp al, 0x5a ;rol z
    je aZ
    cmp al, 0x56 ;ror v
    je aV
    cmp al, 0x42 ;And both
    je aB
    cmp al, 0x4f ;Or
    je aO
    cmp al, 0x58 ;Xor
    je aaX
    cmp al, 0x4e ;Not
    je aN
    cmp al, 0x55 ;pUsh u
    je aU
    cmp al, 0x50 ;Pop
    je aP
    cmp al, 0x49 ;Int
    je aI
    cmp al, 0x43 ;Cmp
    je aC
    cmp al, 0x47 ;in g
    je aG
    cmp al, 0x59 ;out y
    je aY 
    cmp al, 0x4a ;Jmp
    je aJ
    cmp al, 0x46 ;Call function
    je aF
    cmp al, 0x52 ;Ret
    je aR
    cmp al, 0x2e ;. label
    je aLabel
    cmp al, 0x4b ;db kreate
    je a1bk
    cmp al, 0x45 ;End
    je aE
    cmp al, 0x65 ;end
    je asave
    cmp al, 0x3b ;; comment
    je aComment
    cmp al, 0x22 ;" print
    je aPrint
    inc bx
    jmp aconv
acend:
    inc bx
    inc di
    jmp aconv
aM:
    ;MOV
    call aloop
    ;compare dl
    cmp dl, 0x4e ;Number
    je aMN
    cmp dl, 0x52 ;Register
    je aMR
    cmp dl, 0x45 ;mov es, ax
    je aME
    cmp dl, 0x41 ;mov al, [es:bx]
    je aMA
    cmp dl, 0x53 ;mov [es:bx], al
    je aMS
    jmp aerror
aMN:
    ;MOV NUMBER
    mov dl, 0xb0 ;opcode for MN
    jmp amregstart
aMR:
    ;MOV REGISTER
    mov dh, 0x88 ;opcode for MR (or 89)
    jmp acombstart
aME:
    ;MOV ES
    sub bx, 2h ;due to aloop
    mov word [gs:di], 0xc08e
    inc di
    jmp acend
aMA:
    ;MOV ESBX
    sub bx, 2h
    mov byte [gs:di], 0x26
    inc di
    mov word [gs:di], 0x078a
    inc di
    jmp acend
aMS:
    ;MOV ESBX
    sub bx, 2h
    mov byte [gs:di], 0x26
    inc di
    mov word [gs:di], 0x0788
    inc di    
    jmp acend
aA:
    ;ADD
    call aloop
    cmp dl, 0x4e
    je aAN
    cmp dl, 0x52
    je aAR
    jmp aerror
aAN:
    ;ADD NUMBER
    mov dh, 0x80
    jmp aregstart
aAR:
    ;ADD REGISTER
    mov dh, 0x0
    jmp acombstart
aS:
    ;SUB
    call aloop
    cmp dl, 0x4e
    je aSN
    cmp dl, 0x52
    je aSR
    jmp aerror
aSN:
    mov dx, 0x80e8
    mov ch, 1h
    jmp aregstart2
aSR:
    mov dh, 0x28
    jmp acombstart
aaT:
    ;MUL
    call aloop
    mov dx, 0xf6e0
    mov ch, 3h ;no argument
    jmp aregstart2
aD:
    ;DIV
    call aloop
    mov dx, 0xf6f0
    mov ch, 3h ;no argument
    jmp aregstart2
aaH:
    ;INC
    call aloop
    mov dx, 0xfec0
    mov ch, 3h
    jmp aregstart2
aaL:
    ;DEC
    call aloop
    mov dx, 0xfec8
    mov ch, 3h
    jmp aregstart2
aQ:
    ;SHL
    call aloop
    mov dx, 0xc0e0
    mov ch, 1h
    jmp aregstart2
aW:
    ;SHR
    call aloop
    mov dx, 0xc0e8
    mov ch, 1h
    jmp aregstart2
aZ:
    ;ROL
    call aloop
    mov dx, 0xc0c0
    mov ch, 1h
    jmp aregstart2
aV:
    ;ROR
    call aloop
    mov dx, 0xc0c8
    mov ch, 1h
    jmp aregstart2
aB:
    ;AND
    call aloop
    cmp dl, 0x4e
    je aBN
    cmp dl, 0x52
    je aBR
    jmp aerror
aBN:
    mov dx, 0x80e0 ;special case
    mov ch, 1h
    jmp aregstart2
aBR:
    mov dh, 0x20
    jmp acombstart
aO:
    ;OR
    call aloop
    cmp dl, 0x4e
    je aON
    cmp dl, 0x52
    je aOR
    jmp aerror
aON:
    mov dx, 0x80c8 ;special case
    mov ch, 1h
    jmp aregstart2
aOR:
    mov dh, 0x8
    jmp acombstart
aaX:
    ;XOR
    call aloop
    cmp dl, 0x4e
    je aXN
    cmp dl, 0x52
    je aXR
    jmp aerror
aXN:
    mov dx, 0x80f3 ;special case
    mov ch, 1h
    jmp aregstart2
aXR:
    mov dh, 0x30
    jmp acombstart
aN:
    ;NOT
    call aloop
    mov dx, 0xf6d0
    mov ch, 3h
    jmp aregstart2
aC:
    ;CMP
    call aloop
    cmp dl, 0x4e
    je aCN
    cmp dl, 0x52
    je aCR
    jmp aerror
aCN:
    mov dx, 0x80f8 ;special case
    mov ch, 1h
    jmp aregstart2
aCR:
    mov dh, 0x38
    jmp acombstart
aregstart:
    mov dl, 0xc0 ;store argument register
    mov ch, 1h ;number of bytes in source
aregstart2:
    ;byte or word move?
    cmp al, 0x58 ;X
    jne areg
    inc dh ;for r16
    inc ch ;2bytes
areg:
    mov [gs:di], dh
    ;get destination
    cmp ax, 0x4158 ;AX
    je ar0
    cmp ax, 0x4148 ;AH
    je ar4
    cmp ax, 0x414c ;AL
    je ar0
    cmp ax, 0x4258 ;BX
    je ar3
    cmp ax, 0x4248 ;BH
    je ar7
    cmp ax, 0x424c ;BL
    je ar3
    cmp ax, 0x4358 ;CX
    je ar1
    cmp ax, 0x4348 ;CH
    je ar5
    cmp ax, 0x434c ;CL
    je ar1
    cmp ax, 0x4458 ;DX
    je ar2
    cmp ax, 0x4448 ;DH
    je ar6
    cmp ax, 0x444c ;DL
    je ar2
    cmp ax, 0x5358 ;SX
    je ar6
    cmp ax, 0x5458 ;TX
    je ar7
    jmp aerror
    ;set dl = register
ar7:
    inc dl
ar6:
    inc dl
ar5:
    inc dl
ar4:
    inc dl
ar3:
    inc dl
ar2:
    inc dl
ar1:
    inc dl
ar0:
    inc di
    mov [gs:di], dl ;save register
    cmp ch, 1h
    je a1b
    cmp ch, 2h
    je a2b
    jmp acend ;else back
amregstart:
    mov ch, 0h ;adds to dl depending on combination
    mov dh, 1h ;number of bytes in source
    ;byte or word move?
    cmp al, 0x58 ;X
    jne amreg
    inc dh ;2h for r16
amreg:
    ;get register
    cmp ax, 0x4158 ;AX
    je amr8
    cmp ax, 0x4148 ;AH
    je amr4
    cmp ax, 0x414c ;AL
    je amr0
    cmp ax, 0x4258 ;BX
    je amr11
    cmp ax, 0x4248 ;BH
    je amr7
    cmp ax, 0x424c ;BL
    je amr3
    cmp ax, 0x4358 ;CX
    je amr9
    cmp ax, 0x4348 ;CH
    je amr5
    cmp ax, 0x434c ;CL
    je amr1
    cmp ax, 0x4458 ;DX
    je amr10
    cmp ax, 0x4448 ;DH
    je amr6
    cmp ax, 0x444c ;DL
    je amr2
    cmp ax, 0x5358 ;SX
    je amr14
    cmp ax, 0x5458 ;TX
    je amr15
    jmp aerror ;if not found
amr15:
    inc ch
amr14:
    add ch, 3h
amr11:
    inc ch
amr10:
    inc ch
amr9:
    inc ch
amr8:
    inc ch
amr7:
    inc ch
amr6:
    inc ch
amr5:
    inc ch
amr4:
    inc ch
amr3:
    inc ch
amr2:
    inc ch
amr1:
    inc ch
amr0:
    add dl, ch ;set dl as opcode
    mov [gs:di], dl
    ;jump depending on dh (byte or word)
    cmp dh, 1h
    je a1b
    jmp a2b ;else 2 bytes
acombstart:
    mov dl, 0xc0 ;argument, for the various combinations
    mov ch, 1h ;adds to dl depending on combination
    ;byte or word move?
    cmp al, 0x58 ;X
    jne acomb
    inc dh ;for r16
    ;get combinations of registers
acomb:
    mov [gs:di], dh ;opcode for operation
acomb2: ;for second round
    ;get destination
    cmp ax, 0x4158 ;AX
    je ac0
    cmp ax, 0x4148 ;AH
    je ac4
    cmp ax, 0x414c ;AL
    je ac0
    cmp ax, 0x4258 ;BX
    je ac3
    cmp ax, 0x4248 ;BH
    je ac7
    cmp ax, 0x424c ;BL
    je ac3
    cmp ax, 0x4358 ;CX
    je ac1
    cmp ax, 0x4348 ;CH
    je ac5
    cmp ax, 0x434c ;CL
    je ac1
    cmp ax, 0x4458 ;DX
    je ac2
    cmp ax, 0x4448 ;DH
    je ac6
    cmp ax, 0x444c ;DL
    je ac2
    cmp ax, 0x5358 ;SX
    je ac6
    cmp ax, 0x5458 ;TX
    je ac7
    jmp aerror ;if not found
    ;update dl = argument
ac7:
    add dl, ch
ac6:
    add dl, ch
ac5:
    add dl, ch
ac4:
    add dl, ch
ac3:
    add dl, ch
ac2:
    add dl, ch
ac1:
    add dl, ch
ac0:
    ;check if second round through
    cmp ch, 1h
    jne acombend
    ;get source
    call askip
    ;get registor
    mov ah, [es:bx]
    inc bx
    mov al, [es:bx]
    mov ch, 8h ;new add number
    jmp acomb2
acombend:
    inc di
    mov [gs:di], dl ;enter combination
    jmp acend
aU:
    ;PUSH
    mov dl, 0x50
    jmp aUP
aP:
    mov dl, 0x58
aUP:
    inc bx
    mov al, [es:bx]
    cmp al, 0x41 ;AX
    je aU0
    cmp al, 0x42 ;BX
    je aU3
    cmp al, 0x43 ;CX
    je aU1
    cmp al, 0x44 ;DX
    je aU2
    cmp al, 0x53 ;SX (SI)
    je aU6
    cmp al, 0x54 ;TX (DI)
    jmp aerror
aU7:
    inc dl
aU6:
    add dl, 3h   
aU3:
    inc dl
aU2:
    inc dl
aU1:
    inc dl
aU0: 
    mov [gs:di], dl
    jmp acend   
aI:
    ;INT
    mov byte [gs:di], 0xcd ;int
    jmp a1b
aG:
    ;IN
    mov byte [gs:di], 0xe4
    jmp a1b
aY:
    ;OUT
    mov byte [gs:di], 0xe6
    jmp a1b
aF:
    mov byte [gs:di], 0xe8 ;call
    jmp aJMP
aR: 
    mov byte [gs:di], 0xc3 ;ret
    jmp acend
aJ:
    inc bx
    mov al, [es:bx]
    cmp al, 0x4d ;M
    je aJM
    mov byte [gs:di], 0x0f ;conditional far jump
    inc di
    cmp al, 0x45 ;Equal
    je aJE
    cmp al, 0x44 ;Different
    je aJNE
    cmp al, 0x46 ;Greater
    je aJG
    cmp al, 0x41 ;Above jge
    je aJGE
    cmp al, 0x4c ;Less
    je aJL
    cmp al, 0x45 ;Below jle
    je aJLE
    jmp aerror
aJE:
    mov byte [gs:di], 0x84
    jmp aJMP
aJNE:
    mov byte [gs:di], 0x85
    jmp aJMP
aJG:
    mov byte [gs:di], 0x8f
    jmp aJMP
aJGE:
    mov byte [gs:di], 0x8d
    jmp aJMP
aJL:
    mov byte [gs:di], 0x8c
    jmp aJMP
aJLE:
    mov byte [gs:di], 0x8e
    jmp aJMP
aJM:
    mov byte [gs:di], 0xe9 ;jmp
aJMP:
    call askip
    mov ax, 0x3200 ;fs:si stores jmp labels
    mov fs, ax
    inc di ;where it will be written
    mov ax, di
    inc di ;to be correct later
    mov [fs:si], ah ;store bin location
    inc si
    mov [fs:si], al 
    inc si   
aJMl:
    mov al, [es:bx]
    mov [fs:si], al
    cmp al, 0x2e ;.
    je aJMlend
    inc si
    inc bx
    jmp aJMl
aJMlend:
    inc si
    jmp acend
aLabel:
    mov ax, 0x4200 ;fs:si stores jmp labels
    mov fs, ax
    mov dx, si ;store for later
    pop si
    mov cx, di ;store for later
    inc bx ;get passed .
aLabell:
    mov al, [es:bx] ;current char
    mov [fs:si], al ;store
    cmp byte [es:bx], 0x2e ;. ;end of label name
    je aLabelend
    inc si
    inc bx
    jmp aLabell
aLabelend:
    inc si
    mov [fs:si], ch
    inc si
    mov [fs:si], cl
    inc si
    push si
    mov si, dx ;return to normal
    inc bx
    jmp aconv 
aE:
    mov dword [gs:di], 0x16cd00b4
    add di, 4h
    mov byte [gs:di], 0xea ;jmp seg:off
    inc di
    mov dword [gs:di], 0x10200000
    add di, 3h
    jmp acend
aComment:
    inc bx
    cmp byte [es:bx], 0xd ;newline = end of comment
    jne aComment
    inc bx ;this is a real paradox, save space or time? Einstein: "Spacetime"
    jmp aconv
aPrint:
    mov word [gs:di], 0x0eb4 ;mov ah, 0xe
    inc di
aPloop: 
    inc bx
    mov ah, [es:bx]
    cmp ah, 0x22 ;" end of string
    je acend
    mov al, 0xb0 ;mov al
    inc di
    mov [gs:di], ax ;mov al, <>
    add di, 2h
    mov word [gs:di], 0x10cd ;int 10h
    inc di
    jmp aPloop
askip:
    ;skip whitespace
    inc bx
    mov al, [es:bx]
    cmp al, 0xd
    je askip
    cmp al, 0xa
    je askip
    cmp al, 0x20
    je askip
    ret
aloop:
    ;get args
    inc bx
    mov dl, [es:bx] ;store for cmp
    call askip
    ;get two chars, register
    mov ah, [es:bx]
    inc bx
    mov al, [es:bx] ;store ax
    ret
agetbyte:
    ;get 1 byte
    call askip
    mov al, [es:bx]
    call atohex
    mov ah, al
    shl ah, 4h ;move to upper nibble
    inc bx
    mov al, [es:bx]
    call atohex
    add al, ah ;put ah nibble into al
    ret
a4b:
    ;get 4 bytes
    call agetbyte
    inc di
    mov [gs:di], al
    call agetbyte
    inc di
    mov [gs:di], al
a2b:
    ;get 2 bytes
    call agetbyte
    inc di
    mov [gs:di], al
a1b:
    inc di
a1bk:
    ;get 1 bytes
    call agetbyte
    mov [gs:di], al ;place opcode in memory
    jmp acend
aerror:
    call enter
    mov ch, bh
    call xtox
    mov ch, bl
    call xtox
    mov ax, 0xe65 ;e
    int 10h
    ;will still save
asave:
    mov ax, 0x3200
    mov fs, ax
    mov word [fs:si], 0h ;end of list
    mov ax, 0x4200
    mov fs, ax
    pop si
    mov byte [fs:si], 0h ;end of list
    mov es, ax ;label list
    mov bx, 0h
    mov ax, 0x3200 ;jmp list
    mov fs, ax
    mov si, 0h
asaveloop:
    mov ch, [fs:si] ;jmp location, cannot be 0000
    inc si
    mov cl, [fs:si]
    cmp cx, 0h ;end of list
    je awrite
    inc si
ascomp:
    push si ;store so it can loop from same place
ascloop:
    ;compare labels
    mov al, [fs:si]
    cmp al, [es:bx]
    jne ascompend
    cmp al, 0x2e ;.
    je ascompeq
    inc si
    inc bx
    jmp ascloop
ascompend:
    ;jump past label
    cmp byte [es:bx], 0x2e
    je ascend
    cmp byte [es:bx], 0x0 ;label not found
    je alerror
    inc bx
    jmp ascompend
ascend:
    pop si
    add bx, 3h ;es:bx on dot, must jump past location value
    jmp ascomp
ascompeq:
    inc bx
    mov dh, [es:bx] ;label location
    inc bx
    mov dl, [es:bx]
    sub dx, cx ;calculate jump length
    sub dx, 2h ;remove yet 2 because of how jumps apparently work
    mov bx, cx
    mov [gs:bx], dl ;store jump length, must use bx
    inc bx
    mov [gs:bx], dh ;NOTICE reversed order - stupid assembly
    ;set values
    pop ax ;take down si
    inc si
    mov bx, 0h
    jmp asaveloop
alerror:
    ;label error
    pop si ;take down
    mov ax, 0xe65 ;e
    int 10h
awrite:
    mov ax, 0xe61 ;Assembled
    int 10h
    mov ax, 0x2200
    mov es, ax
    mov bx, 0h
    ;destination file
    call filenum
    and cl, 0x3f
    call setfolder
    mov ax, di ;calculate number of files to save: di//0x200
    shr ax, 8h
    mov dl, 0x2
    div dl
    mov ah, 3h
    inc al
    mov dl, 80h
    int 13h
    call enter
    jmp input

program:
    ;read files
    ;buffer
    mov ax, 0x1200
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
    and cl, 0x3f
    ;folder
    call setfolder
    mov ah, 2h
    mov al, dl
    mov dl, 0x80 ;drive
    int 13h ;read
    jmp 0x1200:0x0
    
    times 171 db 0
    db 0h ;upper 2 bits cl -- track
    dw 0h ;0x1000:0xfff -- hd head/track

;nasm -f bin -o myfirst.bin myfirst.asm
;dd status=noxfer conv=notrunc if=myfirst.bin of=myfirst.flp
