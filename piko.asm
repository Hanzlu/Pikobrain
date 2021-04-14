	BITS 16

;***********
;BOOTLOADER
;***********

jmp bootloader

    ;help file
    db "Pikobrain v1.4", 0xd, 0xa
    db "time", 0xd, 0xa
    db "date", 0xd, 0xa
    db "enter", 0xd, 0xa
    db "new", 0xd, 0xa
    db "back", 0xd, 0xa
    db "os", 0xd, 0xa
    db "kalc [4h][4h][1h]", 0xd, 0xa
    db "hex [4h]", 0xd, 0xa
    db "xdex [5d]", 0xd, 0xa
    db ".float [4h]", 0xd, 0xa
    db "folder [fo]", 0xd, 0xa
    db "search [str]", 0xd, 0xa
    db "info", 0xd, 0xa
    db "zero ['y']", 0xd, 0xa
    db "write [fi]", 0xd, 0xa
    db "edit [fi][2h]", 0xd, 0xa
    db "memory [fi]", 0xd, 0xa
    db "visible [fi][2h]", 0xd, 0xa
    db "copy [fi][2h][fo][fi]", 0xd, 0xa
    db "jump [1h][fi][2h][fo][fi]", 0xd, 0xa
    db "assembly [fi][2h][fi]", 0xd, 0xa
    db "run [fi][2h]"

bootloader:
    ;set up registers
    mov ax, 0x9c0
    mov ss, ax ;stack segment
    mov ax, 0x7c0
    mov ds, ax ;data segment
    mov sp, 0x1000 ;stack pointer
    
    ;read files
    ;set buffer
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    ;read
    mov ax, 0x20a ;files to read 10x
    mov cx, 1h
    mov dh, 0h ;dl set at boot
    int 13h
    cmp ah, 0h ;if error stop
    jne $

    ;check if install has been made
    mov bx, 0x1fd ;location of variable
    mov al, [es:bx]
    cmp al, 1h ;1=installing
    jne jmppb ;jump to kernel
    ;mark as installed
    mov byte [es:bx], 0h ;set as 0=installed
    ;set destination drive for install
    shr dl, 7h
    or dl, 0x80
    ;write files to hard drive
    xor bx, bx
    mov ax, 0x30a ;10x files to write
    mov cx, 1h
    int 13h
    cmp ah, 0h ;if error stop
    jne $

jmppb:
    jmp 0x1000:0x0200 ;pikobrain "kernel"

    ;fill up space
    times 509-($-$$) db 0h
    db 1h ;boot true (variable)
    dw 0xAA55


;**********
;PIKOBRAIN
;**********

    ;set up copy buffer
    mov ax, 0x1140
    mov es, ax
    xor bx, bx
    mov byte [es:bx], 0h
    ;setup random
    add bx, 0x400
    mov byte [es:bx], 0h

callnew:
    call new
    jmp input
new:
    pusha ;store for assembly macros
    ;set graphics mode
    mov ax, 3h
    int 10h
    ;set color
    mov ax, 0x600
    mov bh, 0xe ;black-yellow <-- change this value to change colors in Pikobrain
    xor cx, cx
    mov dx, 0x184f
    int 10h
    popa
    ret

input:
    ;char input
    mov ah, 0h
    int 16h
    mov bh, 0h ;graphics reason

    cmp al, 0xd  ;enter
    je callenter  
    cmp al, 0x62 ;b
    je back
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
    cmp al, 0x2e ;.
    je real
    cmp al, 0x6f ;o
    je os
    cmp al, 0x6d ;m
    je memory
    cmp al, 0x76 ;v
    je visible
    cmp al, 0x77 ;w
    je write
    cmp al, 0x65 ;e
    je edit
    cmp al, 0x63 ;c
    je copystart  
    cmp al, 0x66 ;f
    je callfolder
    cmp al, 0x69 ;i
    je info
    cmp al, 0x7a ;z
    je zero
    cmp al, 0x73 ;s
    je search
    cmp al, 0x6a ;j
    je jump
    cmp al, 0x61 ;a
    je assembly
    cmp al, 0x72 ;r
    je run
    
    ;else arrows
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

back:
    ;move cursor to top left
    mov ah, 2h
    xor dx, dx
    int 10h
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
    ;reads file. asks for file number
    ;set buffer
    mov ax, 0x1200
    mov es, ax
    xor bx, bx
    call filenum
    call setfolder
    ;get filenum
    mov ax, 0x201 ;read one file
    mov dl, 0x80 ;drive
    int 13h
    ret

