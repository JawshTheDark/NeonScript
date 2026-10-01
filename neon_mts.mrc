; ============================================================================
;  NeonScript 2026  ::  MTS theme engine
;  Loads classic mIRC Theme Standard (.mts) themes - the format used by KTE,
;  ircN and Peace && Protection - so the great themes of the 2000s still work.
;
;  Supported: [mts] header, Name/Author/Description, Colors (26), RGBColors (16),
;  BaseColors (<c1>..<c4>), Prefix (<pre>), Font* keys, and the templates
;  Join JoinSelf Part Kick KickSelf Quit Nick NickSelf Mode Topic Invite
;  TextChan ActionChan NoticeChan TextQuery ActionQuery Notice  and  RAW.311 /312
;  /313 /317 /318 /319 /301 /307 /330 /671 (WHOIS).
;  Tokens: <nick> <address> <chan> <cmode> <cnick> <target> <knick> <kaddress>
;  <newnick> <modes> <text> <parentext> <ctcp> <pre> <timestamp> <c1>-<c4> <lt> <gt>
;  plus raw tokens <numeric> <realname> <wserver> <serverinfo> <idletime>
;  <signontime> <away> <users> <value> <fromserver> <isoper> <isregd>.
;  (Extension tokens <b> <u> <r> <o> <k> insert the matching control codes.)
; ============================================================================

alias ns.mts.dir return $ns.data(mts\)
alias ns.mts.file return $+($ns.mts.dir,$1)
alias ns.mts.active return $ns.get(mts,file)

; ---------------------------------------------------------------- listing / metadata
alias ns.mts.count return $findfile($ns.mts.dir,*.mts,0)
alias ns.mts.files {
  var %i = 1, %o
  while ($findfile($ns.mts.dir,*.mts,%i)) {
    %o = %o $nopath($v1)
    inc %i
  }
  return %o
}
; peek at a header key without loading the whole theme: $ns.mts.peek(file,key)
alias ns.mts.peek {
  var %f = $ns.mts.file($1), %i = 1, %n = $lines(%f), %l, %k = $lower($2)
  if (!$exists(%f)) return $null
  if (%n > 60) %n = 60
  while (%i <= %n) {
    %l = $read(%f,n,%i)
    if ($lower($gettok(%l,1,32)) == %k) return $gettok(%l,2-,32)
    inc %i
  }
  return $null
}
alias ns.mts.name {
  var %n = $ns.mts.peek($1,name)
  return $iif(%n,%n,$remove($1,.mts))
}

; ---------------------------------------------------------------- parser
; Loads a theme into the ns.mts hash table (key = lower-case line key)
alias ns.mts.load {
  var %f = $ns.mts.file($1), %i = 1, %n, %l, %k, %v, %p
  if (!$exists(%f)) return 0
  if ($hget(ns.mts)) hfree ns.mts
  hmake ns.mts 64
  %n = $lines(%f)
  while (%i <= %n) {
    %l = $read(%f,n,%i)
    inc %i
    if (%l == $null) continue
    if ($left(%l,1) == $chr(59)) continue
    if ($left(%l,1) == $chr(91)) continue
    ; key = first word, value = everything after the first space/tab (kept verbatim)
    %p = $pos(%l,$chr(32))
    if (!%p) %p = $pos(%l,$chr(9))
    if (!%p) {
      hadd ns.mts $lower(%l) $null
      continue
    }
    %k = $lower($left(%l,$calc(%p - 1)))
    %v = $mid(%l,$calc(%p + 1))
    if (%k == $null) continue
    hadd ns.mts %k %v
  }
  hadd ns.mts __file $1
  return 1
}
alias -l mget return $hget(ns.mts,$1)

; ---------------------------------------------------------------- activate / deactivate
; palette backup so switching away from an MTS theme restores the original 16 colours
alias -l pal.save {
  if ($ns.get(mts,palette) != $null) return
  var %i = 0, %o
  while (%i < 16) {
    %o = %o $color(%i)
    inc %i
  }
  ns.set mts palette $ns.trim(%o)
}
alias ns.mts.palrestore {
  var %p = $ns.get(mts,palette), %i = 1
  if (%p == $null) return
  while (%i <= 16) {
    color $calc(%i - 1) $gettok(%p,%i,32)
    inc %i
  }
  ns.del mts palette
}

