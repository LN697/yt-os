org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

; FAT12 header

jmp short start
nop

bdb_oem:					db 'MSWIN4.1'
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:				db 2
bdb_dir_entries_count:		dw 0E0h
bdb_total_sectors:			dw 2880	; 1.44MB
bdb_media_descriptor_type:	db 0F0h	; 3.5" floppy disk
bdb_sectors_per_fat:		dw 9
bdb_sectors_per_track:		dw 18
bdb_heads:					dw 2
bdb_hidden_sectors:			dd 0
bdb_large_sector_count:		dd 0

; extended boot record
ebr_drive_number:			db 0
ebr_reserved:				db 0
ebr_signature:				db 29h
ebr_volume_id:				dd 0
ebr_volume_label:			db 'YouTube OS '
ebr_system_id:				db 'FAT12   '


; Code goes here

start:
	jmp main

; Prints a string to the screen
; Params:
;	ds:di = points to a string

puts:
	; save registers to be modified
	push si
	push ax

.loop:
	lodsb
	or al, al
	jz .done
	
	mov ah, 0x0e
	mov bh, 0
	int 0x10

	jmp .loop

.done:
	pop ax
	pop si
	ret


main:
	; setup DS
	mov ax, 0
	mov ds, ax
	mov es, ax

	; setup SS
	mov ss, ax
	mov sp, 0x7c00

	; read sectors
	mov [ebr_drive_number], dl
	mov ax, 1
	mov cl, 1
	mov bx, 0x7E00
	call disk_read

	; print message
	mov si, msg_hello
	call puts
	
	hlt

floppy_error:
	mov si, floppy_error_msg
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h
	jmp 0FFFFh:0

.halt:
	cli
	hlt
	jmp .halt


; Disk routines


; Converts a LBA address to a CHS address
; Params:
;	ax = LBA address
; Returns:
;	dh = head
;	cx [bits 0-5] = sector number
;	cx [bits 6-15] = cylinder number

lba_to_chs:
	push ax
	push dx

	xor dx, dx
	div word [bdb_sectors_per_track]
	inc dx
	mov cx, dx
	xor dx, dx
	div word [bdb_heads]
	mov dh, dl
	mov ch, al
	shl al, 6
	or cl, ah

	pop ax
	mov dl, al
	pop ax
	ret

; Read sectors from a disk
; Params:
;	dl = drive number
;	cl = number of sectors to read upto 128
;	ax = LBA address
;	es:bx = buffer to read into

disk_read:
	push ax
	push bx
	push cx
	push dx
	push di

	push cx
	call lba_to_chs
	pop ax

	mov ah, 02h
	mov di, 3

.retry:
	pusha
	stc
	int 13h
	jc .done

	; read failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	jmp floppy_error

.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

; Reset the floppy disk
; Params:
;	dl = drive number

disk_reset:
	pusha
	mov ah, 00h
	stc
	int 13h
	jc floppy_error
	popa
	ret

msg_hello: db 'Hello, world!', ENDL, 0
floppy_error_msg: db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
