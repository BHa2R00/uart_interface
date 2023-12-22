\ rc4 algorithm 
0 value ii        0 value jj
0 value keyaddr   0 value keylen
create sarray   256 allot   \ state array of 256 bytes
: keyarray      keylen mod   keyaddr ;

: get_byte      + c@ ;
: set_byte      + c! ;
: as_byte       255 and ;
: reset_ij      0 to ii   0 to jj ;
: i_update      1 +   as_byte to ii ;
: j_update      ii sarray get_byte +   as_byte to jj ;
: swap_s_ij
    jj sarray get_byte
       ii sarray get_byte  jj sarray set_byte
    ii sarray set_byte
;

: rc4_init ( keyaddr keylen -- )
    256 min to keylen   to keyaddr
    256 0 do   i i sarray set_byte   loop
    reset_ij
    begin
        ii keyarray get_byte   jj +  j_update
        swap_s_ij
        ii 255 < while
        ii i_update
    repeat
    reset_ij
;
: rc4_byte
    ii i_update   jj j_update
    swap_s_ij
    ii sarray get_byte   jj sarray get_byte +   as_byte sarray get_byte  xor
;


hex
create akey   61 c, 8a c, 63 c, d2 c, fb c,
: test   cr   0 do  rc4_byte . loop  cr ;
akey 5 rc4_init
2c f9 4c ee dc  5 test   \ output should be: f1 38 29 c9 de