readfiles:
    ;read multiple files
    ;buffer
    mov ax, 0x1200 ;source file
    mov es, ax
    xor bx, bx
    ;first file
    call filenum
    push cx ;filenum
    ;number of files
    call filenum ;number of files
    mov dl, cl ;store for al
    ;set cx
    pop cx
    ;folder
    call setfolder
    mov ah, 2h
    mov al, dl
    mov dl, 0x80 ;drive
    int 13h ;read
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
    ;converts and into cl
    mov ah, 0h
    int 16h
    cmp al, 0x8 ;backspace
    je filenquit ;cancel
    mov ah, 0xe
    int 10h
    call atohex
    mov cl, al
    shl cl, 4h ;*16, upper nibble
    mov ah, 0h
    int 16h
    cmp al, 0x8 ;backspace
    je filenquit ;cancel
    mov ah, 0xe
    int 10h
    call atohex
    add cl, al ;lower nibble
    ret
filenquit:
    ;clear stack (unpopped values)
    pop ax ;pop ip because function
    cmp sp, 0x1000 ;if stack is empty
    jne filenquit
    jmp callnew ;if used as pikoasm macro, this will cancel program

setfolder:
    ;set folder to current
    and cl, 0x3f ;clear upper bits
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x13fd ;OS size depending
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
    ;change head and track=folder number
    ;dh and ch (cl) for int 13h
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x13ff ;!OS size depending
    call filenum
    cmp cl, 0h ;double press tab to select current folder-> value will be negative
    jl fsame
    cmp cl, 0x44 ;double semi-colon to only enter last two digits
    je flast
    cmp cl, 0x3f ;double press letter to select home folder (000000)
    jg fhome
    ;store filenum
    and cl, 3h ;clear bits
    push cx
    call filenum
    push cx
    call filenum
    mov [fs:si], cl
    dec si
    pop cx
    mov [fs:si], cl
    dec si
    pop cx
    mov [fs:si], cl 
    ret
fhome:
    ;set to 000000
    dec si
    mov word [fs:si], 0h
    dec si
    mov byte [fs:si], 0h
    ret
flast:
    ;only change last two digits
    call filenum
    mov [fs:si], cl
fsame: ;do nothing, use current folder
    ret

random:
    push cx ;store for assembly macros
    push dx
    ;random number generator
    ;get tick
    mov ah, 0h
    int 1ah
    ;setup buffer
    mov ax, 0x1180
    mov fs, ax
    xor si, si
    mov ax, [fs:si]
    cmp al, 0h ;check if random value been generated
    jne rcon
    mov al, dl ;use dh value
    mov ah, dh ;subtracter
    jmp rend
rcon:
    sub ah, dl ;update number = generate
    sub al, ah
rend:
    mov [fs:si], ax ;save
    pop dx
    pop cx
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
    mov al, 0x2f ;/
    int 10h
    mov ch, dh
    call xtox
    mov al, 0x2f ;/
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
    call readfile
    mov dl, 0h ;due to visible, show m command running
menter: ;check last line
    mov dh, 0h
    call enter
mbyte:
    ;read file as hex
    ;get content of byte
    mov ch, [es:bx]
    cmp ch, dl ;if value to be visible
    je mvisible
    call xtox
mcon:
    mov ax, 0xe20 ;space
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
mvisible:
    mov ax, 0xe2e ;.
    int 10h
    int 10h
    jmp mcon

visible:
    ;highlight opcode in memory
    call readfile ;get file
    call filenum ;get opcode
    mov dl, cl ;to show that the v command is running
    call menter

read:
    ;read file as ASCII chars
    call readfiles
    mov bl, al;number of files
    shl bx, 9h ;*200h, buffer size
    mov byte [es:bx], 0h
    mov dx, bx
readstart: ;used by wdel
    push cx ;store file number
    call new ;due to edit and wcut
    xor bx, bx
    xor si, si ;stores enters for scrolling
nextread:
    mov al, [es:bx]
    cmp al, 0h ;null char
    je readend
    cmp al, 0xd ;newline
    je readsi
readcon:
    mov ah, 0xe ;due to write
    int 10h
    inc bx
    cmp bx, dx ;because of edit
    jne nextread
readend:
    pop cx ;file number
    ret
readsi:
    push ax
    push bx
    mov bh, 0h
    mov ah, 3h ;get cusor position
    int 10h
    pop bx
    pop ax
    cmp dh, 0x18 ;bottom row
    jne readcon
    call rsiloop
    jmp readcon
rsiloop:
    inc si
    cmp byte [es:si], 0xa ;newline
    jne rsiloop
    inc si
    ret
rbacksi:
    sub si, 2h
rbsiloop:
    dec si
    cmp si, 1h
    jle rbsiend
    cmp byte [es:si], 0xa ;newline
    jne rbsiloop
    inc si
    ret
rbsiend:
    xor si, si
    ret