; ns.mts.apply <file.mts>
alias ns.mts.apply {
  var %f = $1
  if (!$ns.mts.load(%f)) {
    ns.err cannot read MTS theme $qt(%f)
    return
  }
  ; palette (RGBColors: 16 triplets "r,g,b r,g,b ...")
  var %rgb = $mget(rgbcolors), %i = 1, %t
  if ($numtok(%rgb,32) >= 16) {
    pal.save
    while (%i <= 16) {
      %t = $gettok(%rgb,%i,32)
      color $calc(%i - 1) $rgb($gettok(%t,1,44),$gettok(%t,2,44),$gettok(%t,3,44))
      inc %i
    }
  }
  ; Colors (26 items in Colors-dialog order); the last five items are derived
  var %cols = $mget(colors), %items = $ns.theme.items, %n = $numtok(%cols,44)
  if (%n >= 12) {
    %i = 1
    while (%i <= %n) && (%i <= 26) {
      color $gettok(%items,%i,44) $gettok(%cols,%i,44)
      inc %i
    }
    color Title text $gettok(%cols,12,44)
    color Inactive $gettok(%cols,26,44)
    color Treebar $gettok(%cols,1,44)
    color Treebar Text $gettok(%cols,12,44)
    color MDI area $gettok(%cols,1,44)
  }
  ; fonts
  if ($ns.flag(mts,fonts,1)) {
    var %fd = $mget(fontdefault)
    if (%fd != $null) {
      var %fn = $gettok(%fd,1,44), %fs = $ns.trim($gettok(%fd,2,44))
      if (%fs isnum) font -z %fs %fn
    }
  }
  ns.set mts file %f
  ns.set events style mts
  ns.set theme current $+(mts:,%f)
  ns.set theme mode $iif($ns.mts.dark,dark,light)
  var %acc = $gettok($mget(basecolors),2,44)
  ns.set theme accent $iif(%acc isnum,%acc,13)
  ns.mts.storeev
  if ($ns.flag(theme,applybg,1)) ns.theme.bg
  if ($ns.flag(mts,chat,1)) ns.set mts chatactive 1
  .signal -n ns.theme $+(mts:,%f)
  ns.say MTS theme $+($chr(2),$ns.mts.name(%f),$chr(2)) active $chr(40) $+ $iif($mget(author),by $mget(author) $+ $chr(44) $+ $chr(32)) $+ $numtok($mget(colors),44) colours $+ $chr(41)
}
; is the theme's background dark? (Colors item 1 = background palette index)
alias ns.mts.dark {
  var %b = $gettok($mget(colors),1,44)
  return $iif(%b isnum,$iif($calc($ns.r8($ns.pal(%b)) + $ns.g8($ns.pal(%b)) + $ns.b8($ns.pal(%b))) < 384,1,0),1)
}
; give NeonScript's own accents (whois box, dashboard) colours that suit the theme
alias ns.mts.storeev {
  var %bc = $mget(basecolors), %t = $gettok(%bc,1,44), %nk = $gettok(%bc,2,44), %hi = $gettok(%bc,3,44), %br = $gettok(%bc,4,44)
  if (%t !isnum) %t = 15
  if (%nk !isnum) %nk = 12
  if (%hi !isnum) %hi = 8
  if (%br !isnum) %br = 14
  ns.set theme ev_join 9
  ns.set theme ev_part 7
  ns.set theme ev_quit 4
  ns.set theme ev_kick 4
  ns.set theme ev_mode %hi
  ns.set theme ev_topic 11
  ns.set theme ev_nick %nk
  ns.set theme ev_invite 10
  ns.set theme ev_label %br
  ns.set theme ev_value %t
  ns.set theme ev_dim %br
  ns.set theme ev_hi %hi
  ns.set theme ev_q 13
  ns.set theme ev_a 4
  ns.set theme ev_o 9
  ns.set theme ev_h 11
  ns.set theme ev_v 8
}
; leave MTS mode (built-in themes call this when applied)
alias ns.mts.off {
  ns.mts.palrestore
  ns.del mts file
  ns.del mts chatactive
  if ($ns.get(events,style) == mts) ns.set events style modern
}

