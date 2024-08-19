	.text
	.align	2
	.global	main
	.code	16
	.thumb_func
	.type	main, %function

	.equ REG_BASE, 		0x04000000
	.equ PLTT,		0x05000000
	.equ VRAM,		0x06000000
	.equ RANDOM,		0x02000000
	.equ TILE_SIZE,		0x20
	.equ TOTAL_TILE,	0x4
	.equ DISPLAY_WIDTH,	240
	.equ DISPLAY_HEIGHT,	160
	.equ APPLE_LOC_X,	0x02020000
	.equ APPLE_LOC_Y,	0x02020004

main:
	push {r0, lr}
	bl .enable_bg
	bl .load_pal
	bl .load_all_tile
	bl .render_walls
	bl .random_seed
	bl .spawn_apple
.loop:
	@ ;;;;;;;;;;;;;;MAIN GAME;;;;;;;;;;;;;;;
	b .loop

@ // enable BG0 and set its properties
.enable_bg:
	push {r0-r1, lr}
	ldr r0, .DISPCNT
	ldr r1, = (0 | (1 << 8))
	strh r1, [r0]
	ldr r0, .BG0CNT
	ldr r1, = (8 << 8)
	strh r1, [r0]
	pop {r0-r1, pc}

.text
.align	2
	.DISPCNT: 	.word REG_BASE + 0x0
	.BG0CNT: 	.word REG_BASE + 0x8

@ // load color palette for snake walls and apple
.load_pal:
	push {r0-r4, lr}
	ldr r0, .PALETTE
	ldr r1, .CLR_WHITE
	ldr r2, .CLR_RED
	ldr r3, .CLR_BLUE
	ldr r4, .CLR_GREEN
	strh r1, [r0]
	strh r2, [r0, #2]
	strh r3, [r0, #4]
	strh r4, [r0, #6]
	pop {r0-r4, pc}

.text
.align	2
	.PALETTE: 	.word PLTT + 0x2
	.CLR_WHITE:	.word (31 | (31 << 5) | (31 << 10))
	.CLR_RED:	.word (28 | (10 << 5) | (10 << 10))
	.CLR_BLUE:	.word (10 | (28 << 5) | (10 << 10))
	.CLR_GREEN:	.word (10 | (10 << 5) | (28 << 10))

@ // load number of tiles specified
.load_all_tile:
	push {r0, lr}
	mov r0, #0
	.load_tile_loop:
		add r0, r0, #1
		bl .load_single_tile
		cmp r0, #TOTAL_TILE
		bne .load_tile_loop
	pop {r0, pc}

@ // load 8x8 tile based on value of first arg
.load_single_tile:
	push {r0-r5, lr}
	mov r5, r0
	lsl r1, r0, #4
	lsl r2, r0, #8
	lsl r3, r0, #12
	orr r0, r1
	orr r0, r2
	orr r0, r3
	lsl r1, r0, #8
	orr r0, r1
	lsl r1, r0, #8
	orr r0, r1
	mov r2, #(TILE_SIZE / 4)
	ldr r1, .VRAM_TILE
	mov r4, #TILE_SIZE
	mul r5, r4
	add r1, r1, r5
	.single_tile_loop:
		str r0, [r1]
		add r1, r1, #4
		sub r2, r2, #1
		cmp r2, #0
		bne .single_tile_loop
	pop {r0-r5, pc}

.text
.align	2
	.VRAM_TILE: 	.word VRAM

@ // render tile on screen based on x, y and index
.render_tile:
	push {r0-r3, lr}
	ldr r3, .VRAM_BG0
	lsl r0, r0, #1
	lsl r1, r1, #6
	add r0, r0, r1
	add r0, r0, r3
	strh r2, [r0]
	@bl __aeabi_idiv
	pop {r0-r3, pc}

.text
.align	2
	.VRAM_BG0: 	.word VRAM + 0x4000

@ // render wall on screen border
.render_walls:
	push {r0-r2, lr}
	mov r0, #0
	mov r1, #0
	mov r2, #3
	.render_walls_loop:
		cmp r1, #0
		beq .put_tile
		cmp r1, #((DISPLAY_HEIGHT / 8) - 1)
		beq .put_tile
		cmp r0, #0
		beq .put_tile
		cmp r0, #((DISPLAY_WIDTH / 8) - 1)
		bne .incr_counter
		.put_tile:
		bl .render_tile
		.incr_counter:
			add r0, r0, #1
			cmp r0, #(DISPLAY_WIDTH / 8)
			bne .render_walls_loop
			mov r0, #0
			add r1, r1, #1
			cmp r1, #(DISPLAY_HEIGHT / 8)
			bne .render_walls_loop
	pop {r0-r2, pc}

@ // generate random values
.random_seed:
	push {r0, lr}
	ldr r0, .RANDOM_VAL
	ldr r1, [r0]
	ldr r2, .SEED
	add r1, r1, r2
	str r1, [r0]
	pop {r0, pc}

@ // get 16bit random value
.get_random_16:
	push {lr}
	ldr r0, .RANDOM_VAL
	ldrh r0, [r0]
	pop {r1}
	bx r1

@ // get 8bit random value
.get_random_8:
	push {lr}
	ldr r0, .RANDOM_VAL
	ldrb r0, [r0]
	pop {r1}
	bx r1

.text
.align	2
	.RANDOM_VAL: 	.word RANDOM
	.SEED:		.word 0xF52AFC39

@ // spawn apple tile
.spawn_apple:
	push {r0-r3, lr}
	ldr r0, .APPLE_X
	ldr r1, .APPLE_Y
	mov r2, #0
	bl .render_tile

	bl .get_random_8
	mov r1, #((DISPLAY_WIDTH / 8) - 2)
	bl __aeabi_uidivmod
	add r1, r1, #1
	push {r0}
	bl .get_random_8
	mov r1, #((DISPLAY_HEIGHT / 8) - 2)
	bl __aeabi_uidivmod
	mov r1, r0
	add r1, r1, #1
	pop {r0}
	mov r2, #2
	bl .render_tile
	pop {r0-r3, pc}

.text
.align	2
	.APPLE_X: 	.word APPLE_LOC_X
	.APPLE_Y:	.word APPLE_LOC_Y