;TEXT EDITOR
write:
    ;buffer
    mov ax, 0x1200
    mov es, ax
    ;get file number
    call filenum
    push cx ;store for save
    xor cx, cx ;due to edit after writeram, how many chars already in file
    ;set cursor position
    call new
    ;clear ram
    xor bx, bx
    xor si, si ;for scrolling
    mov dx, 0x200 ;for writeram
writeram:
    ;clear buffer
    mov dword [es:bx], 0h
    add bx, 4h
    cmp bx, dx
    jl writeram ;less due to edit
    mov di, cx
    mov fs, dx ;store size of buffer
    push si ;for scrolling
    mov ax, 0x1140 ;copy buffer
    mov gs, ax
typechar:
    pop si
    push si
    mov bh, 0h ;video page
    ;get cursor position
    mov ah, 3h
    int 10h
    push dx ;save
    call wtype
    pop dx
    mov ah, 2h ;reset cursor
    int 10h
    jmp wgetchar
wtype:
    mov bh, 0h ;i hate this
    mov si, di
typeloop:
    mov ah, 0xe
    mov al, byte [es:si]
    cmp al, 0h ;end of file
    je typend
    cmp al, 0xd ;enter
    je typelinestart
    cmp al, 0xa ;don't output
    je typecont
    int 10h ;output char
typecont:
    inc si
    cmp dh, 0x18 ;bottom row
    jne typeloop
typend:
    ;reset cursor
    call typeline ;clear two lines
    call typeline ;..due to backspace on newline
    ret
typelinestart:
    call typeline
    jmp typecont
typeline:
    mov ah, 3h ;get cursor position
    int 10h
    mov bl, 0x50 ;width of screen
    cmp dh, 0x18 ;if on lowest row, prevent newline by bl-1
    jne typelcon
    dec bl
typelcon:
    sub bl, dl ;number of spaces to fill up line with
    mov ax, 0xe20 ;space
tlloop:
    cmp bl, 0h ;end of row
    je tlloopend
    int 10h ;!this must be below the cmp
    dec bl
    jmp tlloop
tlloopend:
    ret