; ---------------------------------------------------------------- rendering
alias -l keyof {
  var %t = $1
  if (%t == join) return join
  if (%t == joinself) return joinself
  if (%t == part) return part
  if (%t == quit) return quit
  if (%t == kick) return kick
  if (%t == kickself) return kickself
  if (%t == nick) return nick
  if (%t == nickself) return nickself
  if (%t == mode) return mode
  if (%t == topic) return topic
  if (%t == invite) return invite
  return %t
}
; does the active theme define a template for this event?  (self variants fall back)
alias ns.mts.has {
  if (!$hget(ns.mts)) return 0
  var %k = $keyof($1)
  if ($mget(%k) != $null) return 1
  if ($right(%k,4) == self) && ($mget($left(%k,-4)) != $null) return 1
  return 0
}
; $ns.mts.render(type) -> finished line, reading event variables from ns.evv
alias ns.mts.render {
  if (!$hget(ns.mts)) return $null
  var %k = $keyof($1), %tpl = $mget(%k)
  if (%tpl == $null) && ($right(%k,4) == self) %tpl = $mget($left(%k,-4))
  if (%tpl == $null) return $null
  hadd -m ns.evv __tpl %tpl
  return $ns.mts.expand
}
; expand the template stored in ns.evv/__tpl  (no parameters: free text may contain commas)
alias ns.mts.expand {
  var %t = $hget(ns.evv,__tpl), %out = $chr(1), %i = 1, %n = $len(%t), %rest, %e, %tok, %lt = $chr(60), %sent = $chr(1), %val
  while (%i <= %n) {
    %rest = $mid(%t,%i)
    %e = $pos(%rest,%lt)
    if (!%e) {
      %out = %out $+ %sent $+ %rest $+ %sent
      break
    }
    ; literal text before the '<'
    if (%e > 1) %out = %out $+ %sent $+ $left(%rest,$calc(%e - 1)) $+ %sent
    %rest = $mid(%rest,%e)
    var %close = $pos(%rest,$chr(62))
    %tok = $null
    if (%close) && (%close <= 14) %tok = $mid(%rest,2,$calc(%close - 2))
    if (%tok != $null) && (!$pos(%tok,$chr(32))) && ($ns.mts.known(%tok)) {
      %val = $ns.mts.val(%tok)
      %out = %out $+ %sent $+ %val $+ %sent
      %i = $calc(%i + %e + %close - 1)
    }
    else {
      ; not a token: keep the '<' literally
      %out = %out $+ %sent $+ %lt $+ %sent
      %i = $calc(%i + %e)
    }
  }
  return $remove(%out,%sent)
}
; every token we understand (lower case)
alias ns.mts.known return $iif($findtok(lt gt c1 c2 c3 c4 nick address chan cmode cnick target knick kaddress newnick modes text parentext ctcp pre timestamp comments numeric value fromserver users away realname isoper operline isregd wserver serverinfo idletime signontime b u r o k,$lower($1),1,32),1,0)
alias ns.mts.val {
  var %k = $lower($1), %v
  if (%k == lt) return $chr(60)
  if (%k == gt) return $chr(62)
  if (%k == b) return $chr(2)
  if (%k == u) return $chr(31)
  if (%k == r) return $chr(22)
  if (%k == o) return $chr(15)
  if (%k == k) return $chr(3)
  if ($findtok(c1 c2 c3 c4,%k,1,32)) {
    var %c = $gettok($hget(ns.mts,basecolors),$mid(%k,2,1),44)
    if (%c !isnum) %c = $gettok(15 12 8 14,$mid(%k,2,1),32)
    return $+($chr(3),$base(%c,10,10,2))
  }
  if (%k == pre) {
    %v = $hget(ns.mts,prefix)
    return $iif(%v != $null,%v,$chr(42))
  }
  if (%k == timestamp) return $asctime($ns.stampfmt($ns.get(events,stampmode,1)))
  if (%k == cnick) return $base($ns.nickcol($hget(ns.evv,nick)),10,10,2)
  if (%k == parentext) {
    %v = $hget(ns.evv,text)
    if (%v == $null) return $null
    return $+($chr(40),%v,$chr(41))
  }
  if (%k == comments) return $null
  return $hget(ns.evv,%k)
}

