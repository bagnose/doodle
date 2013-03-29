#!/bin/sh

# Last modified: Wed 2003-10-22 00:29:12 +0100
# Copyright (C) 2003, Vivek Dasmohapatra <vivek@etla.org>

declare paridx=0;
declare -a OPT_p;

# convert "^X" to a control char (A-_ supported):
_ctrl ()
{
    local char="${1:1:1}";
    #echo _ctrl "$char";
    case $char in
        A) asc=$'\x01' ;;
        B) asc=$'\x02' ;;
        C) asc=$'\x03' ;;
        D) asc=$'\x04' ;;
        E) asc=$'\x05' ;;
        F) asc=$'\x06' ;;
        G) asc=$'\x07' ;;
        H) asc=$'\x08' ;;
        I) asc=$'\x09' ;;
        J) asc=$'\x0a' ;;
        K) asc=$'\x0b' ;;
        L) asc=$'\x0c' ;;
        M) asc=$'\x0d' ;;
        N) asc=$'\x0e' ;;
        O) asc=$'\x0f' ;;
        P) asc=$'\x10' ;;
        Q) asc=$'\x11' ;;
        R) asc=$'\x12' ;;
        S) asc=$'\x13' ;;
        T) asc=$'\x14' ;;
        U) asc=$'\x15' ;;
        V) asc=$'\x16' ;;
        W) asc=$'\x17' ;;
        X) asc=$'\x18' ;;
        Y) asc=$'\x19' ;;
        Z) asc=$'\x1a' ;;
        [) asc=$'\x1b' ;;
       \\) asc=$'\x1c' ;;
        ]) asc=$'\x1d' ;;
        ^) asc=$'\x1e' ;;
        _) asc=$'\x1f' ;;
        *) asc="$1"    ;;
    esac;
}

# decode a symbol, or just return unaltered if no match found:
_decode ()
{
    local \
        asc=""    \
        symbol="" \
        ctlbuf="" ;

    ctlstr="";
    #echo _decode "'$*'" 1>&2;

    for symbol in "$@";
    do
      case "$symbol" in
          S7C1T)  symbol="ESC SP F" ;; # 7 bit controls
          S8C1T)  symbol="ESC SP G" ;; # 8 bit controls
          DECDHLU)symbol="ESC # 3"  ;; # double height, upper half
          DECDHLL)symbol="ESC # 4"  ;; # double height, lower half
          DECSWL) symbol="ESC # 5"  ;; # single width
          DECDWL) symbol="ESC # 6"  ;; # double width
          DECALN) symbol="ESC # 8"  ;; # alignment test
          DECSC)  symbol="ESC 7"    ;; # save cursor
          DECRC)  symbol="ESC 8"    ;; # restore cursor
          DECPAM) symbol="ESC ="    ;; # app keypad
          DECPNM) symbol="ESC >"    ;; # normal keypad
          RIS)    symbol="ESC c"    ;; # full reset
          ESC)    symbol="^["       ;; # esc
          IND)    symbol="ESC D"    ;; # index
          NEL)    symbol="ESC E"    ;; # next line
          HTS)    symbol="ESC H"    ;; # set tab stop
          RI)     symbol="ESC M"    ;; # Reverse Index
          SS2)    symbol="ESC N"    ;; # Single Shift G2 charset next char only
          SS3)    symbol="ESC O"    ;; # Single Shift G3 charset next char only
          DCS)    symbol="ESC P"    ;; # Device Control String
          SPA)    symbol="ESC V"    ;; # Start Protected Area
          EPA)    symbol="ESC W"    ;; # End Protected Area
          SOS)    symbol="ESC X"    ;; # Start Of String
          DECID)  symbol="ESC Z"    ;; # terminal id (obs, use CSI Ps c)
          CSI)    symbol="ESC ["    ;; # Control Sequence Introduction
          ST)     symbol="ESC \\"   ;;# String Terminator (new, was BEL)
          OSC)    symbol="ESC ]"    ;; # Operating System Command
          PM)     symbol="ESC ^"    ;; # Privacy Message
          APC)    symbol="ESC _"    ;; # Application Program Command
          BEL)    symbol="^G"       ;; # beep
          BS)     symbol="^H"       ;; # backspace
          CR)     symbol="^M"       ;; # Carriage Return (beginning of line)
          ENQ)    symbol="^E"       ;; # terminal stats. usu responds "xterm"
          FF)     symbol="^L"       ;; # Form Feed (clear/redraw screen)
          LF)     symbol="^J"       ;; # Line Feed
          SO)     symbol="^N"       ;; # Shift Out : G1 character set
          TAB)    symbol="^I"       ;; # Tab
          VT)     symbol="^K"       ;; # same as LF
          SI)     symbol="^O"       ;; # Shift In : G0 (default) character set
          ^?)     _ctrl "$symbol"; symbol="$asc" ;; # ^X ctrl notation
	  SET_WTITLE) symbol="OSC 2 ; %p ST" ;;
          SET_ITITLE) symbol="OSC 1 ; %p ST" ;;
          SET_TITLES) symbol="OSC 0 ; %p ST" ;;
          SET_XPROP)  symbol="OSC 3 ; %p ST" ;;
          GET_WTITLE) symbol="CSI 2 1 t"     ;;
          GET_ITITLE) symbol="CSI 2 0 t"     ;;
      esac;
      ctlbuf="${ctlbuf}${ctlbuf:+ }${symbol}";
    done;

    ctlstr="${ctlbuf}";
}

