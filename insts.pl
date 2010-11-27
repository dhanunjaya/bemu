use strict;
use warnings;
use List::Util qw(max);

my %arith = (   # imm, r   imm, r/m      r, r/m       r/m, r
    add     =>  [ undef,   [0x81, 0],    0x01,        0x03   ],
    and     =>  [ undef,   [0x81, 4],    0x21,        0x23   ],
    cmp     =>  [ undef,   [0x81, 7],    0x39,        0x3B   ],
    lea     =>  [ undef,   undef,        undef,       0x8D   ],
    mov     =>  [ 0xB8,    [0xC7, 0],    0x89,        0x8B   ],
    or      =>  [ undef,   [0x81, 1],    0x09,        0x0B   ],
    sub     =>  [ undef,   [0x81, 5],    0x29,        0x2B   ],
    test    =>  [ undef,   [0xF7, 0],    0x85,        undef  ],
    xor     =>  [ undef,   [0x81, 6],    0x31,        0x33   ]
   );

sub h($) {sprintf "0x%02x", shift}

print <<END_WARNING;
/***********************************************************************
 * This file is AUTOMATICALLY GENERATED. Do not edit
 * This file is produced by the script `insts.pl'
 ***********************************************************************/
END_WARNING

if (($ARGV[0]||"") eq "-cxx") {
    sub line {
        printf '   typedef %-17s %s;'."\n", $_[0], $_[1];
    }
    sub no_opcode {
        line('no_opcode', $_[0]);
    }
    sub has_opcode {
        line((sprintf 'has_opcode<0x%x>', $_[0]), $_[1]);
    }
    sub one {
        my $name = shift;
        my $opc = shift;
        if ($opc) {
            has_opcode($opc, "op_$name");
        } else {
            no_opcode("op_$name");
        }
    }
    sub pair {
        my $name = shift;
        my $opc = shift;
        if ($opc) {
            has_opcode($opc->[0], "op_$name");
            has_opcode($opc->[1], "subop_$name");
        } else {
            no_opcode("op_$name");
            no_opcode("subop_$name");
        }
    }
    while (my ($mnm, $opc) = each %arith) {
        print "struct X86" . ucfirst$mnm . " {\n";
        one("imm_r", shift @$opc);
        pair("imm_rm", shift @$opc);
        one("r_rm", shift @$opc);
        one("rm_r", shift @$opc);
        print "};\n\n";
    }
    exit 0;
}

while (my ($mnm, $opc) = each %arith) {
    header(uc $mnm);
    
    my $imm_r = shift @$opc;
    if(defined $imm_r) {
        opcode($mnm, "imm32", "r32", ["dst"] => sub {
                   byte(h($imm_r) . "+dst");
               });
    }
    
    my $imm_rm = shift @$opc;
    if(defined $imm_rm) {
        my ($base, $ext) = @$imm_rm;
        opcode($mnm, "imm32", "rm32", [qw(mod reg)] => sub {
                   byte(h $base);
                   modrm('mod', h $ext, 'reg');
               });
    }
    
    my $r_rm = shift @$opc;
    if(defined $r_rm) {
        opcode($mnm, "r32", "rm32", [qw(src mod reg)] => sub {
                   byte(h $r_rm);
                   modrm('mod', 'src', 'reg');
               });
    }
    my $rm_r = shift @$opc;
    if(defined $rm_r) {
        opcode($mnm, "rm32", "r32", [qw(mod reg dst)] => sub {
                   byte(h $rm_r);
                   modrm('mod', 'dst', 'reg');
               });
    }
}

my %shifts = ( # CL            imm8
    shl =>      [[0xD3, 4],    [0xC1, 4]],
    shr =>      [[0xD3, 5],    [0xC1, 5]],
    sar =>      [[0xD3, 7],    [0xC1, 7]],
    );

while(my ($mnm, $spec) = each %shifts) {
    my $cl = shift @$spec;
    my ($opc, $reg) = @$cl;
    opcode($mnm, 'cl', 'rm32', [qw(mod reg)] => sub {
               byte(h $opc);
               modrm('mod', $reg, 'reg');
           });
    my $imm = shift @$spec;
    ($opc, $reg) = @$imm;
    opcode($mnm, 'imm8', 'rm32', [qw(mod reg)] => sub {
               byte(h $opc);
               modrm('mod', $reg, 'reg');
           });
}

header ('imul');

opcode('imul', 'rm32', 'r32', [qw(mod reg dst)] => sub {
           byte(h 0x0f);
           byte(h 0xaf);
           modrm('mod', 'dst', 'reg');
       });

opcode('imul', 'imm32', 'rm32', 'r32', [qw(mod reg dst)] => sub {
           byte(h 0x69);
           modrm('mod', 'dst', 'reg');
       });

header ('idiv');

opcode('idiv', 'rm32', [qw(mod reg)] => sub {
           byte(h 0xf7);
           modrm('mod', h 0x7, 'reg');
       });

header ('cdq');

opcode('cdq', [] => sub {
           byte(h 0x99);
       });

header ('call');

opcode('call', 'rel32', [], sub {
           byte(h 0xe8);
       });
opcode('call', 'indir', 'rm32', [qw(mod reg)] => sub {
           byte(h 0xff);
           modrm('mod', h 0x2, 'reg');
       });

header ('jmp');

opcode('jmp', 'rel8', [], sub {
           byte(h 0xEB);
       });
opcode('jmp', 'rel32', [], sub {
           byte(h 0xE9);
       });
opcode('jmp', 'indir', 'rm32', [qw(mod reg)] => sub {
           byte(h 0xff);
           modrm('mod', h 0x4, 'reg');
       });

header ('jcc');

opcode('jcc', 'rel8', ['cc'] => sub {
           byte('0x70 | (cc)');
       });
opcode('jcc', 'rel32', ['cc'] => sub {
           byte(h 0x0F);
           byte('0x80 | (cc)');
       });

header ('cmov');

opcode ('cmov', 'rm32', 'r32', [qw(cc mod reg dst)] => sub {
            byte(h 0x0f);
            byte('0x40 | (cc)');
            modrm('mod', 'dst', 'reg');
        });

header ('setcc');

opcode ('setcc', 'rm8', [qw(cc mod reg)] => sub {
            byte(h 0x0f);
            byte('0x90 | (cc)');
            modrm('mod', 0, 'reg');
        });

# Start helper routines

our @LINES;

sub header {
    print "/* " . uc $_[0] . " */\n\n";
}

sub opcode {
    my $mnm = shift;
    my @asmargs = ("x86", "$mnm");
    my ($arg, $margs, $sub);
    while(!ref($arg = shift)) {
        push @asmargs, $arg;
    }
    $margs = $arg;
    $sub = shift;
  {
      local @LINES = ();
      $sub->();
      unshift @LINES, ("#define " .
                       join("_", map {uc} @asmargs) .
                       "(" . join (",", 'buf', @$margs) . ")") . "  {";
      push @LINES, ' ' x 8 . '}';
      my $mlen = max map{length} @LINES;
      my $macro = join("\\\n",
                       map{$_ . (" " x ($mlen + 2 - length $_)) } @LINES);
      $macro =~ s/\s*$//;
      print "$macro\n\n";
  }   
}

sub byte {
    my $byte = shift;
    push @LINES, " " x 8 . "X86_BYTE(buf, $byte);";
}

sub modrm {
    my ($mod, $regop, $rm) = @_;
    byte("MODRM($mod, $regop, $rm)");
}