; ---------------------------------------------------------------- WHOIS raws via templates
; raw handlers in neon_events call:  ns.mts.raw <numeric> <the raw's $2->   ($result = 1 if printed)
alias ns.mts.raw {
  var %num = $1
  if ($ns.get(events,style,modern) != mts) || (!$hget(ns.mts)) return 0
  var %tpl = $hget(ns.mts,$+(raw.,%num))
  if (%tpl == $null) return 0
  if ($hget(ns.evv)) hdel -w ns.evv *
  hadd -m ns.evv numeric %num
  hadd -m ns.evv fromserver $server
  hadd -m ns.evv nick $2
  if (%num == 311) {
    hadd -m ns.evv address $3 $+ @ $+ $4
    hadd -m ns.evv realname $6-
  }
  elseif (%num == 312) {
    hadd -m ns.evv wserver $3
    hadd -m ns.evv serverinfo $4-
  }
  elseif (%num == 317) {
    hadd -m ns.evv idletime $duration($3)
    hadd -m ns.evv signontime $asctime($4)
  }
  elseif (%num == 319) hadd -m ns.evv users $3-
  elseif (%num == 301) hadd -m ns.evv away $3-
  else hadd -m ns.evv value $3-
  hadd -m ns.evv text $3-
  hadd -m ns.evv __tpl %tpl
  echo -cati2 whois $ns.mts.expand
  return 1
}

; ---------------------------------------------------------------- chat lines (opt-in)
alias -l mts.chaton return $iif($ns.flag(mts,chatactive,0),$iif($ns.get(events,style,modern) == mts,1,0),0)
alias -l mts.chatvars {
  if ($hget(ns.evv)) hdel -w ns.evv *
  hadd -m ns.evv nick $nick
  hadd -m ns.evv address $address
  hadd -m ns.evv target $target
  hadd -m ns.evv text $1-
  if ($chan) {
    hadd -m ns.evv chan $chan
    hadd -m ns.evv cmode $ns.rk.of($chan,$nick)
  }
  else hadd -m ns.evv chan $target
}
; $1 = template key  $2 = target window  -> prints with highlight/flash handling
alias -l mts.chatshow {
  var %tpl = $hget(ns.mts,$1)
  if (%tpl == $null) return 0
  hadd -m ns.evv __tpl %tpl
  echo -cmlbfti2 normal $2 $ns.mts.expand
  return 1
}
on ^*:TEXT:*:#:{
  if (!$mts.chaton) return
  mts.chatvars $1-
  if ($mts.chatshow(textchan,$chan)) haltdef
}
on ^*:ACTION:*:#:{
  if (!$mts.chaton) return
  mts.chatvars $1-
  if ($mts.chatshow(actionchan,$chan)) haltdef
}
on ^*:NOTICE:*:#:{
  if (!$mts.chaton) return
  mts.chatvars $1-
  if ($mts.chatshow(noticechan,$chan)) haltdef
}
on ^*:TEXT:*:?:{
  if (!$mts.chaton) return
  if (!$query($nick)) return
  mts.chatvars $1-
  if ($mts.chatshow(textquery,$nick)) haltdef
}
on ^*:ACTION:*:?:{
  if (!$mts.chaton) return
  if (!$query($nick)) return
  mts.chatvars $1-
  if ($mts.chatshow(actionquery,$nick)) haltdef
}