usage ()
{
    
    cat <<EOF | ${PAGER:-cat}
usage:
  $0 [-r] [-R] [-p arg0 [-p arg1]...] <SYMBOLIC SEQUENCE...>

  This tool translates a sequence of symbols and strings into a
  corresponding terminal escape sequence, which it then prints
  on stdout.

  If the -r flag is supplied, then it sends the escape sequence
  to the tty ( via '/dev/tty' ), reads the terminal's response,
  trims some leading and trailing marker characters, and prints
  the result on stdout instead (unless -R was specified, in which
  case you get the raw response sequence).

  Note that the raw response generally begins with a control string
  that renders it invisible when printed, so it's a good idea to
  capture it with a RSP=\$($0 -r -R SEQUENCE) type construct.

  The sequence will have all the spaces stripped out of it, except
  those explicitly passed as the 'SP' symbol.

  $0 knows about the following symbols:
  
      S7C1T      7 bit control sequences
      S8C1T      8 bit control sequences
      DECDHLU    double height line, upper half
      DECDHLL    double height line, lower half
      DECSWL     single width
      DECDWL     double width
      DECALN     alignment test
      DECSC      save cursor
      DECRC      restore cursor
      DECPAM     app keypad
      DECPNM     normal keypad
      RIS        full reset
      ESC        esc
      IND        index
      NEL        next line
      HTS        set tab stop
      RI         Reverse Index
      SS2        Single Shift G2 charset: next char only
      SS3        Single Shift G3 charset: next char only
      DCS        Device Control String
      SPA        Start Protected Area
      EPA        End Protected Area
      SOS        Start Of String
      DECID      terminal id (obsolete: use CSI Ps c)
      CSI        Control Sequence Introduction
      ST         String Terminator
      OSC        Operating System Command
      PM         Privacy Message
      APC        Application Program Command
      BEL        beep
      BS         backspace
      CR         Carriage Return (beginning of line)
      ENQ        terminal status
      FF         Form Feed (clear/redraw screen)
      LF         Line Feed
      SO         Shift Out : G1 character set
      SP         space
      TAB        Tab
      VT         same as LF
      SI         Shift In : G0 (default) character set
      ^A ... ^_  control characters 0x01 through 0x1f

  The following high-level sequences have been defined for convenience:

      GET_WTITLE    fetch the window title
      GET_ITITLE    fetch the icon title

  Additionally, we support parametrised symbolic sequences:
  Each '%p' in a sequence will be replaced with successive 
  values of the -p flag.

  The following parametrised sequences are built in:

      SET_WTITLE    (1 arg)    Set the window title
      SET_ITITLE    (1 arg)    Set the icon title
      SET_TITLES    (1 arg)    Set both the above
      SET_XPROP     (1 arg)    Set (prop=value) or zap (prop) an X property

  The escape sequences are detailed here:

      http://rtfm.etla.org/xterm/ctlseq.html

  Example:

      # sets the title bar to "Xterm Title"
      $0 OSC 0 \; Xterm SP Title ST

      # or:
      $0 -p "Xterm SP Title" SET_WTITLE
      
      # stores the (sanitised) title response in \$TSTR
      TSTR=\$($0 CSI 2 1 t)

      # or:
      TSTR=\$($0 GET_WTITLE)
EOF
}

