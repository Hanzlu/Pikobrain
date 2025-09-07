	BITS 16

;***********
;BOOTLOADER
;***********

;constants instead of magic numbers
OS_SECTORS equ 0x20c ;size of OS in sectors, 2 is for int 13h (read)

RANDOM_BUFFER equ 0x1180
SEARCH_BUFFER equ 0x1181
REPLACE_BUFFER equ 0x1189
COPY_BUFFER equ 0x1190

jmp bootloader

    ;"help file" list of commands
    db "Pikobrain v1.7.1", 0xd, 0xa
    db "new, enter, back", 0xd, 0xa
    db "time", 0xd, 0xa
    db "memory [fi]", 0xd, 0xa
    db "write [fi]", 0xd, 0xa
    db "edit [fi][2h]", 0xd, 0xa
    db "delete [fi][2h]", 0xd, 0xa
    db "link [fi][fi][2h]", 0xd, 0xa
    db "copy [fi][2h]w[fo][fi]", 0xd, 0xa
    db "jump [1h][fi][2h]w[fo][fi]", 0xd, 0xa
    db "kalc [4h][4h][1h]", 0xd, 0xa
    db "Kagain [4h][1h]", 0xd, 0xa
    db "hex [4h]", 0xd, 0xa
    db "xdex [5d]", 0xd, 0xa
    db ".float [4h]", 0xd, 0xa
    db "folder [fo]", 0xd, 0xa
    db "search [str]", 0xd, 0xa
    db "info", 0xd, 0xa
    db "os", 0xd, 0xa
    db "assembly [fi][2h]a[fi]", 0xd, 0xa
    db "run [fi][2h]"

bootloader:
    ;set up registers
    mov ax, 0x7c0
    mov ds, ax ;data segment
    mov ax, 0xa00
    mov ss, ax ;stack segment
    mov sp, 0x1000 ;stack pointer

    ;redirect ctrl+break handler
    xor ax, ax
    mov es, ax
    mov bx, 0x6c ;location in Interrup Vector Table
    mov word [es:bx], CTRL_BREAK ;location of handler in code
    add bx, 2h
    mov word [es:bx], 0x1000

    ;mask PIT interrupt
    in al, 21h
    or al, 1h
    out 21h, al

    ;read OS files into RAM
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ax, OS_SECTORS ;files to read
    mov cx, 1h
    mov dh, 0h ;dl set at boot
    int 13h
    cmp ah, 0h ;if error stop
    jne $

    ;check if install has been made
    mov bx, 0x1fd           ;location of variable
    cmp byte [es:bx], 0h    ;if installed: jump to OS
    jne jmppb
    mov byte [es:bx], 1h    ;else: mark as installed, and install

    ;set destination drive for install
    shr dl, 7h
    or dl, 0x80 ;0->80, 80->81 bitwise math

    ;write files to hard drive
    xor bx, bx
    mov ah, 3h ;use same values as previous int 13h
    int 13h
    cmp ah, 0h ;if error stop
    jne $

jmppb:
    jmp 0x1000:0x0200 ;jump to Pikobrain main

    ;fill up space
    times 506-($-$$) db 0h

    ;folder number
    db 0h ;upper 2 bits cl -- track
    dw 0h ;0x1000:last_byte

    db 0h ;0=installation=false, 1=installation=true
    dw 0xaa55


;**********
;PIKOBRAIN
;**********

    ;setup copy buffer
    mov ax, COPY_BUFFER
    mov es, ax
    xor bx, bx
    mov byte [es:bx], 0h

callnew:
    call new  ;call function, jump to main loop
    jmp input ;-->
new:
    ;clear screen
    pusha
    ;set graphics mode
    mov ax, 3h ;80x25 16 color text
    int 10h
    ;popa ;UNCOMMENT
    ;ret  ;FOR QEMU
    ;set color and clear screen
    mov ax, 0x600
    mov bh, 0x3e ;cyan-yellow <-- change this value to change colors in Pikobrain
    xor cx, cx
    mov dx, 0x184f ;size of screen 25x80
    int 10h
    popa
    ret


;**********
;FUNCTIONS
;**********
;common functions
;some used as macros in pikoasm

;wait for and return keypress
;int 16h is a CPU-consuming polling method
;hlt is used to give the CPU some rest
keyget:
    ;sleep CPU until PIT interrupt (18Hz), which is auto enabled by BIOS
    hlt
    mov ah, 1h ;check if key press
    int 16h
    je keyget ;if no key press loop hlt again
    ;use int 16h to read and update the keyboard buffer
    mov ah, 0h
    int 16h
    ret

callenter:
    call enter
    jmp input
enter:
    ;print enter char
    mov ax, 0xe0d
    int 10h
    mov al, 0xa
    int 10h
    ret

readfile:
    ;reads one file
    mov ax, 0x1200
    mov es, ax
    xor bx, bx
    call filenum ;number of file
    call setfolder
    mov ax, 0x201 ;read one file
    int 13h
    ret

readfiles:
    ;read multiple files
    mov ax, 0x1200
    mov es, ax
    xor bx, bx
readfiles2: ;used by link
    push bx
    call filenum ;first file
    push cx ;store number
    call filenum ;number of files
    mov bl, cl ;store for al
    pop cx
    call setfolder
    mov al, bl
    mov ah, 2h
    pop bx
    push ax ;IBM BIOS "bug"
    int 13h ;read
    pop ax
    ret

xtox:
    ;output ch as 2 digit hex number
    mov al, ch
    and al, 0xf ;clear upper nibble, to get second digit only
    call xtoasc
    mov ah, al ;store
    mov al, ch
    shr al, 4h ;get upper nibble, to get first digit only
    call xtoasc
    mov ch, ah ;store
    ;output two numbers
    mov ah, 0xe
    int 10h
    mov al, ch
    int 10h
    ret

;the next two convert between ascii-chars and numerical values
;such as F=46h <-> 0xf
atohex:
    ;ascii-hex to hex
    sub al, 30h
    cmp al, 9h
    jle athback
    sub al, 7h ;if letter
athback:
    ret

xtoasc:
    ;hex to ascii-hex
    add al, 30h
    cmp al, 39h
    jle xtaback
    add al, 7h ;if letter
xtaback:
    ret

filenum:
    ;get 2 digit hex num input
    ;converts and into cl
    call keyget
    cmp al, 0x8 ;backspace = cancel
    je filenquit
    mov ah, 0xe ;output
    int 10h
    call atohex
    mov cl, al
    shl cl, 4h ;*16, store in upper nibble
    call keyget
    cmp al, 0x8 ;backspace = cancel
    je filenquit
    mov ah, 0xe
    int 10h
    call atohex
    add cl, al ;lower nibble
    ret
filenquit:
    ;exit writing, clear stack, go to input
    mov sp, 0x1000
    jmp input ;if a pikoasm program gets here it will terminate

setfolder:
    ;set folder to current folder number, for int 13h
    ;folder number stored in the end of the bootloader code
    and cl, 0x3f ;clear upper bits, cl is file number
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x1fa ;folder number location
    mov al, [fs:si]
    shl al, 6h ;into right position
    add cl, al
    inc si
    mov dh, [fs:si] ;set values
    inc si
    mov ch, [fs:si]
    mov dl, 0x80
    ret

callfolder:
    call folder
    jmp input
folder:
    ;change (head and track i.e.) folder number
    ;dh and ch (cl) for int 13h
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x1fc ;last number in folder number
    call filenum
    cmp cl, 0x69 ;double press tab to select current folder
    je fsame
    cmp cl, 0x44 ;double semi-colon to only enter last two digits
    je flast
    cmp cl, 0x41 ;double press h to select home folder (000000)
    je fhome
    and cl, 3h ;clear bits
    push cx
    call filenum
    push cx
    call filenum ;i.e. 6 digits total
    ;write values, to change folder number
    mov [fs:si], cl
    dec si
    pop cx
    mov [fs:si], cl
    dec si
    pop cx
    mov [fs:si], cl
    ret
fhome:
    ;set folder number to 000000
    dec si
    mov word [fs:si], 0h
    dec si
    mov byte [fs:si], 0h
    ret
flast:
    ;only change last two digits of folder number
    call filenum
    mov [fs:si], cl
fsame: ;use current folder number
    ret

random:
    ;random number generator
    push cx ;store for assembly macros
    push dx
    mov ah, 0h ;get tick
    int 1ah
    mov ax, RANDOM_BUFFER
    mov fs, ax
    xor si, si
    mov ax, [fs:si]
    sub ah, dl ;update number = generate
    sub al, ah ;al is random number returned
    rol ax, 1h
    mov [fs:si], ax ;store
    pop dx
    pop cx
    ret

sget:
    ;get string input
    mov ax, SEARCH_BUFFER
    mov gs, ax
    xor di, di ;gs:di search word