; ---------------------------------------------------------------- import / commands
; /neon mts                      open the theme gallery
; /neon mts import [file]        add a .mts file to the library
; /neon mts apply <file.mts>     activate one
; /neon mts off                  back to the built-in styles and your original palette
; /neon mts list                 what is installed
alias neon.mts {
  var %c = $lower($1)
  if (%c == $null) { neon themes | return }
  if (%c == import) { ns.mts.import $2- | return }
  if (%c == preview) {
    if ($2 == $null) { ns.err usage: /neon mts preview <file.mts> | return }
    ns.mts.preview $2
    return
  }
  if (%c == apply) {
    if ($ns.mts.peek($2,name) == $null) && (!$exists($ns.mts.file($2))) { ns.err no such theme: $2 | return }
    ns.mts.apply $2
    return
  }
  if (%c == off) {
    ns.mts.off
    ns.theme.apply $ns.get(theme,lastbuiltin,neonnight)
    return
  }
  if (%c == list) {
    var %i = 1
    while ($gettok($ns.mts.files,%i,32)) {
      ns.say $v1 - $ns.mts.name($v1)
      inc %i
    }
    if (!$ns.mts.files) ns.say no MTS themes installed - /neon mts import
    return
  }
  ns.err usage: /neon mts import [file], preview <file.mts>, apply <file.mts>, off or list
}
alias ns.mts.import {
  var %src = $1-
  if (%src == $null) %src = $sfile($mircdir $+ *.mts,Import an MTS theme,Import)
  if (!%src) return
  if (!$exists(%src)) { ns.err file not found: %src | return }
  if ($right(%src,4) != .mts) { ns.err that does not look like an .mts file | return }
  if (!$isdir($ns.mts.dir)) mkdir $qt($ns.mts.dir)
  .copy -o $qt(%src) $qt($ns.mts.dir)
  ns.say imported $+($chr(2),$ns.mts.name($nopath(%src)),$chr(2)) $chr(40) $+ $nopath(%src) $+ $chr(41) - apply it from /neon themes
  .signal -n ns.mtschanged
}

; ---------------------------------------------------------------- preview window
; a picture window that renders sample events through a theme's templates
alias ns.mts.preview {
  var %file = $1, %w = @NeonPreview, %keep = $ns.get(mts,file)
  if (!$ns.mts.load(%file)) return
  if ($window(%w)) window -c %w
  window -pBf %w -1 -1 640 280
  titlebar %w Preview: $ns.mts.name(%file)
  var %cols = $mget(colors), %bgi = $gettok(%cols,1,44), %fgi = $gettok(%cols,12,44)
  var %bg = $ns.pal($iif(%bgi isnum,%bgi,1)), %fg = $ns.pal($iif(%fgi isnum,%fgi,0))
  drawrect -rfn %w %bg 1 0 0 640 280
  var %fn = Consolas, %fs = 13, %y = 10
  var %lines = $ns.mts.sample, %i = 1, %line
  while ($gettok(%lines,%i,32) != $null) {
    %line = $ns.mts.samplerender($v1)
    if (%line != $null) {
      drawtext -prn %w %fg %fn %fs 10 %y %line
      inc %y 19
    }
    inc %i
  }
  drawrect %w
  ; restore the active theme's templates
  if (%keep) ns.mts.load %keep
  elseif ($hget(ns.mts)) hfree ns.mts
}
; sample events used by the preview (space separated)
alias ns.mts.sample return textchan actionchan noticechan join joinself part quit kick nick mode topic invite
alias ns.mts.samplerender {
  var %t = $1
  if ($hget(ns.evv)) hdel -w ns.evv *
  hadd -m ns.evv nick Nova
  hadd -m ns.evv address nova@host.example
  hadd -m ns.evv chan #neon
  hadd -m ns.evv cmode $chr(64)
  hadd -m ns.evv target #neon
  hadd -m ns.evv knick Zed
  hadd -m ns.evv kaddress zed@zed.example
  hadd -m ns.evv newnick Nova2
  hadd -m ns.evv modes +o Kira
  hadd -m ns.evv ctcp VERSION
  hadd -m ns.evv text $iif($findtok(textchan actionchan noticechan,%t,1,32),hello everyone - nice theme!,$iif(%t == topic,Welcome to NeonScript,gone for a while))
  if (%t == actionchan) hadd -m ns.evv text waves hello
  var %tpl = $ns.mts.render(%t)
  if (%tpl == $null) return $+($chr(3),14,[,%t,] not defined by this theme)
  return %tpl
}