_param ()
{
    local curidx=0;

    while [ 1 -eq 1 ];
    do
      if [ $paridx -eq $curidx ];
      then
	  par=${OPT_p[$curidx]};
	  paridx=$(($paridx + 1));
	  #echo "retrieving p[$curidx] = $par";
	  break;
      else
	  curidx=$(($curidx + 1));
      fi;
    done;
}

decode ()
{
    local\
        ctlstr="" \
        sym=""    \
        seqbuf="" ;
    
    for sym in "$@";
    do
      while [ "1" = "1" ];
      do
        _decode $sym; 
        if [ "X$ctlstr" = "X$sym" ]; then break; else sym="$ctlstr"; fi;
      done;
      sequence="${sequence}${sequence:+ }${sym}";
      #echo -n sequence=                               1>&2; 
      #echo    "$sequence" | sed -e 's@[^A-Z0-9_]@.@g' 1>&2; 
    done;

    for sym in $sequence;
    do
      if [ "X$sym" = "XSP" ]; then sym=" ";             fi;
      if [ "X$sym" = "X%p" ]; then _param ; sym="$par"; fi;
      seqbuf="${seqbuf}${sym}";
    done;

    sequence="$seqbuf";
}

ctl_read ()
{
    local \
	old=""      \
        cseq="$*"   \
        response="" \
        sequence="" ;

    exec </dev/tty;              # make sure stdin is a tty
    old="$(stty -g)";            # store the stty settings
    stty raw -echo min 0 time 1; # black magic
    echo -n "$cseq" > /dev/tty;  # feed the control sequence to the tty
    IFS='' read -r response;     # read the response
    stty "$old";                 # reset th tty to its saved state

    if [ -z "$OPT_R" ] && [ -n "$response" ];
    then
        local \
            OSC=""                \
            CSI=""                \
            rlen=${#response}     \
            start=${response:0:2} ;
        
        decode "OSC"; OSC="$sequence";
        decode "CSI"; CSI="$sequence";
        
        if   [ "$start" = "$OSC" ]; then response=${response:3:$(($rlen-5))};
        elif [ "$start" = "$CSI" ]; then response=${response:3:$(($rlen-4))};
        fi;
    fi;
    
    echo -n "$response";         # echo the response string
}

main ()
{
    local \
        name=""   \
        setarg="" ;
    while getopts rRhp: n;
    do
      case $n in
	  p)
	      OPT_p[$paridx]="${OPTARG:-$paridx}";
	      paridx=$(($paridx + 1));
	      ;;
	  *)
	      setarg="OPT_${n}=\"\${OPT_${n}}\${OPT_$n:+ }${OPTARG:-1}\"";
	      #echo $setarg 1>&2;
	      eval $setarg;
	      ;;
      esac;
    done;
    paridx=0;
    shift $(($OPTIND-1));

    #echo "\$OPT_p='$OPT_p'";

    if [ $# -eq 0 ] || [ -n "$OPT_h" ]; then usage; exit 0; fi;
    
    decode "$@";
    
    if [ -n "$OPT_r" ]; then ctl_read $sequence; else echo -n $sequence; fi;
}

main "$@";

