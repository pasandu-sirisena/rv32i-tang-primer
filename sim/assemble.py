import sys

def assemble(lines_src):
    labels = {}
    cleaned = []
    pc = 0
    for line in lines_src:
        line = line.split('#')[0].strip()
        if not line: continue
        if line.endswith(':'):
            labels[line[:-1].strip()] = pc
        else:
            cleaned.append((pc, line))
            if line.startswith('.word') or line.startswith('.string'):
                if line.startswith('.string'):
                    s = line[len('.string'):].strip().strip('"').encode('ascii').decode('unicode_escape').encode('latin1') + b'\x00'
                    while len(s) % 4 != 0: s += b'\x00'
                    pc += len(s)
                else:
                    pc += 4
            else:
                pc += 4

    def reg(r):
        r = r.strip()
        if r.startswith('x'): return int(r[1:])
        if r == 'zero': return 0
        raise ValueError(f'Unknown reg {r}')

    def lui(rd, imm): return f'{((imm & 0xFFFFF) << 12) | (rd << 7) | 0x37:08X}'
    def addi(rd, rs, imm): return f'{((imm & 0xFFF) << 20) | (rs << 15) | (0 << 12) | (rd << 7) | 0x13:08X}'
    def slli(rd, rs, shamt): return f'{(shamt << 20) | (rs << 15) | (1 << 12) | (rd << 7) | 0x13:08X}'
    def srli(rd, rs, shamt): return f'{(shamt << 20) | (rs << 15) | (5 << 12) | (rd << 7) | 0x13:08X}'
    def andi(rd, rs, imm): return f'{((imm & 0xFFF) << 20) | (rs << 15) | (7 << 12) | (rd << 7) | 0x13:08X}'
    def lw(rd, rs, imm): return f'{((imm & 0xFFF) << 20) | (rs << 15) | (2 << 12) | (rd << 7) | 0x03:08X}'
    def lbu(rd, rs, imm): return f'{((imm & 0xFFF) << 20) | (rs << 15) | (4 << 12) | (rd << 7) | 0x03:08X}'
    def sw(rs2, rs1, imm):
        imm = imm & 0xFFF
        return f'{(((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((imm & 0x1F) << 7) | 0x23:08X}'
    def beq(rs1, rs2, off):
        imm = off & 0x1FFE
        return f'{(((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (0 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63:08X}'
    def bne(rs1, rs2, off):
        imm = off & 0x1FFE
        return f'{(((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (1 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63:08X}'
    def jal(rd, off):
        imm = off & 0x1FFFFF
        return f'{(((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F:08X}'

    hex_words = []
    for cur_pc, line in cleaned:
        tokens = line.replace(',', ' ').replace('(', ' ').replace(')', ' ').split()
        op = tokens[0]
        if op == '.string':
            s = line[len('.string'):].strip().strip('"').encode('ascii').decode('unicode_escape').encode('latin1') + b'\x00'
            while len(s) % 4 != 0: s += b'\x00'
            for i in range(0, len(s), 4):
                w = s[i] | (s[i+1] << 8) | (s[i+2] << 16) | (s[i+3] << 24)
                hex_words.append(f'{w:08X}')
            continue
        elif op == '.word':
            val = int(tokens[1], 0)
            hex_words.append(f'{val:08X}')
            continue

        if op == 'lui': hex_words.append(lui(reg(tokens[1]), int(tokens[2], 0)))
        elif op == 'addi':
            imm = labels[tokens[3]] if tokens[3] in labels else int(tokens[3], 0)
            hex_words.append(addi(reg(tokens[1]), reg(tokens[2]), imm))
        elif op == 'slli': hex_words.append(slli(reg(tokens[1]), reg(tokens[2]), int(tokens[3], 0)))
        elif op == 'srli': hex_words.append(srli(reg(tokens[1]), reg(tokens[2]), int(tokens[3], 0)))
        elif op == 'andi': hex_words.append(andi(reg(tokens[1]), reg(tokens[2]), int(tokens[3], 0)))
        elif op == 'lw': hex_words.append(lw(reg(tokens[1]), reg(tokens[3]), int(tokens[2], 0)))
        elif op == 'lbu': hex_words.append(lbu(reg(tokens[1]), reg(tokens[3]), int(tokens[2], 0)))
        elif op == 'sw': hex_words.append(sw(reg(tokens[1]), reg(tokens[3]), int(tokens[2], 0)))
        elif op == 'beq':
            target = labels[tokens[3]] if tokens[3] in labels else (cur_pc + int(tokens[3], 0))
            hex_words.append(beq(reg(tokens[1]), reg(tokens[2]), target - cur_pc))
        elif op == 'bne':
            target = labels[tokens[3]] if tokens[3] in labels else (cur_pc + int(tokens[3], 0))
            hex_words.append(bne(reg(tokens[1]), reg(tokens[2]), target - cur_pc))
        elif op == 'jal':
            target = labels[tokens[2]] if tokens[2] in labels else (cur_pc + int(tokens[2], 0))
            hex_words.append(jal(reg(tokens[1]), target - cur_pc))
        else:
            raise ValueError(f'Unknown op {op}')

    return hex_words, labels

assembly = '''
_start:
    lui x1, 0x10000
    lui x2, 0x20000
    
    addi x3, zero, 1
    sw x3, 0(x2)
    
    addi x4, zero, banner_msg
print_banner:
    lbu x5, 0(x4)
    beq x5, zero, banner_done
uart_wait_tx:
    lw x6, 4(x1)
    andi x6, x6, 1
    bne x6, zero, uart_wait_tx
    sw x5, 0(x1)
    addi x4, x4, 1
    jal zero, print_banner

banner_done:
    addi x3, zero, 1
    addi x9, zero, 0

chaser_loop:
    sw x3, 0(x2)

    lui x7, 0x0B0
delay_loop:
    addi x7, x7, -1
    bne x7, zero, delay_loop

    bne x9, zero, shift_right

shift_left:
    slli x3, x3, 1
    addi x10, zero, 32
    bne x3, x10, chaser_next
    addi x9, zero, 1
    jal zero, chaser_next

shift_right:
    srli x3, x3, 1
    addi x10, zero, 1
    bne x3, x10, chaser_next
    addi x9, zero, 0

chaser_next:
    jal zero, chaser_loop

banner_msg:
    .string "\\r\\n\\r\\nTang Primer 20K RV32IM CPU Online\\r\\n\\r\\n"
'''

words, lbls = assemble(assembly.strip().split('\n'))

with open('rtl/firmware.hex', 'w') as f:
    for w in words:
        f.write(w + '\n')