sword:
    ;get char
    call keyget
    cmp ah, 0x3b ;f1, quit writing, for use of old string input
    je send
    cmp al, 0x1b ;esc, quit writing, must be checked afterwards (by wreplace)
    je send
    cmp al, 8h ;backspace
    jne swordcon
    dec di
    mov ah, 0xe ;print backspace
    int 10h
    ;overwrite old char
    xor bx, bx
    mov ax, 0xa20 ;space
    mov cx, 1h
    int 10h
    jmp sword
swordcon:
    mov [gs:di], al ;store char in buffer
    ;if enter: end
    cmp al, 0xd ;if enter, end writing
    je send
    ;output
    mov ah, 0xe ;output char
    int 10h
    inc di
    jmp sword
send:
    xor di, di
    ret

;******
;INPUT
;******
;main loop

input:
    ;get commands
    call keyget
    mov bh, 0h ;graphics reason

    cmp al, 0x6e ;n
    je callnew
    cmp al, 0xd  ;enter
    je callenter
    cmp al, 0x62 ;b
    je callback
    cmp al, 0x74 ;t
    je time
    cmp al, 0x6d ;m
    je memory
    cmp al, 0x77 ;w
    je write
    cmp al, 0x65 ;e
    je edit
    cmp al, 0x64 ;d
    je delete
    cmp al, 0x6c ;l
    je link
    cmp al, 0x63 ;c
    je copystart
    cmp al, 0x6a ;j
    je jump
    cmp al, 0x6b ;k
    je kalc
    cmp al, 0x4b ;K
    je kagain
    cmp al, 0x68 ;h
    je hex
    cmp al, 0x78 ;x
    je xdec
    cmp al, 0x2e ;.
    je real
    cmp al, 0x66 ;f
    je callfolder
    cmp al, 0x69 ;i
    je info
    cmp al, 0x73 ;s
    je search
    cmp al, 0x6f ;o
    je os
    cmp al, 0x61 ;a
    je assembly
    cmp al, 0x72 ;r
    je run

    ;else check arrows
arrow:
    mov al, ah
    ;get cursor location
    mov ah, 3h
    int 10h
    cmp al, 0x48 ;up
    je arrowup
    cmp al, 0x50 ;down
    je arrowdown
    cmp al, 0x4b ;left
    je arrowleft
    cmp al, 0x4d ;right
    je arrowright
    jmp input
arrowup:
    dec dh
    jmp arrowend
arrowdown:
    inc dh
    jmp arrowend
arrowleft:
    dec dl
    jmp arrowend
arrowright:
    inc dl
arrowend:
    mov ah, 2h ;update cursor
    int 10h
    jmp input

callback:
    call back
    jmp input
back:
    ;move cursor to top left
    mov bh, 0h
    mov ah, 2h
    xor dx, dx
    int 10h
    ret


;*********
;COMMANDS
;*********
;'programs'

time:
    ;get date
    ;convert to decimal
    mov ah, 4h
    int 1ah
    call xtox
    mov ch, cl
    call xtox
    mov al, 0x2f ;/
    int 10h
    mov ch, dh
    call xtox
    mov al, 0x2f ;/
    int 10h
    mov ch, dl
    call xtox
    mov al, 0x20 ;space
    int 10h
    ;get time
    ;convert to decimal
    mov ah, 2h
    int 1ah
    call xtox
    mov al, 0x3a ;:
    int 10h
    mov ch, cl
    call xtox
    mov al, 0x3a ;:
    int 10h
    mov ch, dh
    call xtox
    jmp input

memory:
    ;read file in hex and ascii
    ;in mfun there is functionality
    ;first half of the file is read, and functionality mode is entered
    call readfile
    push cx ;store file number
    mov si, 0h ;due to mmark 00 is marked by default
mnew: ;used when a new half is displayed
    call new
    mov ch, bh ;output page
    call xtox
    mov ax, si ;output si
    mov ch, al
    call xtox
mrow:
    call enter
    mov dh, 0h ;column counter
    mov ch, bl ;print row index
    call xtox
    mov al, 0x3a ;:
    int 10h
mbyte:
    mov ch, [es:bx] ;get content of byte
    mov ax, si
    cmp ch, al ;mark the si opcode (now in al)
    je mmark
    call xtox ;else output as hex
mcon:
    mov al, 0x20 ;space
    int 10h
    inc bx
    inc dh
    cmp dh, 0x10 ;width of content
    jne mbyte
    ;output row as ascii
    mov di, bx
    sub bx, 0x10
mascii:
    mov al, [es:bx]
    ;check if special char
    cmp al, 0xf
    ja macon
    mov al, 0x2a ;* since some chars are problematic
macon:
    int 10h ;write char
    inc bx
    cmp bx, di ;end of row
    jne mascii
    cmp bl, 0h ;enter functionality mode when a half of the file is displayed
    je mfun
    jmp mrow
mmark:
    mov ax, 0x0e2e ;.. to mark si value
    int 10h
    int 10h
    jmp mcon
mfun:
    ;this provides functionality for the program
    mov di, bx ;es:di used as pointer while bh used for cursor
    sub di, 0x100 ;since it has read the whole half
    mov bh, 0h
    mov ah, 2h
    mov dx, 0x0103 ;move cursor to first opcode
    int 10h
