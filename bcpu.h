#ifndef __BCPU_H__
#define __BCPU_H__

#include <stdint.h>
#include "bdecode.h"

#define PC_SUPERVISOR   0x80000000
#define ISR_RESET       (PC_SUPERVISOR | 0x00000000)
#define ISR_ILLOP       (PC_SUPERVISOR | 0x00000004)
#define ISR_CLK         (PC_SUPERVISOR | 0x00000008)
#define ISR_KBD         (PC_SUPERVISOR | 0x0000000C)
#define ISR_MOUSE       (PC_SUPERVISOR | 0x00000010)

/* Interrupt flags in 'pending_interrupts' */
#define INT_CLK         0x0001
#define INT_KBD         0x0002
#define INT_MOUSE       0x0004

#define set_interrupt(cpu, i)   ({(cpu)->pending_interrupts |= (i);})
#define clear_interrupt(cpu, i) ({(cpu)->pending_interrupts &= ~(i);})


#define XP 30

typedef struct {
    /* This layout is hard-coded into bt.S */
    uint32_t regs[32];
    uint32_t PC;
    uint32_t halt;
    uint32_t *memory;
    uint32_t memsize;
    uint32_t segment;
    uint32_t pending_interrupts;
    uint32_t inst_count;
    uint32_t opcode_counts[256];
} beta_cpu;

/*
 * We address memory by words, internally, but the beta uses
 * byte-addressing, even though it only supports aligned access
 */
#define BYTE2WORDADDR(addr) ((addr) >> 2)
#define WORD2BYTEADDR(addr) ((addr) << 2)

/* Typedefs to hopefully make it clear which we're using */
typedef uint32_t byteptr;
typedef uint32_t wordptr;

extern "C" void bcpu_process_interrupt(beta_cpu *cpu);
void bcpu_execute_one(beta_cpu *cpu, bdecode *decode);
void bcpu_reset(beta_cpu *cpu);
void bcpu_step_one(beta_cpu *cpu);

static uint32_t beta_read_mem32(beta_cpu *cpu, byteptr addr) __attribute__((always_inline));
static void beta_write_mem32(beta_cpu *cpu, byteptr addr, uint32_t val) __attribute__((always_inline));

static inline uint32_t beta_read_mem32(beta_cpu *cpu, byteptr addr) {
    if((addr & ~PC_SUPERVISOR) >= cpu->memsize) {
        panic("Illegal memory reference %08x", addr);
    }
    return cpu->memory[BYTE2WORDADDR(addr & ~PC_SUPERVISOR)];
}

static inline void beta_write_mem32(beta_cpu *cpu, byteptr addr, uint32_t val) {
    if((addr & ~PC_SUPERVISOR) >= cpu->memsize) {
        panic("Illegal memory write %08x", addr);
    }
    cpu->memory[BYTE2WORDADDR(addr & ~PC_SUPERVISOR)] = val;
}

#endif
