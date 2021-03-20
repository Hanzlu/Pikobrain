	BITS 16

;***********
;BOOTLOADER
;***********

;using this program, and booting from this program using a USB
;will install the files that you sepcify by altering the values
;in the code where comments has been placed.

;this is currently the only method of getting files into Pikobrain from other machines.
;will not work on VirtualBox as easily, but has been tested and works on real hardware.

bootloader:
    ;set up registers
	mov ax, 0x9c0
	mov ss, ax
    mov ax, 0x7c0
    mov ds, ax
	mov sp, 0x1000
    

    ;READ FILE TO INSTALL
    mov ax, 0x1200
    mov es, ax
    mov bx, 0h
    mov ax, 0x201 ;01 = number of files
    mov cx, 0x2   ;2  = location on disk (USB) (0x1 = this file)
    mov dx, 0x80
    int 13h
    
    mov ax, 0x301 ;01 = number of files
    mov cx, 0x35  ;35 = location on disk (Hard Disk) (this value can be changed depending on where an empty file is in your 'home' folder)
    mov dx, 0x81
    int 13h

    mov ax, 0xe2e ;.
    int 10h
    jmp $

    ;fill up space
    times 510-($-$$) db 0h
    dw 0xAA55

;linux commands to use installer:
;nasm -f bin -o install.bin install.asm (where install.asm is this file)
;cat yourfile >> install.bin (where yourfile is whatever file (with extension) that you wish to install, and install.bin is the file created by the last command)
;you are now able to place the install.bin file onto a USB similar to placing piko.bin on a USB, and booting from that.
;you shall see a dot when the installation of your files have been done. 