minput:
    mov ah, 3h ;get cursor location
    int 10h
    mov cx, di ;used by arrows; cx changed by 3h
    call keyget
    cmp ah, 0x48 ;up
    je mup
    cmp ah, 0x50 ;down
    je mdown
    cmp ah, 0x4b ;left
    je mleft
    cmp ah, 0x4d ;right
    je mright
    cmp al, 0x9 ;tab, switch page
    je mpage
    cmp ah, 0xf ;shifted tab, select marked opcode
    je mfmark
    cmp al, 0x7e ;~ write new opcode
    je mwrite
    cmp al, 0x60 ;` save
    je msave
    cmp al, 0x1b ;esc cancel
    je input
    jmp minput
mup:
    ;cx equals di
    cmp cl, 0x10
    jb minput
    sub di, 0x10
    mov ah, 2h ;move cursor up
    dec dh
    int 10h
    jmp minput
mdown:
    cmp cl, 0xef
    ja minput
    add di, 0x10
    mov ah, 2h
    inc dh
    int 10h
    jmp minput
mleft:
    cmp cl, 0h
    je minput
    dec di
    mov ah, 2h
    and cl, 0xf ;if 0
    je mleftrow
    sub dl, 3h
    jmp mleftend
mleftrow:
    dec dh
    add dl, 0x2d ;last opcode in row
mleftend:
    int 10h
    jmp minput
mright:
    cmp cl, 0xff
    je minput
    inc di
    mov ah, 2h
    and cl, 0xf
    cmp cl, 0xf
    je mrightrow
    add dl, 3h
    jmp mleftend
mrightrow:
    inc dh
    mov dl, 3h ;first opcode in row
    jmp mleftend
mpage:
    mov bx, di
    xor bh, 1h ;switches
    mov bl, 0h
    jmp mnew
mfmark:
    call filenum
    mov ch, 0h
    mov si, cx
    mov bx, di
    mov bl, 0h
    jmp mnew
mwrite:
    call filenum ;value is written to the screen
    mov [es:di], cl ;enter new value into memory
    mov al, cl ;used for interrupt
    ;write the new char in ascii column
    push dx ;current cursor location
    mov ah, 2h
    mov dl, 0x33 ;location of first ascii representation in row
    mov cx, di
    and cl, 0xf
    add dl, cl ;location of char to be edited
    int 10h
    mov ah, 0xe ;write char already in al
    int 10h
    mov ah, 2h ;restore cursor location
    pop dx
    int 10h
    mov cx, di
    jmp mright
msave:
    xor bx, bx
    pop cx
    call setfolder
    mov ax, 0x301
    int 13h
    jmp input

;TEXT EDITOR
;registor use:
;ax, general purpose
;bx, gp. or index, bh=0h for some int10h
;cx, gp. but passed to readloop as read-until-index
;dx, gp. but often needed for location of cursor
;si, first-char-on-screen-index for scrolling
;di, buffer-index
;stack use:
;cx, <number of files><filenum of first file> (after last int13h read)

;start writing in existing file
edit:
    call readfiles
editreload: ;wreload enters here
    mov ch, al ;number of files
    push cx ;cx stores number of files & file number
    mov bl, al ;al=number of files
    shl bx, 9h ;*200h-> buffer size in bytes
    mov byte [es:bx], 0h ;mark end of buffer, due to full files
    call new ;might be used by others
    xor si, si ;index of character in top-left of screen
    xor di, di ;es:di is buffer index
    jmp wcontinue ;fill first full screen

;read from [es:bx] until bx=cx or [es:bx]=0h
;WARNING di may not change in read
readloop:
    mov dl, 0h
    call writeline ;bx stands after the line's last char, except for 0h
    cmp bx, cx   ;also needed here if cx is last char
    je wcontinue ;and we want to go to wcontinue
    cmp byte [es:bx], 0h ;endfile
    je editjoin ;go to editor
    ;inc bx
    inc dh ;this is kept <0x19 by readsi! WARNING
    cmp dh, 0x18 ;if screen is scrolled
    ja readsi    ;update si
    jmp readloop
writeline:
    ;writes the text of a line and fills it
    cmp bx, di ;if di is inside of the word moved by wnlreverse gs is updated
    jne wllskip
    mov gs, dx ;store new cursor location if di inside of the moved word
wllskip:
    cmp bx, cx ;cx used by some editor functions to update screen from si until di
    je writend ;necessary to ret, and then it will goto wcontinue
    mov al, [es:bx]
    cmp al, 0h ;eof should not cause a newline fill
    je writend
    cmp al, 0xd ;enter with 0xd 0xa
    je writenld
    cmp al, 0xa ;enter with 0xa only
    je writenl
    cmp dl, 0x4e ;end of allowed space on line
    je writenl
    mov ah, 0xe ;write character
    int 10h
    inc bx ;next char
    inc dl ;cursor is moved
    jmp writeline
writenld:
    ;assumes a 0xa follows
    inc bx
    mov al, [es:bx]
writenl:
    cmp al, 0xa ;newline
    je wnlfill
    cmp al, 0x20 ;space
    je wnlspace
    ;else it's a character
    ;move the word to next line
wnlreverse:
    ;reverse until a space
    dec bx
    dec dl
    cmp byte [es:bx], 0x20 ;find a space
    jne wnlreverse
    ;when a space is found
    push bx
    mov ah, 2h ;set cursor position
    mov bh, 0h ;don't replace this with print, dumbo
    inc dl ;to not overwrite space
    int 10h
    pop bx
    jmp wnlfill
wnlspace:
    ;if a space on column 0x4e
    mov ah, 0xe ;write it
    int 10h
    inc dl
    ;jmp rnlfill
wnlfill:
    ;fill rest of line with null-characters and cause newline
    mov ax, 0xe00
    int 10h
    inc dl
    cmp dl, 0x50
    jne wnlfill
    inc bx ;go beyond the last char of line; except for 0h
writend:
    ret ;line is now filled
;move si pointer to next line
readsi:
    call rsinext
    mov dh, 0x18 ;WARNING must point to correct line
    jmp readloop
rsinext:
    mov ah, 0h ;cursor counter
rsiloop:
    ;search for first character of next line
    mov al, [es:si]
    cmp al, 0xd ;cannot be ignored due to 0xd on 0x4e
    je rsid
    cmp al, 0xa
    je rsiend
    cmp ah, 0x4e
    je rsifull
    inc ah
rsid: ;0xd is ignored but increases si
    inc si
    jmp rsiloop
rsifull:
    cmp al, 0x20 ;space is allowed
    jne rsimove
    inc si ;if space: the next char is first on next line
    ret
rsimove:
    ;reverse until a space
    dec si
    dec ah
    cmp byte [es:si], 0x20 ;find a space
    jne rsimove
    ;when a space is found
    inc si ;the next char is first on next line
    ret
rsiend:
    inc si ;if 0xa, next char is first on next line
    ret
;move si pointer to previous line
rsiback:
    ;WARNING no check for si being 0h
    mov ah, 0x4e ;cursor counter
    dec si
    mov al, [es:si]
    cmp al, 0x20 ;only space allowed on 0x4e
    je rsbspace
    dec ah ;otherwise at most 0x4d
rsbspace:
    cmp al, 0xa ;needs to go beyond newline
    jne rsbloop
    dec si
rsbloop:
    ;search for start of previous line
    cmp si, 0h ;start of file
    je rsbend
    cmp byte [es:si], 0xa ;newline
    je rsbenda
    cmp ah, 0h ;should be after 0xa check
    je rsbfull
    dec si
    dec ah
    jmp rsbloop
rsbfull:
    ;line could be entirely filled
    ;this only allowed if [si-1] in [0xa, 0x20]
    dec si
    mov al, [es:si]
    cmp al, 0xa
    je rsbenda
    cmp al, 0x20
    je rsbenda
wsbfloop:
    ;else go beyond next space
    inc si
    cmp byte [es:si], 0x20
    jne wsbfloop
rsbenda:
    inc si ;beyond 0xa or 0x20
rsbend:
    ret

;start writing in empty file
write:
    mov ax, 0x1200
    mov es, ax
    call filenum
    mov ch, 0h
    push cx ;num of files & filenum
    call new
    xor si, si ;top-left char index
    xor bx, bx ;reading pointer
    mov byte [es:bx], 0h ;mark last char
editjoin:
    ;edit enters here
    mov di, bx ;di is used as pointer
;main editor loop
editor:
    ;get cursor location for dx, used by some special keys etc.
    mov bh, 0h
    mov ah, 3h
    int 10h
    ;read char
    call keyget
    ;WARNING don't print chars before weolnot
    ;WARNING don't make ah=0xe as preparation
        ;as there are 'cmp ah's below
    ;check if special key
    cmp al, 8h ;backspace; cannot be under the eol checks due to 0x4e
    je werase
    cmp al, 0x60 ;` save
    je wsave
    cmp al, 0x1b ;esc cancel
    je wexit
    cmp al, 0x7e ;~ special char
    je wspecial
    cmp al, 0x5c ;\ char count
    je wchar
    ;these are not printed
    cmp ah, 0x4b ;left arrow
    je wleft
    cmp ah, 0x48 ;up arrow
    je wup
    cmp ah, 0x47 ;home
    je whome
    cmp ah, 0x4d ;right arrow
    je wcallright
    cmp ah, 0x50 ;down arrow
    je wcalldown
    cmp ah, 0x4f ;end
    je wend
    cmp ah, 0x49 ;page up
    je wpgup
    cmp ah, 0x51 ;page down
    je wpgdown
    cmp ah, 0x52 ;ins
    je wins
    cmp ah, 0x53 ;del
    je wdel
    cmp al, 0xd ;enter
    je wenter
    cmp al, 0x9 ;tab (circle)
    je wcallcopy
    cmp ah, 0xf ;shifted tab (cut)
    je wcallcopy
    cmp al, 0x7c ;| paste
    je wpaste
    cmp ah, 0x3b ;f1
    je wcallfind
    cmp ah, 0x3c ;f2
    je wfnext
    cmp ah, 0x3d ;f3
    je wreplace
    cmp ah, 0x3e ;f4
    je wascii
    cmp ah, 0x3f ;f5
    je wsave
    cmp ah, 0x40 ;f6
    je wreload
    cmp ah, 0x41 ;f7
    je wgoto
    ;end of line writing check
    cmp dl, 0x4e ;only space allowed there
    jb weolnot
    cmp al, 0x20 ;only space
    jne weolnl
    inc dl ;cursor is moved later
weolnot:
    ;output char
    mov ah, 0xe
    int 10h
    ;second end of line check, when space gets here
    ;these things are needed for end of line writing
    cmp dl, 0x4f
    jne weolskip
    ;if space on dl=4e:
    cmp dh, 0x18 ;if space on last line
    jne weolslast
    call rsinext ;move si only on last line
weolslast:
    call wnlfill ;if space, cause newline
    mov al, 0x20 ;reset to space, so that it is waddchar-ed
    jmp weolskip
weolnl:
    ;the word must be moved
    push ax ;al char, WARNING popped after ca 20 lines
    cmp dh, 0x18
    jne weolnlskip
    call rsinext ;if last line, move si
weolnlskip:
    mov bx, di
    call wnlreverse ;reverse until space, bx will be beyond space
    mov ah, 0xe
weolwrite:
    ;rewrite the moved word
    cmp bx, di
    je weolwend
    mov al, [es:bx]
    int 10h
    inc bx
    jmp weolwrite
weolwend:
    ;write the new char
    pop ax
    mov ah, 0xe ;write char
    int 10h
weolskip: ;used by wspecial
    call waddchar ;add char to buffer
;update and continue
wcontinue:
    mov bh, 0h
    mov ah, 3h ;read cursor location
    int 10h
    call wupdate
    ;clear screen from cursor location, needed for: wpgdown,werase,wcallcopy
    ;calculate number of chars for the rest of screen
    mov cx, 0x50 ;width of screen
    sub cl, dl
    mov al, 0x50
    mov ah, 0x18 ;height of screen
    sub ah, dh
    mul ah
    add cx, ax
    mov bh, 0h
    mov ax, 0xa00 ;null char is used
    int 10h
    ;reset cursor (bugcheck bh=0)
    mov ah, 2h
    mov dx, gs ;gs can change when cursor moves with word
    int 10h
    jmp editor