wgetchar:
    mov bh, 0h
    ;get cursor location for dx, used by some keys
    mov ah, 3h
    int 10h
    ;get char to write
    mov ah, 0h
    int 16h
    ;certain characters shall not be outputted
    cmp al, 0x8 ;backspace
    je backspace
    cmp ah, 0x4b ;left arrow
    je wleft
    cmp ah, 0x4d ;right arrow
    je wright
    cmp al, 0x9 ;tab (circle)
    je wrowleft
    cmp ah, 0xf ;shifted tab
    je wrowright
    cmp ah, 0x49 ;page up
    je wup
    cmp ah, 0x51 ;page down
    je wdown
    cmp al, 0x7c ;| cut
    je wcopy
    cmp ah, 0x50 ;down arrow
    je wcopy
    cmp ah, 0x48 ;up arrow
    je wpaste
    cmp ah, 0x52 ;ins
    je wins
    cmp ah, 0x53
    je wdel
    cmp ah, 0x47 ;home
    je whome
    cmp ah, 0x4f ;end
    je wend
    cmp al, 0xd ;enter
    je wenter
    cmp al, 0x7e ;~ char count
    je wchar
    ;output character typed
    mov ah, 0xe
    int 10h
    ;special chars
    cmp al, 0x60 ;` save
    je save
    cmp al, 0x1b ;esc cancel
    je input
    cmp al, 0x5c ;\ special char
    je wspecial
    call wloopstart
wtypend:
    mov cx, fs ;due to wtypend
    cmp si, cx
    jge wsize
    jmp typechar
wsize:
    ;increase size of buffer by clearing more space
    add cx, 0x200
wsizeloop:
    ;clear buffer
    mov dword [es:si], 0h
    add si, 4h
    cmp si, cx
    jl wsizeloop
    mov fs, cx
    jmp typechar
    ;adds character to buffer
wloopstart:
    mov si, di
    mov cx, fs
wloop:
    mov ah, [es:si]  ;get current char
    mov [es:si], al  ;place new char (the typed one)
    mov al, ah       ;store the old char as the "new char"
    inc si
    cmp si, cx   ;check if file end
    jge wloopend
    cmp al, 0h       ;check if file end
    jne wloop
wloopend:
    inc di           ;update di
    ret
wleft:
    dec di
    cmp dl, 0h ;beginning of line
    je wleftnl
    mov ax, 0xe08 ;backspace
    int 10h
    jmp wgetchar
wleftnl:
    ;move cursor
    mov ah, 2h
    dec dh
    mov dl, 0x4f ;end of line
    int 10h
    cmp byte [es:di], 0xa ;newline
    jne wgetchar
    dec di
    jmp wbnloop
wright:
    call wright2
    jmp wgetchar
wright2:
    ;get cursor location
    mov ah, 3h ;due to wend
    int 10h
    cmp dl, 0x4f ;end of line
    je wrightnl
    cmp byte [es:di], 0xd ;newline as well
    je wrightnl
    inc di
    ;move cursor right
    mov ah, 2h
    inc dl
    int 10h
    ret
wrightnl:
    add di, 2h ;go past 0xa
    ;move cursor
    mov ah, 2h
    inc dh ;next line
    mov dl, 0h
    int 10h
    ret
backspace:
    ;output backspace
    mov ax, 0xe08
    int 10h
    dec di
    mov ch, [es:di] ;must store for cmp later
    call wbloopstart ;erase
    cmp dl, 0h ;newline erase? (cursor pos)
    je wbnl
wbauto:
    mov bh, 0h
    mov cx, 0x1 ;only one character
    mov ax, 0xa20 ;for backspace newline
    int 10h
    jmp typechar
wbnl:
    ;move cursor
    mov ah, 2h
    dec dh
    mov dl, 0x4f ;79 end of row
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
    dec ah ;2h i don't like dec ah, but here it is
    dec dl
    int 10h
    jmp wbnloop
wbnlend:
    ;cursor right
    mov ah, 2h
    inc dl
    int 10h
    jmp typechar
    ;erase character
wbloopstart:
    mov si, di
wbloop:
    inc si
    mov al, [es:si] ;get next character
    dec si
    mov [es:si], al ;move it to current byte
    cmp al, 0h      ;check if file end
    je wbloopend
    inc si          ;go to next byte
    jmp wbloop
wbloopend:
    ret
wenter:
    ;remove spaces before newline, else unexpected behaviour
    dec di
    cmp byte [es:di], 0x20 ;space
    jne wenterspace
    call wbloopstart ;remove space
    jmp wenter ;check if multiple spaces
wenterspace:
    inc di ;due to increase above
    mov al, 0xd
    call wloopstart
    ;di already increased
    call typeline
    mov al, 0xa
    call wloopstart
    cmp dh, 0x18 ;bottom row
    jne wtypend
    mov ax, 0xe0d ;print enter, else bug on last row
    int 10h
    mov al, 0xa
    int 10h
    mov ax, si ;has to be stored for wtypend
    pop si
    call rsiloop
    push si
    mov si, ax
    jmp wtypend
wup:
    ;scroll page up
    pop si
    cmp si, 0h
    je wgetchar
    call rbacksi ;dec si
    push si
    call wupdown
    inc dh
    int 10h
    jmp wgetchar
wdown:
    ;scroll page down
    pop si
    call rsiloop ;inc si
    push si
    call wupdown
    dec dh
    int 10h
    jmp wgetchar
wupdown:
    ;rewrite screen
    push dx
    push di
    mov ah, 2h ;move cursor top left
    xor dx, dx
    int 10h
    mov di, si
    call wtype
    pop di
    pop dx
    mov ah, 2h ;move cursor one line up
    ret
wrowleft:
    ;works like normal home
    push dx
    mov dh, 0h
    sub di, dx
    pop dx
    mov dl, 0h
    mov ah, 2h ;set cursor
    int 10h
    jmp wgetchar
wrowright:
    ;works like normal left
    call wendrow
    jmp wgetchar
wins:
    ;scroll bulk to top
    mov ah, 2h ;move cursor to top left
    xor dx, dx
    int 10h
    pop si
    xor si, si
    xor di, di
    push si
    jmp typechar ;rewrite screen
wdel:
    ;scroll bulk to bottom
    mov dx, fs ;size of buffer for readstart
    call readstart
    mov di, bx ;last char
    jmp wgetchar
whome:
    mov ah, 2h ;move cursor to top left
    xor dx, dx
    int 10h
    pop si
    mov di, si ;set to first byte
    push si
    jmp wgetchar
wend:
    ;move cursor to end  of file
    cmp byte [es:di], 0h ;end of the file
    je wgetchar
    cmp dh, 0x18
    je wendrowstart
    call wright2 ;go to next line
    jmp wend
wendrowstart:
    call wendrow
    jmp wgetchar
wendrow:
    cmp byte [es:di], 0h ;end of file
    je wbloopend
    cmp byte [es:di], 0xd ;newline
    je wbloopend
    cmp dl, 0x4f
    je wbloopend
    inc di
    mov ah, 2h ;set cursor
    inc dl    
    int 10h
    jmp wendrow
wspecial:
    ;type special ascii char
    ;get charcode
    call filenum
    push cx
    mov al, cl
    call wloopstart
    mov ah, 2h ;reset cursor, dx stored in wgetchar
    int 10h
    pop ax ;cl is char
    mov ah, 0xe ;output char
    int 10h
    jmp wtypend
wchar:
    ;display number of the char the cursor is on
    mov cx, di ;di stores the value
    call xtox
    mov ch, cl
    call xtox
    ;char press
    mov ah, 0h
    int 16h
    mov ah, 2h ;reset cursor
    int 10h
    jmp typechar
wcopy:
    ;copy and cut
    push dx ;store
    mov dh, al ;if 7C cut (ascii value for |)
    xor si, si
    cmp byte [gs:si], 0h ;store copy into copy-buffer
    jne wccopy
    pop dx ;take down
    mov byte [gs:si], 1h ;start copying
    inc si
    mov [gs:si], di ;save location of current char
    jmp typechar
wccopy:
    mov byte [gs:si], 0h ;end of copying
    inc si
    mov bx, [gs:si] ;first limit
    mov cx, di ;bx and cx store ends of buffer
    cmp bx, cx
    jle wcsave
    mov ax, cx ;cx should be higher than bx..
    mov cx, bx ;because of cut
    mov bx, ax
wcsave:
    mov al, [es:bx] ;copy chars..
    mov [gs:si], al ;to copy buffer
    cmp dh, 0x7c ;cut
    jne wccon
    ;cut chars by removing from text buffer
    push si
    mov si, bx
    call wbloop ;cut char
    pop si
    cmp bx, cx ;end of buffer
    je wcsavend
    dec cx ;make bx remain stationary due to wbloop
    inc si
    jmp wcsave
wccon:
    cmp bx, cx
    je wcsavend ;all characters copied
    inc bx
    inc si
    jmp wcsave
wcsavend:
    pop cx ;take down dx
    inc si
    mov byte [gs:si], 0h ;end of copy
    cmp dh, 0x7c ;cut
    jne wsendc
    ;due to write page update change in v1.3.4
    mov di, bx
    call new
    pop si
    push si ;get and store
    push cx ;gets changed by wtype
    push di
    mov di, si
    call wtype ;rewrite page
    pop di
    pop cx
    mov bh, 0h
    mov dx, cx ;reset
    mov ah, 2h ;reset cursor
    int 10h
wsendc:
    jmp wgetchar
wpaste:
    mov si, 1h ;where copy string starts
wcsi:
    push si
    mov al, [gs:si]
    cmp al, 0h ;end of copy
    je wpastend
    mov ah, 0xe ;move cursor according to character
    int 10h
    call wloopstart ;write character
    pop si
    inc si
    jmp wcsi
wpastend:
    pop si
    jmp typechar
save:
    pop si ;take down si
    ;set buffer and write
    xor bx, bx ;reset
    mov dl, 0x80   
    pop cx
    ;set ch and dh
    mov ax, fs ;size of buffer = number of files to save
    shr ax, 9h ;/200h
    push ax
    call setfolder
    pop ax
    mov ah, 3h ;write
    int 13h
    jmp input

edit:
    ;edit file
    call read
    push cx ;for write save
    mov cx, bx ;for writeram
    jmp writeram
    
copystart:
    mov di, 0x8080 ;source and destination disk
    jmp copy
jump:
    ;move file between usb and hard disk, only works when booting from usb
    ;get source 0=80h 1=81h
    ;destination will be opposite
    mov ah, 0h
    int 16h
    mov ah, 0xe ;output number
    int 10h
    mov bl, al ;store in bx
    mov bh, bl
    xor bx, 0xb1b0 ;convert from 30h to 80h, and not the first bit of bh
    mov di, bx
copy:
    ;buffer
    mov ax, 0x1200
    mov es, ax
    xor bx, bx
    ;read
    call filenum ;filenum
    push cx
    call filenum ;number of files
    mov al, cl
    mov ah, 2h ;for int 13h 
    pop cx
    push ax
    mov dx, di ;set dl
    shr di, 8h ;get next value for dl
    call setfolder
    pop ax ;set ax
    push ax
    int 13h
    mov ax, 0xe77 ;w = succesfull read
    int 10h
    ;write
    call folder ;set dest folder
    call filenum
    mov dx, di
    call setfolder
    pop ax ;same number
    inc ah
    int 13h
    jmp input   

;CALCULATOR
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
    mov bl, 0h ;counter
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
    ;print
    mov ah, 0xe
    call xtoasc ;convert into ascii
    int 10h
    pop ax
    mul cx ;multiply quotient by divisor
    mov dx, ax
    pop ax
    sub ax, dx ;"long division" subtraction
    mov dx, ax
    inc bl
    cmp bl, 4h ;4 digits
    jne kfloop
    jmp input ;answer outputted
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
    mov al, 0x30 ;end of result
    push ax
    ;get 4-digit hex
    call filenum
    mov bh, cl ;store value
    call filenum
    call enter
    mov bl, cl
    mov ax, bx
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
    add ax, 0xe30 ;printable, ah was=0
    int 10h
    jmp hend

xdec:
    ;convert dec to hex
    mov al, 0x30 ;end of ans
    push ax
    mov dx, 0x2710 ;mul 10000
    xor bx, bx ;answer
    mov cx, 0xa ;dx ax / cx
    xor si, si ;counter
xget:
    ;get number
    mov ah, 0h
    int 16h
    ;print
    mov ah, 0xe
    int 10h
    mov ah, 0h
    sub al, 30h
    push dx ;save while mul
    mul dx
    add bx, ax ;store answer in bx
    ;div dx 10
    pop dx
    mov ax, dx
    xor dx, dx ;divide dx by 10, since in the next digit x will be one less in 10^x.
    div cx
    mov dx, ax
    inc si
    cmp si, 5h ;5 digit number
    jne xget
    mov cx, 0x10 ;div
    mov ax, bx ;answer in bx
xconv:
    xor dx, dx
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

real:
    ;convert hex float to dec
    call filenum
    mov bh, cl
    call filenum ;float in ax
    mov bl, cl
    push bx
    mov cl, 0h ;counter
    mov bx, 0xa ;10 is multiplier
    call enter
    mov al, 0x2e ;.
    int 10h
    pop ax
realoop:
    mul bx      ;by solving for x in the ratio equation (x/10=y/16)..
    push ax     ;where y is the upper most nibble in ax (the inputted float value)..
    mov al, dl  ;you can convert a hexadecimal float to decimal float -> x=(y*10)/16..
    add al, 30h ;you don't have to divide by 16, since the quotient will still be the same as in dl
    mov ah, 0xe
    int 10h ;print value
    pop ax
    inc cl
    cmp cl, 0x6 ;decimal points precision
    jne realoop
    jmp input

info: 
    ;pikobrain dir/ls command 
    ;ouput folder number hex
    mov ax, 0x1000
    mov fs, ax
    mov si, 0x13fd
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
    xor di, di ;counter
    ;get file info in folder
    ;buffer
    mov ax, 0x1200
    mov es, ax
    xor bx, bx
    ;other stuff
    mov cl, 1h ;changes later
    call setfolder
    mov dl, 0x80
    mov ax, 0x201
    int 13h ;read
iloop:
    and cl, 0x3f ;cear upper bits (due to setfolder)
    mov al, [es:bx]
    cmp al, 0h ;is empty?
    je ilend
    ;output filenum
    mov ch, cl
    call xtox
    mov ax, 0xe2e ;.
    mov bx, 0x1ff
    cmp byte [es:bx], 0h ;check if file is full
    je iskip
    mov al, 0x3a ;: use different char
iskip:
    xor bx, bx ;reset
    int 10h ;output char
    mov ch, 0h ;char counter
iwloop:
    ;write chars
    mov al, [es:bx]
    cmp al, 0x20 ;space, to not print weird chars
    jge iw
    mov al, 0x2a ;*
iw:
    mov ah, 0xe ;print char
    int 10h
    inc bl
    inc ch
    cmp ch, 0xa ;10 characters
    jne iwloop
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
    mov bl, 0h
    int 13h
    ;check di
    cmp di, 5h ;x columns
    je idi3 
    jmp iloop
idi3:
    xor di, di
    jmp iloop

zero:
    ;erases file in folder
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
    xor bx, bx
    mov dl, 80h
    mov cl, 1h
zloop:   
    ;read
    call setfolder
    mov ax, 0x201
    int 13h
    and cl, 0x3f ;clear upper bits, since else will be wrong next time calling setfolder
zread:
    mov al, [es:bx]
    cmp al, 0h ;file is already "empty"
    je zend
    mov byte [es:bx], 0h ;set as 0h, since if the first byte is a 0h the file is "empty"
    ;save file
    call setfolder
    ;write
    mov ax, 0x301
    int 13h
    and cl, 0x3f ;clear upper bits
zend:
    inc cl
    cmp cl, 0x40 ;end of folder
    jne zloop
    jmp input

search:
    ;search for string in files in folder
    mov ax, 0x1160 ;buffer location
    mov gs, ax
    xor di, di ;gs:di search word
sword:
    ;get char
    mov ah, 0h
    int 16h
    cmp al, 8h ;backspace
    jne swordcon
    dec di
    mov byte [gs:di], 0h
    mov ah, 0xe
    int 10h
    mov ax, 0xa20 ;space
    int 10h
    jmp sword
swordcon:
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
    xor bx, bx
    mov cl, 1h ;will change
sloop:
    call setfolder
    xor di, di ;reset
    ;read
    mov dl, 80h
    xor bx, bx ;must be here! reset
    mov ax, 0x201
    int 13h
    and cl, 0x3f ;clear upper bits
scomp:
    mov al, [es:bx] ;get char from file..
    cmp al, 0h ;end of file
    je sfile
    mov dl, [gs:di] ;compare with search word
    cmp dl, 0xd ;end of search word
    je sfind
    cmp al, dl
    jne snot ;not equal words
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
    cmp bx, 0x200 ;check if file end
    jge sfile
    xor di, di ;reset
    jmp scomp
sfile:
    inc cl
    cmp cl, 0x40
    je input
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
    ;read files
    ;buffer
    mov ax, 0x1a00
    mov gs, ax ;gs:di writes machine opcodes
    xor di, di
    call readfiles
    xor si, si ;fs:si stores labels and jmp
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
    cmp dl, 0x4e ;mov [--:--]
    jl aMS
    jmp aerror
aMN:
    ;MOV NUMBER
    mov dl, 0xb0 ;opcode for MN
    jmp amregstart
aMR:
    ;MOV REGISTER
    mov dh, 0x88 ;opcode for MR (or 89)
    jmp acombstart
aMS:
    dec bx ;due to aloop
    mov al, [es:bx] ;get char
    cmp dl, 0x41 ;MA
    je aMA
    cmp dl, 0x45 ;ME
    je aME
    cmp dl, 0x46 ;MF
    je aMF
    cmp dl, 0x47 ;MG
    je aMG
    jmp aerror
aMA:
    ;char in al
    cmp al, 0x45 ;MAE
    je aMAE
    cmp al, 0x46 ;MAF
    je aMAF
    cmp al, 0x47 ;MAG
    je aMAG
    jmp aerror
aMAE:
    mov byte [gs:di], 0x26
    inc di
    mov word [gs:di], 0x078a
    inc di
    jmp acend
aMAF:
    mov byte [gs:di], 0x64
    inc di
    mov word [gs:di], 0x048a
    inc di
    jmp acend
aMAG:
    mov byte [gs:di], 0x65
    inc di
    mov word [gs:di], 0x058a
    inc di
    jmp acend
aME:
    cmp al, 0x45 ;mov es, ax
    je aMEE
    cmp al, 0x41 ;mov [es:bx], al
    je aMEA
    jmp aerror
aMEE:
    mov word [gs:di], 0xc08e
    inc di
    jmp acend
aMEA:
    mov byte [gs:di], 0x26
    inc di
    mov word [gs:di], 0x0788
    inc di
    jmp acend
aMF:
    cmp al, 0x46 ;mov fs, ax
    je aMFF
    cmp al, 0x41 ;mov [fs:si], al
    je aMFA
    jmp aerror
aMFF:
    mov word [gs:di], 0xe08e
    inc di
    jmp acend
aMFA:
    mov byte [gs:di], 0x64
    inc di
    mov word [gs:di], 0x0488
    inc di
    jmp acend
aMG:
    cmp al, 0x47 ;mov gs, ax
    je aMGG
    cmp al, 0x41 ;mov [gs:di], al
    je aMGA
    jmp aerror
aMGG:
    mov word [gs:di], 0xe88e
    inc di
    jmp acend
aMGA:
    mov byte [gs:di], 0x65
    inc di
    mov word [gs:di], 0x0588
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
    jmp aregstart2
aZL:
    mov dx, 0xc0e0
    mov ch, 1h
    cmp al, 0x58 ;X
    je aZQX
    jmp aregstart2
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
    jmp aregstart2
aQL:
    mov dx, 0xc0c0
    mov ch, 1h
    cmp al, 0x58 ;X
    je aZQX
    jmp aregstart2
aZQX:
    ;Z and Q will take 8 bit argument even if 16 bit register
    dec ch ;will end up as 1h = 1 byte
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
    ;aregstart is for [mne] [reg], [imm8/16]
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
    ;amregstart is for mov, [reg], [imm8/16]    
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
    cmp dl, 0x49 ;I
    je aGI
    cmp dl, 0x4f ;O
    je aGO
    jmp aerror
aGI:
    ;IN
    mov byte [gs:di], 0xe4
    jmp a1b
aGO:
    ;OUT
    mov byte [gs:di], 0xe6
    jmp a1b
aF:
    mov byte [gs:di], 0xe8 ;call
    jmp aJMP
aR: 
    mov byte [gs:di], 0xc3 ;ret
    jmp acend
aW:
    ;macros, using pikobrain functions
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
    cmp al, 0x47 ;readfiles Getfiles
    je aWG
    cmp al, 0x48 ;xtoasc Hex
    je aWH
    cmp al, 0x4e ;fileNum
    je aWN
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
    add cx, readfiles
    jmp aWend
aWH:
    add cx, xtoasc
    jmp aWend
aWN:
    add cx, filenum
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
    sub cx, 2h
    mov word [gs:di], cx
    inc di
    jmp acend
aJ:
    inc bx
    mov al, [es:bx]
    cmp al, 0x4d ;M
    je aJM
    cmp al, 0x46 ;F
    je aJF
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
    cmp al, 0x42 ;Below
    je aJB
    cmp al, 0x4f ;Overflow
    je aJO
    cmp al, 0x53 ;Signed
    je aJS
    cmp al, 0x50 ;Parity
    je aJP
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
aJS:
    mov byte [gs:di], 0x88
    jmp aJMP
aJP:
    mov byte [gs:di], 0x8a
    jmp aJMP
aJM:
    mov byte [gs:di], 0xe9 ;jmp
aJMP:
    call askip
    mov ax, 0x2000 ;fs:si stores jmp statements
    mov fs, ax
    inc di ;where machine code will be written
    mov ax, di
    inc di ;to be correct later
    mov [fs:si], ax ;store bin location 
    add si, 2h 
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
    inc si
    jmp acend
aJF:
    ;far jump
    mov byte [gs:di], 0xea
    jmp a4b
aLabel:
    mov ax, 0x2800 ;fs:si stores labels
    mov fs, ax
    mov dx, si ;store for later
    pop si ;the si for 0x2800 is stored on stack
    mov cx, di ;store for later (dx=si, cx=di)
    inc bx ;get passed the 1st "." in label name
aLabell:
    ;store label name
    mov al, [es:bx] ;current char
    mov [fs:si], al ;store
    cmp byte [es:bx], 0x2e ;. ;end of label name
    je aLabelend
    inc si
    inc bx
    jmp aLabell
aLabelend:
    ;store memory location of label
    inc si
    mov [fs:si], cx
    add si, 2h
    push si
    mov si, dx ;return to normal
    inc bx
    jmp aconv 
aE:
    ;end of program
    mov dword [gs:di], 0x16cd00b4
    add di, 4h
    mov byte [gs:di], 0xea ;jmp seg:off
    inc di
    mov dword [gs:di], 0x10000200 ;cs does not change
    add di, 3h
    jmp acend
aComment:
    ;commenting
    inc bx
    cmp byte [es:bx], 0xd ;newline = end of comment
    jne aComment
    jmp aconv
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
    call agetbyte
    push ax
    call agetbyte
    push ax
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
    call enter
    mov ch, bh
    call xtox
    mov ch, bl
    call xtox
    mov ax, 0xe65 ;e
    int 10h
    ;will still save
asave:
    ;add jumps to machine code
    mov ax, 0x2000
    mov fs, ax
    mov word [fs:si], 0h ;end of list
    mov ax, 0x2800
    mov fs, ax
    pop si
    mov byte [fs:si], 0h ;end of list
    mov es, ax ;label list (es:bx)
    xor bx, bx
    mov ax, 0x2000 ;jmp list (fs:si)
    mov fs, ax
    xor si, si
asaveloop:
    mov cx, [fs:si] ;jmp statement location, cannot be at 0000 (start of file)..
    cmp cx, 0h      ;as that is same as end of list
    je awrite
    add si, 2h
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
    cmp byte [es:bx], 0x2e ;. end of name
    je ascend
    cmp byte [es:bx], 0h ;label not found
    je alerror
    inc bx
    jmp ascompend
ascend:
    pop si
    add bx, 3h ;es:bx on dot, must jump past location value
    jmp ascomp
ascompeq:
    inc bx
    mov dx, [es:bx] ;label location
    sub dx, cx ;calculate jump length
    sub dx, 2h ;remove yet 2 because of how jumps apparently work
    mov bx, cx
    mov [gs:bx], dx ;store jump length, must use bx
    inc bx
    ;set values
    pop ax ;take down si
    inc si
    xor bx, bx
    jmp asaveloop
alerror:
    ;label error
    pop si ;take down
    ;output the location in source code
    call enter
    mov ch, bh
    call xtox
    mov ch, bl
    call xtox
    mov ax, 0xe4c ;L
    int 10h
awrite:
    mov ax, 0xe61 ;Assembled
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
    mov ah, 3h
    inc al ;because of shr
    mov dl, 80h
    int 13h
    call enter
    jmp input

run:
    ;run user program
    ;read files
    call readfiles
    jmp 0x1000:0x2000 ;location of program machine code  


    ;fill space to make divisible by 512
    times 5117-($-$$) db 0h
    db 0h ;upper 2 bits cl -- track
    dw 0h ;0x1000:0x13ff -- hd head/track

;commands to assemble and make into flp file linux + NASM
;nasm -f bin -o myfirst.bin myfirst.asm
;dd status=noxfer conv=notrunc if=myfirst.bin of=myfirst.flp
;to place onto USB:
;sudo dd if=piko.bin of=/dev/sdb