;internal organs
wupdate:
    ;update screen from di
    mov bx, di
    mov gs, dx ;return location of cursor in wcontinue
    mov cx, 0xffff ;read-until index for writeline
wuloop:
    ;WARNING si, and cx must not change unexpectedly
    cmp dh, 0x18 ;last line
    je wulast
    call writeline ;update line
    cmp byte [es:bx], 0h ;end of file, [] due to same 0h output in al
    je wulast
    inc dh
    mov dl, 0h ;WARNING make sure this solved the old add dx, 0xb0
    jmp wuloop
wulast:
    cmp bx, di ;needs to be here if a word is moved from line 17 to 18
    jne wulskip
    mov gs, dx ;store new cursor location if di inside of the moved word
wulskip:
    mov al, [es:bx]
    cmp al, 0h ;endfile
    je wuend
    cmp al, 0xd ;enter with 0xd 0xa
    je wuend
    cmp al, 0xa ;enter with 0xa only
    je wuend
    cmp dl, 0x4e ;end of allowed space on line
    je wuline
    mov ah, 0xe ;else write character
    int 10h
    inc bx ;next char
    inc dl ;cursor is moved
    jmp wulast
wuline:
    cmp al, 0x20 ;only space is allowed on 0x4e
    jne wuend
    mov ah, 0xe ;write space
    int 10h
    inc dl
    ;jmp wuend
wuend:
    ;fill rest of line, except last cell, with null
    cmp dl, 0x4f ;otherwise scroll
    je wupdatend
    mov ax, 0xe00
    int 10h
    inc dl
    jmp wuend
wupdatend:
    ret
waddchar:
    mov bx, di ;pointer
waddloop:
    ;add char to buffer
    mov ah, [es:bx]  ;get current char
    mov [es:bx], al  ;place new char (the typed one)
    mov al, ah       ;store the old char as the "new char"
    inc bx
    cmp al, 0h ;check if file end
    jne waddloop
    inc di ;update di
    mov byte [es:bx], 0h ;double mark end of file
    ret
wsubchar:
    ;di stands on char to be erased
    mov bx, di
wsubloop:
    ;erase character from buffer
    inc bx
    mov al, [es:bx] ;get next character
    dec bx
    mov [es:bx], al ;move it to current byte
    cmp al, 0h      ;check if file end
    je wsublend
    inc bx          ;go to next byte
    jmp wsubloop
wsublend:
    ret
;sepecial chars
;cursor movements
werase:
    cmp dx, 0h ;if top-left
    je editor  ;do nothing
    mov ah, 0xe
    int 10h ;print backspace
    mov ax, 0xa00 ;overwrite the old char
    mov cx, 1h
    int 10h
    dec di
    mov cl, [es:di] ;store (0xa)
    call wsubchar ;remove char
    cmp dl, 0h
    jne wcontinue
    ;if newline erase
    dec di
    cmp byte [es:di], 0xd
    jne werased
    call wsubchar ;remove 0xd also
    jmp wenlback ;do not increase di
werased:
    inc di
wenlback: ;used by wleft
    ;move cursor to previous line
    mov bh, 0h
    mov ah, 2h
    dec dh
    mov dl, 0x4f ;end of row
    int 10h
weback:
    ;reverse until no longer null
    cmp dl, 0h ;must be here
    je werasend
    dec dl
    mov ax, 0xe08 ;write backspace to reverse
    int 10h
    mov ah, 8h ;read char at cursor
    int 10h
    cmp al, 0h
    je weback
    ;if char is found
    cmp cl, 0xa ;only increase if newline
    jne werasend
    inc dl ;place cursor after char
werasend:
    mov ah, 2h ;set cursor position
    int 10h
    jmp wcontinue
wleft:
    ;move move cursor one step left
    cmp dx, 0h ;top-left do nothing
    je editor
    dec di
    cmp dl, 0h ;beginning of line
    je wleftnl
    mov ax, 0xe08 ;backspace
    int 10h
    jmp wcontinue
wleftnl:
    mov cl, [es:di] ;WARNING necessary for wback that cl be 0xa if nl
    dec di
    cmp byte [es:di], 0xd ;if newline move two steps left
    je wenlback
    inc di ;if !nl, back only 2 steps (-3+1)
    jmp wenlback
wup:
    ;move to end of the line above
    mov bl, dl ;bh = 0
    sub di, bx ;move di to start of line
    mov ah, 2h
    mov dl, 0h ;move cursor to start of line
    int 10h
    jmp wleft
whome:
    ;move cursor to top left of screen
    call back ;move cursor to top left
    mov di, si ;set to first char on screen
    jmp wcontinue
wcallright:
    call wright
    jmp editor
wright:
    ;move cursor to next char
    ;WARNING bh is assumed to be 0h
    mov bl, 0h ;changed to 20h, to mark space-caused nl
    cmp dx, 0x184e ;don't allow cursor to go right of this
    je wrightend
    mov cx, [es:di] ;store
    cmp cl, 0h ;eof do nothing
    je wrightend
    mov ah, 8h ;read char at cursor
    int 10h
    cmp al, 0h ;end of line 0xd/0xa (use this!)
    je wrightnl
    inc di ;this used to be before read char at cursor -> bug
    mov ah, 0xe ;print cl char
    mov al, cl
    int 10h ;move cursor right
    inc dl ;needs to be correct
    ;if ([di] == 0x20 && dl == 0x4f OR [di] == 0x20 && [dl+1]' == 0h && [di+1] not in [0xd, 0xa]): do a newline
    cmp cl, 0x20  ;only space can demand a nl
    jne wrightend ;else simple move
    cmp dl, 0x4f    ;SPECIAL: if line is full because of space, do a newline
    je wrspacenl
    mov ah, 8h ;read char at cursor
    int 10h
    cmp al, 0h    ;end of line
    jne wrightend ;else simple move
    cmp ch, 0xd    ;if space is followed by
    je wrightend   ;0xd or 0xa
    cmp ch, 0xa    ;do no newline
    je wrightend
    ;else, space is followed by a word moved by linefull
wrspacenl:
    dec di ;results in di+1 in total after the next inc di
    mov bl, 0x20 ;return value for space-nl
wrightnl:
    cmp dh, 0x18 ;do not cause a scroll
    je wrightend
    inc di
    cmp cl, 0xd
    jne wrdskip
    inc di ;if 0xd, skip past 0xa also
wrdskip:
    ;move cursor like a newline
    inc dh
    mov dl, 0h
    mov ah, 2h
    int 10h
wrightend:
    ret
wcalldown:
    call wdown
    cmp bl, 0x20 ;space-caused nl return value
    je wleft ;has caused an extra nl; bad solution
    jmp editor
wdown:
    ;move cursor to end of next line
    call wright
    cmp cl, 0h ;eof
    je wdownend
    cmp dl, 0h ;new line reached
    je wdline
    cmp dh, 0x18 ;may not scroll
    jne wdown
wdline:
    cmp byte [es:di], 0xd
    je wdownend
    cmp byte [es:di], 0xa
    je wdownend
    call wright
    cmp cl, 0h ;eof
    je wdownend
    cmp dx, 0x184e ;cannot go beyond this
    je wdownend
    cmp bl, 0x20 ;space-caused nl return value
    jne wdline
wdownend:
    ret
wend:
    ;move cursor to end of text on screen
    push dx
    push di ;because wdown continues from 0xd to 0xa
    call wdown ;until dx no longer changes
    pop ax
    pop cx
    cmp cx, dx ;run until dx no longer moves
    jne wend
    ;check if di moved past the old di (ax)
    cmp di, ax
    je wcontinue
    mov di, ax ;if they are different, ax is correct
    jmp wcontinue
;scrolling
wpgup:
    ;scroll page up
    cmp si, 0h ;would scroll beyond top of file
    je editor
    cmp dh, 0x18 ;cursor would disappear
    je editor
    call rsiback ;si to previous line
    call back ;cursor top-left
    ;values for readloop
    mov bx, si
    mov cx, di ;read until di, then goes to wcontinue
    jmp readloop
wpgdown:
    ;scroll page down
    cmp dh, 0h ;cursor would disappear
    je editor
    call rsinext ;move si to next line
    call back ;cursor to top-left
    ;values for readloop
    mov bx, si
    mov cx, di ;read until di, then goes to wcontinue
    jmp readloop
wins:
    ;go to top of file
    call back
    xor si, si ;reset values
    xor di, di
    jmp wcontinue ;rewrite screen
wdel:
    ;go to end of file
    call back ;because dl must be 0h for readloop
    ;read es:bx until eof
    mov bx, di
    dec bx ;if already at eof (inc directly in lloop)
    call lloop
wdelgoto: ;used by goto if index is past eof
    ;put bx 0x200 chars before end
    sub bx, 0x200
    cmp bx, si ;if bx is not closer to end than si
    jb wdelend ;..read from si (si is also always >0)
    mov si, bx ;else: set si as bx and read from bx
wdelend:
    mov bx, si ;reread from si
    mov cx, 0xffff
    jmp readloop
wenter:
    ;handle the use of enter: 0xd 0xa
    call waddchar ;add 0xd to buffer
    cmp dh, 0x18 ;last line
    jne wenterskip
    call rsinext ;move si
wenterskip:
    call wnlfill ;cause a newline
    mov al, 0xa
    jmp weolskip ;0xa is added, and then update
;special functions
wspecial:
    ;type special ascii char
    mov ah, 0xe ;write the ~ char
    int 10h
    call filenum ;char value
    mov ah, 2h ;reset cursor, dx stored in wgetchar
    int 10h
    mov ah, 0xe
    mov al, cl ;output char
    int 10h
    jmp weolskip ;place char in buffer
wchar:
    ;print file_number:di = index of cursor char
    mov ah, 0xe ;write \ WARNING NASM comments can't end with backslash
    int 10h
    pop cx ;get file number
    push cx
    mov ch, cl
    call xtox
    mov al, 0x3a ;colon :
    int 10h ;ah is 0x0e from xtox
    mov cx, di
    call xtox
    mov ch, cl
    call xtox
    ;char press
    call keyget
    mov ah, 2h ;reset cursor
    int 10h
    jmp wcontinue ;to overwrite
wcallcopy:
    ;copy/cut
    mov cl, al ;09=copy, 00=cut
    mov ax, COPY_BUFFER
    mov fs, ax ;moved here due to a quick-save bug
    push si
    call wcopy
    pop si
    call back
    ;values for readloop
    cmp di, si ;when cutting left-limit might no longer be on screen
    ja wccsi   ;...
    xor si, si ;if so: read from start of file
wccsi:
    mov bx, si
    mov cx, di ;read until di, then goes to wcontinue
    jmp readloop
wcopy:
;the copy buffer looks like this:
;INDEX| CONTENT
;0    | copying? (byte)(1=true, 0=false)
;1-2  | index    (word)(index of first limit) [if copying=1]
;1-   | buffer   (string)(stores the text to copy) [if copying=0]
;index 1 is used depending on the value of 'copying' boolean
;either:
;[1, <index>]
;[0, <buffer>]
    xor si, si
    cmp byte [fs:si], 0h ;check if copy is active
    jne wccopy
    ;if not active mark copying as active 1h
    mov byte [fs:si], 1h ;start copying
    inc si
    mov [fs:si], di ;store char location
    ret
wccopy:
    ;copy content
    mov byte [fs:si], 0h ;mark end of copying
    inc si
    mov bx, [fs:si] ;get location of second limit/char
    mov ax, di ;current location into ax
    cmp bx, ax
    jle wcsave
    xchg bx, ax ;bx should be lower than ax
wcsave:
    mov dx, bx ;bx is left limit, store
wcsloop: ;loop to store chars in buffer
    mov ch, [es:bx]
    mov [fs:si], ch ;store char in copy buffer
    cmp bx, ax
    je wcsend ;all characters copied
    inc bx
    inc si
    jmp wcsloop
wcsend:
    inc si
    mov byte [fs:si], 0h ;mark end of copy string
    cmp cl, 0h ;0=cut
    jne wcend
    ;prepare cutting
    ;it is wsubchar, but done on a gap
    inc ax
    mov bx, ax ;first char after gap
    sub ax, dx ;size of gap +1
wcutloop:
    ;remove cut text from buffer
    mov ch, [es:bx]
    sub bx, ax
    mov [es:bx], ch ;move character
    add bx, ax
    inc bx
    cmp ch, 0h ;end of file
    jne wcutloop
    mov di, dx ;cut causes to left limit (dx)
wcend:
    ret ;di is still same old for copy
wpaste:
    mov ax, COPY_BUFFER
    mov fs, ax ;due to a quick-save bug
    mov bx, 1h ;where copied string starts
wpasteloop:
    mov al, [fs:bx] ;get char
    cmp al, 0h ;end of string
    je wpastend
    push bx
    call waddchar ;save char in buffer
    pop bx
    inc bx
    jmp wpasteloop
wpastend:
    call back
    ;values for readloop
    mov bx, si
    mov cx, di ;read until di, then goes to wcontinue
    jmp readloop
;function keys
wcallfind:
    ;find string in file
    call sget ;get string into gs:, di=0h
    xor bx, bx
    call wfind
wcfend: ;used by several
    ;reread file from start
    xor si, si
wcfend2: ;reread file from si
    call back
    ;values for readloop
    mov bx, si ;WARNING si should be given, since call back bh=0
    mov cx, di ;read until di, then goes to wcontinue
    jmp readloop
wfnext:
    ;find next occurance of string
    mov ax, SEARCH_BUFFER
    mov gs, ax
    xor bx, bx ;gs:bx search word
    call wfind
    jmp wcfend2
wfind:
    ;search for word; [es:di] and [gs:bx]
    mov al, [es:di]
    cmp al, 0h ;eof
    je wfend
    cmp al, [gs:bx] ;[es:di] == [gs:bx]
    je wfchar
    inc di
    xor bx, bx ;reset because not equal
    jmp wfind
wfchar:
    ;equal char (still) found
    inc di
    inc bx
    mov al, [gs:bx]
    cmp al, 0x2a ;* any-char wildcard
    je wfchar
    cmp al, 0xd ;0xd is end of search string
    jne wfind
wfend:
    ret
wreplace:
    ;replace string created by f1 with specified string
    mov ax, REPLACE_BUFFER
    mov fs, ax ;fs:si will be it later
    mov gs, ax ;but first gs:di is given to sword manually
    xor di, di
    call sword ;get string that will replace
    cmp al, 0x1b ;esc means we quit this function
    je wrend     ;di will be 0h
    mov ax, SEARCH_BUFFER ;when comparing, find old string
    mov gs, ax
wrloop:
    xor si, si ;fs:si replace buffer
    xor bx, bx ;gs:bx search buffer ;es:di text buffer
    ;compare chars between buffers
    call wfind
    cmp al, 0h ;eof reached
    je wrend
    ;else match found
    sub di, bx ;go to start of word
wrerase:
    ;erase old string
    push bx
    call wsubchar
    pop bx
    dec bx
    jne wrerase
    ;write new string, using fs:si
wrwrite:
    mov al, [fs:si]
    cmp al, 0xd ;end of replace string = finished replacing
    je wrloop
    call waddchar ;increases di
    inc si
    jmp wrwrite
wrend:
    ;di = eof, OR di = 0h if escaped
    jmp wcfend ;reread file
wascii:
    ;display table of ascii chars 0x10 - 0xff
    call new
    mov cl, 0x10 ;char counter
wascloop:
    mov ch, cl
    call xtox
    mov al, 0x3d ;=
    int 10h
    mov al, cl ;write char
    int 10h
    mov al, 0x20 ;space
    int 10h
    inc cl
    jne wascloop
    call keyget
    mov bx, si
    jmp wcfend2 ;will read until di from si
wreload:
    ;reload the last quicksave
    pop cx ;#files | first file
    mov bl, ch ;number of files
    call setfolder
    mov ah, 2h ;read
    mov al, bl
    xor bx, bx
    push ax ;IBM BIOS "bug"
    int 13h
    pop ax
    jmp editreload ;fill first screen
wgoto:
    ;go to certain char in file
    call filenum ;get location into cx
    mov ch, cl
    call filenum ;4 digit hex
    call back
    ;mov bx to eof
    mov bx, di
    dec bx ;if already at eof
    call lloop
    cmp cx, bx  ;if cx is beyond eof
    ja wdelgoto ;handle this as a wdel
    ;reread file from 0x200 chars before cx index
    mov bx, cx
    sub bx, 0x200
    cmp bx, 0h ;if bx gets <0 it should be 0
    jg wgend
    xor bx, bx
wgend:
    ;read from bx to cx
    mov si, bx
    mov di, cx
    jmp readloop ;cx already set
wsave:
    pop cx ;number of files | first file
    push ax ;save or quicksave check later
    ;go to end of bulk
    mov bx, di
    dec bx ;if di eof already
    call lloop ;go to eof
    ;mark end of file
    or bx, 0x1ff ;end of that file
    mov byte [es:bx], 0h ;place a null at end, to mark it is not a bulk
    shr bx, 9h ;/200h
    inc bl ;number of files to save
    ;save file
    push si ;due to quicksave
    call setfolder ;WARNING cx should be set before
    pop si
    mov al, bl ;number of files
    mov ah, 3h
    xor bx, bx
    push ax ;IBM BIOS "bug"
    int 13h
    pop ax
    mov ch, al ;cx = number of files | first file
    pop ax ;save or quicksave
    ;check if quicksave
    cmp al, 0x60 ;` pure save
    je wexit
    push cx ;only this is now on the stack
    jmp editor
wexit:
    ;exit the text editor
    mov ah, 0xe ;print save or esc char
    int 10h
    mov sp, 0x1000 ;reset stack pointer
    xor bx, bx
    mov byte [fs:bx], 0h ;reset copy buffer
    jmp input

delete:
    ;erases files
    call readfiles
    shl al, 1h ;*2 = "number of files" to delete for bx
dloop:
    mov byte [es:bx], 0h ;set as 0h, since if the first byte is a 0h the file is "empty"
    add bh, 2h ;next file
    cmp bh, al ;all files erased
    jne dloop
    ;write files back
    shr al, 1h ;return to old value
    mov ah, 3h
    xor bx, bx
    int 13h
    jmp input

lloop:
    ;read [es:bx] until 0h char
    inc bx
    cmp byte [es:bx], 0h ;end of file
    jne lloop
    ret
link:
    ;link files together (concatenate)
    call readfile ;get last file of first bulk
    push cx ;first file number
    call lloop
    call readfiles2 ;use bx value for destination
    call lloop
    ;write files
    pop cx ;file number
    mov ah, 3h
    or bx, 0x1ff ;go to last byte
    mov byte [es:bx], 0h ;mark end of file
    inc bh ;->200h
    mov al, bh
    shr al, 1h ;set al to right number of files to save
    xor bx, bx ;reset buffer
    int 13h
    jmp input

copystart:
    mov bx, 0x8080 ;source and destination disk (hard drive)
    jmp copy
jump:
    ;move file between usb and hard disk, only works when booting from usb
    ;get source 0=80h 1=81h
    ;destination will be opposite
    call keyget
    mov ah, 0xe ;output number
    int 10h
    mov bl, al ;store in bx
    mov bh, bl
    xor bx, 0xb1b0 ;convert from 30h to 80h, and flip the first bit of bh
copy:
    mov di, bx ;di is used to store source and destination disk
    mov ax, 0x1200
    mov es, ax
    call filenum ;file number
    push cx
    call filenum ;number of files
    mov al, cl
    mov ah, 2h ;for int 13h
    pop cx
    push ax
    call setfolder
    pop ax ;set ax
    push ax
    mov dl, bl ;set dl (bx=di)
    shr di, 8h ;get next value for dl
    xor bx, bx
    int 13h
    mov ax, 0xe77 ;w = succesfull read
    int 10h
    ;write
    call folder ;get destination folder
    call filenum ;file number
    call setfolder
    pop ax ;same number
    inc ah
    mov bx, di
    mov dl, bl ;drive
    xor bx, bx
    int 13h
    jmp input

;CALCULATOR
kalc:
    call kgetint
kagain: ;uses result from last operation, i.e. cx
    push cx ;store number
    call kgetint
    ;2 integers stored on stack
    ;0000-FFFF
    ;return integers
    pop dx ;first integer, 2nd already in cx
    ;get operator
    call keyget
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
    cmp al, 30h ;0=float division
    je kfloat
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
    xor dx, dx
    div cx
    mov dx, ax
    jmp kanswer
kmod:
    mov ax, dx
    xor dx, dx
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
    jmp kanswer
kfloat:
    ;uses the normal "long division" style of division for hexadecimal
    ;this means that instead of multiplying the remainder by 10, we do it by 16.
    ;4 digit result
    ;divide and save the remainder
    mov ax, 0xe2e ;.
    int 10h
    mov bl, 4h ;counter
    mov ax, dx
    xor dx, dx
    div cx
    ;dx is remainder
    ;divide dx by cx to get float
kfloop:
    shl dx, 4h ;*16 (multiply the remainder)
    push dx ;save
    mov ax, dx
    xor dx, dx
    div cx
    push ax ;output al
    mov ah, 0xe
    call xtoasc ;convert into ascii
    int 10h
    pop ax
    mul cx ;multiply quotient by divisor
    mov dx, ax
    pop ax
    sub ax, dx ;"long division" subtraction
    mov dx, ax
    dec bl
    jne kfloop
    jmp input
kanswer:
    ;answer in dx, output as hex
    mov ch, dh
    call xtox
    mov ch, dl
    call xtox
    mov cx, dx ;due to , command
    jmp input
kgetint:
    ;get 4-digit hex number
    call filenum
    mov ch, cl
    call filenum
    call enter
    ret

hex:
    ;convert hex to dec
    mov al, 0x30 ;end of result, ah = 0
    push ax
    ;get 4-digit hex
    call filenum
    mov ch, cl ;store value
    call filenum
    call enter
    mov ax, cx
    mov bx, 0xa ;divisor
hloop:
    xor dx, dx ;dx ax / bx, else too large result
    ;convert
    div bx
    push dx ;store remainder
    cmp ax, 0h ;division ended
    jne hloop
hend:
    ;write result
    pop ax
    cmp al, 0x30 ;end of result
    je input
    ;output
    add ax, 0xe30 ;printable
    int 10h
    jmp hend

xdec:
    ;convert dec to hex
    mov al, 0x30 ;mark end of result
    push ax
    mov dx, 0x2710 ;mul 10000
    xor bx, bx ;answer
    mov si, 0xa ;dx ax / si
    mov cl, 5h ;counter
xget:
    ;get number
    call keyget
    mov ah, 0xe ;output
    int 10h
    and ax, 0xf ;~sub 30h
    push dx ;save while mul
    mul dx
    add bx, ax ;store answer in bx
    ;div dx 10
    pop dx
    mov ax, dx
    xor dx, dx ;divide dx by 10, since in the next digit x will be one less in 10^x.
    div si
    mov dx, ax
    dec cl
    jne xget ;if not 0
    mov si, 0x10 ;div
    mov ax, bx ;answer in bx
xconv:
    xor dx, dx
    div si
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

real:
    ;convert hex float to dec float
    call filenum
    mov bh, cl
    call filenum ;get number and push
    mov bl, cl
    push bx
    mov cl, 6h ;counter=number of digits in output
    mov bx, 0xa ;10 is multiplier
    call enter
    mov al, 0x2e ;.
    int 10h
    pop ax ;number to convert
realoop:
    mul bx      ;by solving for x in the ratio equation (x/10=y/16)..
    push ax     ;where y is the upper most nibble in ax (the inputted float value)..
    mov al, dl  ;you can convert a hexadecimal float to decimal float -> x=(y*10)/16..
    add al, 30h ;you don't have to divide by 16, since the quotient will still be the same as in dl
    mov ah, 0xe
    int 10h ;print value
    pop ax
    dec cl
    jne realoop ;6 decimal points precision
    jmp input

info:
    ;Pikobrain dir/ls command
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x1fa ;folder number location
    ;ouput folder number in hex
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
    ;get file info in folder
    mov ax, 0x1200
    mov es, ax
    xor bx, bx
    mov cl, 1h ;changes later
    call setfolder
    mov ax, 0x23f ;read all files
    int 13h
    mov cl, 1h
iloop:
    ;read file
    cmp byte [es:bx], 0h ;is empty?
    je ilend
    ;output filenum
    mov ch, cl
    call xtox
    mov ax, 0xe2e ;.
    or bx, 0x1ff ;end of file
    cmp byte [es:bx], 0h ;check if file is full
    je iskip
    mov al, 0x3a ;: used if file is full
iskip:
    int 10h ;output . or :
    and bx, 0xfe00 ;start of file
    mov ch, 0xa ;char counter
iwloop:
    ;write 10 chars
    mov al, [es:bx]
    cmp al, 0x20 ;space, to not print weird chars
    jge iw
    mov al, 0x2a ;* to mark special char
iw:
    int 10h
    inc bl ;next char
    dec ch
    jne iwloop ;10 characters
    mov ax, 0xe20 ;space
    int 10h
    int 10h
    int 10h ;3 times, will cause a newline
ilend:
    mov bl, cl
    shl bx, 9h ;move bx to next file
    inc cl
    cmp cl, 0x40 ;last file
    je input
    jmp iloop ;read next file

search:
    ;search for string in folder (find)
    call sget ;input string
    call enter
    ;read all files
    mov ax, 0x1200
    mov es, ax
    xor bx, bx
    mov cl, 1h ;will change
    call setfolder
    mov ax, 0x23f ;all files
    int 13h
sloop:
    xor di, di ;reset, [gs:di] stores string
scomp:
    mov dl, [gs:di] ;compare with search word
    cmp dl, 0xd ;end of search word
    je sfind
    cmp dl, 0x2a ;* any character
    je scont
    mov al, [es:bx] ;get char from file
    cmp al, 0h ;end of file
    je seof
    cmp al, dl
    jne snot ;not equal words
scont:
    inc bx
    inc di
    jmp scomp
sfind:
    ;print file number
    push bx
    push bx
    shr bx, 9h ;"convert" into file number
    inc bl
    mov ch, bl
    call xtox
    mov ax, 0xe2e ;.
    int 10h
    pop bx
    and bx, 0x1ff ;clear upper bits
    ;output index of string found location
    mov ch, bh
    call xtox
    mov ch, bl
    call xtox
    mov al, 0x20 ;space
    int 10h
    pop bx
seof:
    ;end of file
    or bx, 0x1ff
snot:
    inc bx ;next char
    cmp bh, 0x7e ;check if last file
    jge input
    jmp sloop

os:
    ;display largest folder
    mov ah, 8h ;get drive info
    mov dl, 0x80
    int 13h
    push cx
    shr cl, 6h ;upper bits of track
    mov ch, cl
    call xtox
    mov ch, dh ;sides
    call xtox
    pop cx ;cylinders
    call xtox
    call enter
    and cl, 0x3f ;clear upper bits
    mov ch, cl ;sectors
    call xtox
    jmp input

;ASSEMBLER
assembly:
    mov ax, 0x1a00
    mov gs, ax ;gs:di writes machine opcodes
    xor di, di
    mov byte [gs:di], 0x5c ;\ to mark executable for r command
    inc di
    call readfiles
    mov sp, 0x1000 ;reset stack pointer
    xor si, si ;fs:si stores labels and jmp
    push si ;store for labels
aconv:
    mov al, [es:bx] ;get char
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
    cmp al, 0x5a ;shift z
    je aZ
    cmp al, 0x51 ;rotate q
    je aQ
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
    cmp al, 0x47 ;in/out g
    je aG
    cmp al, 0x4a ;Jmp
    je aJ
    cmp al, 0x46 ;Call function
    je aF
    cmp al, 0x52 ;Ret
    je aR
    cmp al, 0x57 ;macro w
    je aW
    cmp al, 0x2e ;. label
    je aLabel
    cmp al, 0x4b ;db kreate
    je a1bk
    cmp al, 0x45 ;End
    je aE
    cmp al, 0h ;end of file
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
    cmp dl, 0x52 ;Register
    je aMR
    cmp dl, 0x4e ;Number
    jne aMS      ;Segment
    ;MOV NUMBER
    mov dl, 0xb0 ;opcode for MN
    jmp amregstart
aMR:
    ;MOV REGISTER
    mov dh, 0x88 ;opcode for MR (or 89)
    jmp acombstart
aMS:
    cmp dl, 0x49 ;I= mov Xs, ax
    je aMI
    cmp dl, 0x4f ;O= mov ax, Xs
    je aMO
    cmp dl, 0x45 ;ME
    jb aMAstart
    cmp dl, 0x47 ;MG
    ja aMAstart  ;if not E,F,G -> mov xx, [xx:xx]
    ;mov [xx:xx], xx OR MIx
    mov al, ah
    mov ah, dl ;seg:off chars into ax
    push ax
    dec bx
    call aloop2 ;get register chars into ax
    mov cx, ax ;placed into cx
    pop ax
    mov dx, 0x8826 ;mov [xx:xx], al
    cmp cl, 0x58 ;X
    jne aMA
    inc dh
    jmp aMA
aMI:
    ;mov seg.reg, reg ;; MI rg sr
    mov dh, 0x8e
    jmp acomb
aMO:
    ;mov reg, seg.reg ;; MO rg sr
    mov dh, 0x8c
    jmp acomb
aMAstart:
    ;mov xx, [xx:xx]
    mov cl, ah
    mov ch, dl ;register chars into cx
    dec bx
    call aloop2 ;seg:off chars into ax
    mov dx, 0x8a26
    cmp cl, 0x58 ;X
    jne aMA
    inc dh ;16-bit
aMA:
    cmp ah, 0x45 ;E:
    je aMA0
    cmp ah, 0x46 ;F:
    je aMA1
    cmp ah, 0x47 ;G:
    je aMA2
    jmp aerror
    ;inc dl from 0x26
aMA2:
    inc dl
aMA1:
    add dl, 0x3e
aMA0:
    mov [gs:di], dx ;save
    add di, 2h
    mov dl, 0x4 ;last byte for register
    cmp al, 0x42 ;B
    je aM2
    cmp al, 0x53 ;S
    je aM0
    cmp al, 0x54 ;T
    je aM1
    jmp aerror
    ;inc dl
aM2:
    add dl, 2h
aM1:
    inc dl
aM0:
    mov ax, cx ;prepare acomb
    mov ch, 8h ;number to add
    jmp acomb2
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
    mov dx, 0x80c0
    mov ch, 1h
    jmp aregstart
aAR:
    ;ADD REGISTER
    mov dh, 0h
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
    jmp aregstart
aSR:
    mov dh, 0x28
    jmp acombstart
aaT:
    ;MUL
    call aloop
    mov dx, 0xf6e0
    mov ch, 3h ;no argument
    jmp aregstart
aD:
    ;DIV
    call aloop
    mov dx, 0xf6f0
    mov ch, 3h ;no argument
    jmp aregstart
aaH:
    ;INC
    call aloop
    mov dx, 0xfec0
    mov ch, 3h
    jmp aregstart
aaL:
    ;DEC
    call aloop
    mov dx, 0xfec8
    mov ch, 3h
    jmp aregstart
aZ:
    ;SH R/L
    call aloop
    cmp dl, 0x52 ;R
    je aZR
    cmp dl, 0x4c ;L
    je aZL
    jmp aerror
aZR:
    mov dx, 0xc0e8
    mov ch, 1h
    cmp al, 0x58 ;X
    je aZQX
    jmp aregstart
aZL:
    mov dx, 0xc0e0
    mov ch, 1h
    cmp al, 0x58 ;X
    je aZQX
    jmp aregstart
aQ:
    call aloop
    cmp dl, 0x52 ;R
    je aQR
    cmp dl, 0x4c ;L
    je aQL
    jmp aerror
aQR:
    mov dx, 0xc0c8
    mov ch, 1h
    cmp al, 0x58 ;X
    je aZQX
    jmp aregstart
aQL:
    mov dx, 0xc0c0
    mov ch, 1h
    cmp al, 0x58 ;X
    je aZQX
    jmp aregstart
aZQX:
    ;Z and Q will take 8 bit argument even if 16 bit register
    dec ch ;will end up as 1h = 1 byte
    jmp aregstart
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
    jmp aregstart
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
    jmp aregstart
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
    mov dx, 0x80f0 ;special case
    mov ch, 1h
    jmp aregstart
aXR:
    mov dh, 0x30
    jmp acombstart
aN:
    ;NOT
    call aloop
    mov dx, 0xf6d0
    mov ch, 3h
    jmp aregstart
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
    jmp aregstart
aCR:
    mov dh, 0x38
    jmp acombstart
aregstart:
    ;aregstart is for [mne] [reg], [imm8/16]
    ;dx contain opcode, and ch number of bytes in source
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
    ;amregstart is for mov [reg], [imm8/16]
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
    ;acombstart is for [mne] [reg], [reg]
    ;byte or word move?
    cmp al, 0x58 ;X
    jne acomb
    inc dh ;for r16
acomb: ;used by MI and MO
    mov [gs:di], dh ;opcode for operation
    mov dl, 0xc0 ;argument, for the various combinations
    mov ch, 1h ;adds to dl depending on combination
    inc di ;do it here due to segment moves MEBAL etc.
acomb2: ;for second round
    ;get combinations of registers
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
    cmp ax, 0x4553 ;ES
    je ac0
    cmp ax, 0x4653 ;FS
    je ac4
    cmp ax, 0x4753 ;GS
    je ac5
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
    call aloop2
    mov ch, 8h ;new add number
    jmp acomb2
acombend:
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
    jne aerror
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
    ;IN/OUT
    inc bx
    mov dl, [es:bx]
    inc bx ;needed in both
    cmp dl, 0x49 ;I
    je aGI
    cmp dl, 0x4f ;O
    je aGO
    jmp aerror
aGI:
    ;IN
    mov dl, [es:bx]
    cmp dl, 0x49 ;I
    je aGII
    cmp dl, 0x41 ;A
    je aGIA
    cmp dl, 0x58 ;X
    je aGIX
    ;else: in al, imm8
    mov byte [gs:di], 0xe4
    jmp a1b
aGII:
    ;in ax, imm8
    mov byte [gs:di], 0xe5
    jmp a1b
aGIA:
    ;in al, dx
    mov byte [gs:di], 0xec
    jmp acend
aGIX:
    ;in ax, dx
    mov byte [gs:di], 0xed
    jmp acend
aGO:
    ;OUT
    mov dl, [es:bx]
    cmp dl, 0x4f ;O
    je aGOO
    cmp dl, 0x41 ;A
    je aGOA
    cmp dl, 0x58 ;X
    je aGOX
    ;else: out al, imm8
    mov byte [gs:di], 0xe6
    jmp a1b
aGOO:
    ;out ax, imm8
    mov byte [gs:di], 0xe7
    jmp a1b
aGOA:
    ;out al, dx
    mov byte [gs:di], 0xee
    jmp acend
aGOX:
    ;out ax, dx
    mov byte [gs:di], 0xef
    jmp acend
aF:
    mov byte [gs:di], 0xe8 ;call
    jmp aJMP
aR:
    mov byte [gs:di], 0xc3 ;ret
    jmp acend
aW:
    ;macros, using Pikobrain functions
    mov byte [gs:di], 0xe8 ;call
    inc bx
    inc di
    mov cx, 0xe000 ;difference betwwen segment 0x1000: and 0x1200:, stores jump lenght
    mov al, [es:bx] ;next char
    cmp al, 0x41 ;atohex
    je aWA
    cmp al, 0x45 ;enter
    je aWE
    cmp al, 0x46 ;folder
    je aWF
    cmp al, 0x47 ;sGet
    je aWG
    cmp al, 0x48 ;xtoasc Hex
    je aWH
    cmp al, 0x4b ;keyget
    je aWK
    cmp al, 0x4e ;fileNum
    je aWN
    cmp al, 0x4f ;readfiles2 Open
    je aWO
    cmp al, 0x52 ;random
    je aWR
    cmp al, 0x53 ;setfolder
    je aWS
    cmp al, 0x57 ;neW
    je aWW
    cmp al, 0x58 ;xtox
    je aWX
    jmp aerror
aWA:
    add cx, atohex ;adding location of function to cx
    jmp aWend
aWE:
    add cx, enter
    jmp aWend
aWF:
    add cx, folder
    jmp aWend
aWG:
    add cx, sget
    jmp aWend
aWH:
    add cx, xtoasc
    jmp aWend
aWK:
    add cx, keyget
    jmp aWend
aWN:
    add cx, filenum
    jmp aWend
aWO:
    add cx, readfiles2
    jmp aWend
aWR:
    add cx, random
    jmp aWend
aWS:
    add cx, setfolder
    jmp aWend
aWW:
    add cx, new
    jmp aWend
aWX:
    add cx, xtox
    jmp aWend
aWend:
    sub cx, di
    sub cx, 2h ;bacause of the size of this call
    mov word [gs:di], cx
    inc di
    jmp acend
aJ:
    inc bx
    mov al, [es:bx]
    cmp al, 0x4d ;M
    je aJM
    mov byte [gs:di], 0xf ;conditional far jump
    inc di
    cmp al, 0x45 ;Equal
    je aJE
    cmp al, 0x4e ;Not equal
    je aJNE
    cmp al, 0x47 ;Greater
    je aJG
    cmp al, 0x41 ;Above
    je aJA
    cmp al, 0x4c ;Less
    je aJL
    cmp al, 0x42 ;Below = Carry
    je aJB
    cmp al, 0x4f ;Overflow
    je aJO
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
aJA:
    mov byte [gs:di], 0x87
    jmp aJMP
aJL:
    mov byte [gs:di], 0x8c
    jmp aJMP
aJB:
    mov byte [gs:di], 0x82
    jmp aJMP
aJO:
    mov byte [gs:di], 0x80
    jmp aJMP
aJM:
    mov byte [gs:di], 0xe9 ;jmp
aJMP:
    call askip
    mov ax, 0x2000 ;fs:si stores jmp statements
    mov fs, ax
    inc di ;where machine code will be written
    mov cx, di ;store location of machine code pointer
    inc di ;to be correct later
    call aJMl
    inc si
    mov [fs:si], cx ;store di
    add si, 2h
    jmp acend
aJMl:
    ;store label name in fs:si
    mov al, [es:bx]
    mov [fs:si], al
    cmp al, 0x2e ;. end of label name
    je aJMlend
    inc si
    inc bx
    jmp aJMl
aJMlend:
    ret
aLabel:
    mov ax, 0x2800 ;fs:si stores labels
    mov fs, ax
    mov dx, si ;store for later
    pop si ;the si for 0x2800 is stored on stack
    mov cx, di ;store for later (dx=si, cx=di)
    inc bx ;get passed the 1st "." in label name
    call aJMl ;store label in buffer
    ;store memory location of label
    inc si
    mov [fs:si], cx ;store di
    add si, 2h
    push si
    mov si, dx ;return to normal
    inc bx
    jmp aconv
aComment:
    ;commenting
    inc bx
    mov al, [es:bx]
    cmp al, 0h ;end of file
    je aconv
    cmp al, 0xd ;newline = end of comment
    jne aComment
    jmp aconv
aE:
    ;end program by a far return
    mov byte [gs:di], 0xcb ;far return
    jmp acend
aPrint:
    ;print string
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
aloop2:
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
a2b:
    call agetbyte
    push ax
a1b:
    inc di
a1bk:
    call agetbyte
    push ax
abloop:
    pop ax
    mov [gs:di], al
    cmp sp, 0xffe ;since si pushed
    je acend
    inc di
    jmp abloop
aerror:
    ;output the location in source code
    mov ch, bh
    call xtox
    mov ch, bl
    call xtox
    mov ax, 0xe65 ;e
    int 10h
    ;will still save
asave:
    ;add jumps to machine code (second round)
    mov ax, 0x2000
    mov fs, ax
    mov byte [fs:si], 0h ;mark end of jmp list
    mov ax, 0x2800
    mov es, ax
    pop si
    mov byte [es:si], 0h ;mark end of label list
    xor si, si
aslstart:
    xor bx, bx
ascomp:
    push si
asaveloop:
    mov al, [fs:si] ;get jmp statement label
    cmp al, 0h
    je awrite ;end of jmps
    cmp al, [es:bx]
    jne ascompend ;not same name
    cmp al, 0x2e ;. end of label name
    je ascompeq ;label found
    inc si
    inc bx
    jmp asaveloop
ascompend:
    ;jump past label
    mov al, [es:bx]
    cmp al, 0x2e;. end of name
    je ascend
    cmp al, 0h ;label not found
    je alerror
    inc bx
    jmp ascompend
ascend:
    pop si ;reset
    add bx, 3h ;jump past label location
    jmp ascomp
ascompeq:
    ;label found
    inc si
    mov cx, [fs:si] ;jmp location
    inc bx
    mov dx, [es:bx] ;label location
    sub dx, cx ;calculate jump lenght
    sub dx, 2h ;because of how jmps work
    mov bx, cx
    mov [gs:bx], dx ;store jump lenght
    ;update values for next round
    pop ax ;take down si
    add si, 2h ;go past jmp location
    jmp aslstart
alerror:
    pop si ;take down si
    mov ah, 0xe ;output label name
aleloop:
    ;label error
    mov al, [fs:si]
    int 10h
    inc si
    cmp al, 0x2e ;. end of name
    jne aleloop
awrite:
    mov ax, 0xe61 ;assembled
    int 10h
    ;buffer of machine code to be saved
    mov ax, 0x1a00
    mov es, ax
    xor bx, bx
    ;destination file
    call filenum
    call setfolder
    mov ax, di ;calculate number of files to save: di//0x200
    shr ax, 9h ;/200h
    inc al
    push cx
    push ax
    mov ch, al
    call xtox ;print size of machine code
    pop ax
    pop cx
    mov ah, 3h
    int 13h
    jmp input

run:
    ;run user program
    call readfiles
    cmp byte [es:bx], 0x5c ;\ marks executable (only these run)
    jne input
    call 0x1000:0x2001 ;location of program machine code
runcall: ;used in ctrl+break handler
    jmp input


;***********
CTRL_BREAK: ;Location used in bootloader
;***********

    ;ctrl+break handler
    ;goes to input
    mov bx, sp ;store
    mov sp, 0xffe ;first stack item
breakloop:
    pop ax
    cmp ax, 0x1000 ;search for cs value 0x1000
    jne breakcon
    ;set new cs:ip values to 0x1000:0x200
    push ax ;0x1000
    sub sp, 2h
    pop ax
    cmp ax, runcall ;cs:ip will be at a different place while running
    je breakcon
    mov ax, input
    push ax
    mov sp, bx ;reset
    iret
breakcon:
    push ax
    sub sp, 2h ;next stack item
    jmp breakloop

    times 6144-($-$$) db 0h ;fill space

;commands to assemble and make into flp file linux + NASM
;nasm -f bin -o myfirst.bin myfirst.asm
;dd status=noxfer conv=notrunc if=myfirst.bin of=myfirst.flp

;to place onto USB:
;sudo dd if=piko.bin of=/dev/sdb

;to read file 0D of the USB on Linux (after using the j command)
;sudo head -c 6656 /dev/sdb | tail -c 512 > test.txt
