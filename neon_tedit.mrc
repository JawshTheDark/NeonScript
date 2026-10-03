; ============================================================================
;  NeonScript 2026  ::  theme editor   /neon themeedit
;  Build your own colour theme: every mIRC colour item and every NeonScript event colour, with a live preview,
;  saved next to the built-in ones (themes_user.ini, ids "u_<name>") and exportable as a classic .mts file.
;  Imported MTS themes can be edited too: their colours change and everything else in the file (line layouts,
;  fonts, palette) is carried over byte for byte into a copy - the original is never touched.
;  Colours are palette indices 0-98 (mIRC's own 99 colours), which is what mIRC and NeonScript store; a theme may
;  carry its own 16 first colours (the way MTS themes do) for exact RGB values.
;  With the native helper on, /neon themeedit opens the HTML "Theme Studio" (data\ui\ted.html); without it, the dialog.
; ============================================================================

alias ns.theme.ufile return $+($scriptdir,themes_user.ini)
alias ns.theme.uids return $replace($readini($ns.theme.ufile,n,themes,order),$chr(44),$chr(32))
alias ns.ted.evkeys return join part quit kick mode topic nick invite label value dim hi q a o h v
; one line per editable item:  "mirc 1 Background" / "ev join Join lines"; an MTS theme only has the 26 mIRC colours of its Colors line
alias ns.ted.count return $iif($ns.ted.get(kind) == mts,26,$calc(31 + $numtok($ns.ted.evkeys,32)))
alias ns.ted.itemname {
  var %n = $1
  if (%n <= 31) return $gettok($ns.theme.items,%n,44)
  return NeonScript: $gettok($ns.ted.evnames,$calc(%n - 31),44)
}
alias ns.ted.evnames return join lines,part lines,quit lines,kick lines,mode lines,topic lines,nick changes,invites,labels,values,dim text,highlight,owner (~) names,admin (&) names,op (@) names,halfop (%) names,voice (+) names
; the working copy lives in the ns.ted hash:  c<N> = colour index of mIRC item N (1-31), e<N> = index of event key N
alias ns.ted.get return $hget(ns.ted,$1)
alias ns.ted.val {
  var %n = $1
  return $iif(%n <= 31,$ns.ted.get($+(c,%n)),$ns.ted.get($+(e,$calc(%n - 31))))
}
alias ns.ted.setval {
  var %n = $1
  if (%n <= 31) hadd -m ns.ted $+(c,%n) $2
  else hadd -m ns.ted $+(e,$calc(%n - 31)) $2
  if ($ns.ted.get(kind) == mts) ns.ted.derive
}

; ---------------------------------------------------------------- the three kinds of theme
;  builtin  an id of data\themes.ini           user  "u_<name>" in themes_user.ini           mts  "mts:<file.mts>" (imported)
alias ns.ted.kind return $iif($left($1,4) == mts:,mts,$iif($left($1,2) == u_,user,builtin))
alias ns.ted.valid return $iif($istok($ns.theme.entries,$1,32),1,0)
; ones the editor may delete: your own themes, and MTS copies it wrote itself (they carry an EditedBy line)
alias ns.ted.mine {
  var %k = $ns.ted.kind($1)
  if (%k == user) return 1
  if (%k == mts) return $iif($ns.ted.mtsval($ns.mts.file($mid($1,5)),editedby) != $null,1,0)
  return 0
}
; the value of a key in an .mts file - the LAST such line, as the theme engine reads it:  $ns.ted.mtsval(<full path>,<key>)
alias ns.ted.mtsval {
  var %f = $1, %k = $lower($2), %n = 0, %l, %o, %p
  if (!$exists(%f)) return $null
  while ($true) {
    %l = $read(%f,nw,$+(%k,?*),$calc(%n + 1))
    if (%l == $null) break
    %n = $readn
    if (!$regex(ns.tm,%l,/^(\w+)\s(.*)$/)) continue
    if ($lower($regml(ns.tm,1)) != %k) continue
    %o = $regml(ns.tm,2)
  }
  return %o
}
; the number of the LAST line of an .mts that starts with <key> (0 when there is none): $ns.ted.mtsline(<full path>,<key>)
alias ns.ted.mtsline {
  var %f = $1, %k = $lower($2), %n = 0, %l, %o = 0
  if (!$exists(%f)) return 0
  while ($true) {
    %l = $read(%f,nw,$+(%k,?*),$calc(%n + 1))
    if (%l == $null) break
    %n = $readn
    if ($regex(ns.tm,%l,/^(\w+)\s/)) && ($lower($regml(ns.tm,1)) == %k) %o = %n
  }
  return %o
}
; file name for a theme name: letters and digits only
alias ns.ted.mtsslug return $regsubex($lower($1-),/[^a-z0-9]/g,)

; ---------------------------------------------------------------- palette
; the user's own 16 colours: what mIRC had before a theme replaced them (kept by the MTS engine), else what it has now
alias ns.ted.curpal {
  var %p = $ns.get(mts,palette), %i = 0
  if ($numtok(%p,32) == 16) return %p
  %p = $null
  while (%i < 16) {
    %p = %p $color(%i)
    inc %i
  }
  return $ns.trim(%p)
}
; palette index -> RGB integer, using the working copy's own first 16 colours
alias ns.ted.pal {
  if ($1 < 16) {
    var %v = $gettok($ns.ted.get(pal),$calc($1 + 1),32)
    if (%v isnum) return %v
  }
  return $ns.pal($1)
}
; palette index -> "#rrggbb" and back to RGB
alias ns.ted.hex {
  var %c = $ns.ted.pal($1)
  return $+(#,$base($ns.r8(%c),10,16,2),$base($ns.g8(%c),10,16,2),$base($ns.b8(%c),10,16,2))
}
; the palette entry closest to a colour (RGB integer)
alias ns.ted.nearest {
  var %c = $1, %i = 0, %best = 0, %bd = 999999, %p, %d
  while (%i <= 98) {
    %p = $ns.ted.pal(%i)
    %d = $calc(($ns.r8(%c) - $ns.r8(%p)) ^ 2 + ($ns.g8(%c) - $ns.g8(%p)) ^ 2 + ($ns.b8(%c) - $ns.b8(%p)) ^ 2)
    if (%d < %bd) {
      %bd = %d
      %best = %i
    }
    inc %i
  }
  return %best
}
; 16 "r,g,b" triplets -> hash item "tri" = 16 RGB integers (no item when they are not 16 good triplets), and back.
; (a command, so the commas in the text are never taken for parameter separators)
alias ns.ted.tri2int {
  var %i = 1, %o, %t
  if ($hget(ns.ted,tri) != $null) hdel ns.ted tri
  if ($numtok($1-,32) < 16) return
  while (%i <= 16) {
    %t = $gettok($1-,%i,32)
    if ($numtok(%t,44) != 3) return
    %o = %o $rgb($gettok(%t,1,44),$gettok(%t,2,44),$gettok(%t,3,44))
    inc %i
  }
  hadd -m ns.ted tri $ns.trim(%o)
}
alias ns.ted.int2tri {
  var %i = 1, %o, %v
  while (%i <= 16) {
    %v = $gettok($1-,%i,32)
    %o = %o $+($ns.r8(%v),$chr(44),$ns.g8(%v),$chr(44),$ns.b8(%v))
    inc %i
  }
  return $ns.trim(%o)
}

; ---------------------------------------------------------------- loading a theme into the working copy
; load a theme (built-in, "u_..." or "mts:<file>") into the working copy
alias ns.ted.load {
  var %id = $1, %kind = $ns.ted.kind(%id), %f = $ns.theme.fileof(%id), %cols, %i = 1, %ev, %k
  if ($hget(ns.ted)) hfree ns.ted
  hmake ns.ted 100
  hadd ns.ted kind %kind
  hadd ns.ted base %id
  hadd ns.ted pal0 $ns.ted.curpal
  hadd ns.ted pal $ns.ted.get(pal0)
  hadd ns.ted pc 0
  if (%kind == mts) {
    ns.ted.loadmts %id
    return
  }
  %cols = $readini(%f,n,%id,colors)
  %ev = $readini(%f,n,%id,ev)
  while (%i <= 31) {
    hadd ns.ted $+(c,%i) $iif($gettok(%cols,%i,44) isnum,$gettok(%cols,%i,44),0)
    inc %i
  }
  %i = 1
  while ($gettok($ns.ted.evkeys,%i,32) != $null) {
    %k = $v1
    hadd ns.ted $+(e,%i) $iif($ns.ted.evof(%ev,%k) != $null,$ns.ted.evof(%ev,%k),$ns.ecn(%k))
    inc %i
  }
  hadd ns.ted name $iif(%kind == user,$ns.theme.name(%id),$+($ns.theme.name(%id),$chr(32),copy))
  hadd ns.ted desc $iif(%kind == user,$readini(%f,n,%id,desc),Based on $ns.theme.name(%id))
  hadd ns.ted mode $iif($readini(%f,n,%id,mode) != $null,$readini(%f,n,%id,mode),dark)
  hadd ns.ted accent $iif($readini(%f,n,%id,accent) isnum,$readini(%f,n,%id,accent),75)
  hadd ns.ted acc1 $iif($readini(%f,n,%id,acc1) != $null,$readini(%f,n,%id,acc1),#ff2e88)
  hadd ns.ted acc2 $iif($readini(%f,n,%id,acc2) != $null,$readini(%f,n,%id,acc2),#2ee6ff)
  hadd ns.ted nickcols $iif($readini(%f,n,%id,nickcols) != $null,$readini(%f,n,%id,nickcols),64 65 66 68 69 70 71 73 74 75 77 80 84 85)
  ; a theme of your own may carry its own 16 first colours (rgb= 16 triplets)
  ns.ted.tri2int $readini(%f,n,%id,rgb)
  if ($ns.ted.get(tri) != $null) {
    hadd ns.ted pal $ns.ted.get(tri)
    hadd ns.ted pc 1
  }
}
; "join:68,part:77,..." -> value for one key
alias ns.ted.evof {
  var %kv, %list = $1, %j = 1
  while ($gettok(%list,%j,44) != $null) {
    %kv = $v1
    inc %j
    if ($gettok(%kv,1,58) == $2) return $gettok(%kv,2,58)
  }
  return $null
}
; an imported MTS theme: the 26 colours of its Colors line, its own 16 colours (RGBColors), BaseColors, font, prefix
alias -l ns.ted.loadmts {
  var %id = $1, %file = $mid($1,5), %f = $ns.mts.file(%file), %cols = $ns.ted.mtsval(%f,colors), %dflt = $readini($ns.theme.file,n,neonnight,colors), %i = 1, %v
  var %bc = $ns.ted.mtsval(%f,basecolors), %fd = $ns.ted.mtsval(%f,fontdefault)
  hadd ns.ted file %f
  while (%i <= 26) {
    %v = $ns.trim($gettok(%cols,%i,44))
    hadd ns.ted $+(c,%i) $iif(%v isnum && %v >= 0 && %v <= 98,$int(%v),$gettok(%dflt,%i,44))
    inc %i
  }
  ; colours 27-31 of the colour dialog and NeonScript's event colours are derived when the theme is applied; carried along as extras
  hadd ns.ted extra $gettok(%cols,27-,44)
  ns.ted.tri2int $ns.ted.mtsval(%f,rgbcolors)
  if ($ns.ted.get(tri) != $null) {
    hadd ns.ted pal $ns.ted.get(tri)
    hadd ns.ted pc 1
  }
  %i = 1
  while (%i <= 4) {
    %v = $ns.trim($gettok(%bc,%i,44))
    hadd ns.ted $+(b,%i) $iif(%v isnum && %v >= 0 && %v <= 98,$int(%v),$gettok(15 12 8 14,%i,32))
    inc %i
  }
  %v = $ns.trim($gettok(%bc,2,44))
  hadd ns.ted accent $iif(%v isnum && %v >= 0 && %v <= 98,$int(%v),13)
  hadd ns.ted prefix $ns.ted.mtsval(%f,prefix)
  hadd ns.ted font $ns.trim($gettok(%fd,1,44))
  hadd ns.ted fsize $ns.trim($gettok(%fd,2,44))
  var %edited = $ns.ted.mtsval(%f,editedby)
  hadd ns.ted name $iif(%edited != $null,$ns.mts.name(%file),$+($ns.mts.name(%file),$chr(32),copy))
  hadd ns.ted desc $ns.ted.mtsval(%f,description)
  hadd ns.ted acc1 $ns.get(theme,acc1,#ff2e88)
  hadd ns.ted acc2 $ns.get(theme,acc2,#2ee6ff)
  hadd ns.ted nickcols $ns.get(theme,nickcols,64 65 66 68 69 70 71 73 74 75 77 80 84 85)
  ns.ted.derive
}
; what ns.mts.apply and ns.mts.storeev derive from an MTS theme's own colours (items 27-31, the event colours, light or dark)
alias ns.ted.derive {
  if ($ns.ted.get(kind) != mts) return
  var %t = $ns.ted.get(b1), %nk = $ns.ted.get(accent), %hi = $ns.ted.get(b3), %br = $ns.ted.get(b4), %bg = $ns.ted.pal($ns.ted.get(c1))
  hadd -m ns.ted b2 %nk
  hadd -m ns.ted c27 $ns.ted.get(c12)
  hadd -m ns.ted c28 $ns.ted.get(c26)
  hadd -m ns.ted c29 $ns.ted.get(c1)
  hadd -m ns.ted c30 $ns.ted.get(c12)
  hadd -m ns.ted c31 $ns.ted.get(c1)
  var %k = 1, %list = 9 7 4 4 %hi 11 %nk 10 %br %t %br %hi 13 4 9 11 8
  while (%k <= 17) {
    hadd -m ns.ted $+(e,%k) $gettok(%list,%k,32)
    inc %k
  }
  hadd -m ns.ted mode $iif($calc($ns.r8(%bg) + $ns.g8(%bg) + $ns.b8(%bg)) < 384,dark,light)
}

; ---------------------------------------------------------------- saving
; write the working copy as a theme of your own (themes_user.ini, id "u_<slug>"); returns the id
alias ns.ted.save {
  var %name = $ns.trim($ns.ted.get(name)), %slug = $regsubex($lower(%name),/[^a-z0-9]/g,), %id, %i = 1, %cols, %ev, %k, %order, %rgb
  if (%name == $null) || (%slug == $null) return $null
  %id = $+(u_,%slug)
  while (%i <= 31) {
    %cols = $+(%cols,$iif(%cols != $null,$chr(44)),$ns.ted.get($+(c,%i)))
    inc %i
  }
  %i = 1
  while ($gettok($ns.ted.evkeys,%i,32) != $null) {
    %k = $gettok($ns.ted.evkeys,%i,32)
    %ev = $+(%ev,$iif(%ev != $null,$chr(44)),%k,:,$ns.ted.get($+(e,%i)))
    inc %i
  }
  writeini -n $qt($ns.theme.ufile) %id name %name
  writeini -n $qt($ns.theme.ufile) %id desc $iif($ns.ted.get(desc) != $null,$ns.ted.get(desc),My theme)
  writeini -n $qt($ns.theme.ufile) %id mode $ns.ted.get(mode)
  writeini -n $qt($ns.theme.ufile) %id colors %cols
  writeini -n $qt($ns.theme.ufile) %id accent $ns.ted.get(accent)
  writeini -n $qt($ns.theme.ufile) %id acc1 $ns.ted.get(acc1)
  writeini -n $qt($ns.theme.ufile) %id acc2 $ns.ted.get(acc2)
  writeini -n $qt($ns.theme.ufile) %id ev %ev
  writeini -n $qt($ns.theme.ufile) %id nickcols $ns.ted.get(nickcols)
  if ($ns.ted.get(pc) == 1) writeini -n $qt($ns.theme.ufile) %id rgb $ns.ted.int2tri($ns.ted.get(pal))
  else remini $qt($ns.theme.ufile) %id rgb
  %order = $ns.theme.uids
  if (!$istok(%order,%id,32)) writeini -n $qt($ns.theme.ufile) themes order $replace($ns.trim(%order %id),$chr(32),$chr(44))
  return %id
}
; write the working copy wherever its kind belongs; returns the theme id, or $null with the reason in ns.ted "err"
alias ns.ted.commit {
  var %id
  if ($hget(ns.ted,err) != $null) hdel ns.ted err
  if ($ns.ted.get(kind) == mts) %id = $ns.ted.commitmts
  else {
    %id = $ns.ted.save
    if (!%id) hadd -m ns.ted err Give the theme a name first.
    else {
      hadd -m ns.ted base %id
      hadd -m ns.ted kind user
    }
  }
  if (%id) .signal -n ns.mtschanged
  return %id
}
; an MTS theme is saved as <slug>.mts in the library: a copy of the original with the colours changed
alias -l ns.ted.commitmts {
  var %name = $ns.trim($ns.ted.get(name)), %slug = $ns.ted.mtsslug(%name), %src = $ns.ted.get(file), %dst
  if (%slug == $null) {
    hadd -m ns.ted err Give the theme a name first.
    return $null
  }
  %dst = $ns.mts.file($+(%slug,.mts))
  if ($exists(%dst)) && ($ns.ted.mtsval(%dst,editedby) == $null) {
    hadd -m ns.ted err $+($chr(34),%slug,.mts,$chr(34)) is one of your imported themes - pick another name, the original stays untouched.
    return $null
  }
  if (!$isdir($ns.mts.dir)) .mkdir $qt($ns.mts.dir)
  if (!$ns.ted.mtswrite(%src,%dst)) {
    hadd -m ns.ted err Could not write $nopath(%dst) $+ .
    return $null
  }
  hadd -m ns.ted file %dst
  hadd -m ns.ted base $+(mts:,%slug,.mts)
  ; the edited theme is the active one: pick the new colours up
  if ($ns.get(mts,file) == $+(%slug,.mts)) ns.mts.apply $+(%slug,.mts)
  return $+(mts:,%slug,.mts)
}
; Copy an .mts byte for byte (BOM, glyphs, control codes, line endings) and replace only the lines the editor owns:
; Name, Colors (the first 26 values; extras are kept), BaseColors (the accent), EditedBy, BasedOn.  Missing ones are
; added after the [mts] line.  Returns 1 when written.   ns.ted.mtswrite <source.mts> <destination.mts>
alias ns.ted.mtswrite {
  var %src = $1, %dst = $2, %size = $file(%src).size, %pos = 1, %lf, %cut, %len, %peek, %key, %crlf = 0, %cols, %i, %x, %b1, %nl, %skip = 0, %hdrdone = 0
  var %oc = $ns.ted.mtsval(%src,colors), %ob = $ns.ted.mtsval(%src,basecolors), %acc = $ns.ted.get(accent), %have = $null, %keys = name colors basecolors editedby basedon
  if (!%size) return 0
  ; the lines that replace the file's own (kept in the ns.ted hash: text with commas is safe there)
  %i = 1
  while (%i <= 26) {
    %cols = $+(%cols,$iif(%cols != $null,$chr(44)),$ns.ted.get($+(c,%i)))
    inc %i
  }
  if ($gettok(%oc,27-,44) != $null) %cols = $+(%cols,$chr(44),$gettok(%oc,27-,44))
  if (%ob != $null) %b1 = $puttok(%ob,%acc,2,44)
  elseif (%acc != 13) %b1 = $+($ns.ted.get(b1),$chr(44),%acc,$chr(44),$ns.ted.get(b3),$chr(44),$ns.ted.get(b4))
  hdel -w ns.ted nl.*
  hadd -m ns.ted nl.name Name $ns.ted.get(name)
  hadd -m ns.ted nl.colors Colors %cols
  if (%b1 != $null) hadd -m ns.ted nl.basecolors BaseColors %b1
  hadd -m ns.ted nl.editedby EditedBy NeonScript theme editor
  %x = $ns.ted.mtsval(%src,basedon)
  hadd -m ns.ted nl.basedon BasedOn $iif(%x != $null,%x,$nopath(%src))
  ; which of them the file has already
  %i = 1
  while ($gettok(%keys,%i,32) != $null) {
    %x = $v1
    inc %i
    if ($ns.ted.mtsval(%src,%x) != $null) %have = %have %x
  }
  ; a file can hold several schemes (a Colors and a BaseColors line each): only the line the theme engine reads - the last one -
  ; is replaced, the others stay as they were
  %i = 1
  while ($gettok(%keys,%i,32) != $null) {
    %x = $v1
    inc %i
    hadd -m ns.ted $+(nl.at.,%x) $ns.ted.mtsline(%src,%x)
  }
  bread $qt(%src) 0 %size &nsmin
  bunset &nsmout
  ; CRLF or LF?  (the lines the editor adds follow the file)
  %lf = $bfind(&nsmin,1,$chr(10))
  if (%lf > 1) && ($bvar(&nsmin,$calc(%lf - 1)) == 13) %crlf = 1
  %nl = $iif(%crlf,13 10,10)
  if ($bvar(&nsmin,1,3) == 239 187 191) %skip = 3
  var %ln = 0
  while (%pos <= %size) {
    inc %ln
    %lf = $bfind(&nsmin,%pos,$chr(10))
    if (%lf) %len = $calc(%lf - %pos + 1)
    else %len = $calc(%size - %pos + 1)
    %cut = $calc(%pos + %len - 1)
    if (%lf) dec %cut
    if (%cut >= %pos) && ($bvar(&nsmin,%cut) == 13) dec %cut
    ; the first bytes of the line (after a byte order mark), to see which key it is
    %x = $calc(%cut - %pos + 1 - $iif(%pos == 1,%skip,0))
    if (%x > 40) %x = 40
    %peek = $null
    if (%x > 0) %peek = $bvar(&nsmin,$calc(%pos + $iif(%pos == 1,%skip,0)),%x).text
    %key = $null
    if ($regex(ns.tw,%peek,/^(\w+)\s/)) %key = $lower($regml(ns.tw,1))
    if (%key != $null) && ($istok(%keys,%key,32)) && ($hget(ns.ted,$+(nl.,%key)) != $null) && ($hget(ns.ted,$+(nl.at.,%key)) == %ln) {
      bset -t &nsmout $calc($bvar(&nsmout,0) + 1) $hget(ns.ted,$+(nl.,%key))
      bset &nsmout $calc($bvar(&nsmout,0) + 1) %nl
    }
    else {
      bcopy &nsmout $calc($bvar(&nsmout,0) + 1) &nsmin %pos %len
      ; just after the [mts] line: add what the file does not have
      if (!%hdrdone) && ($regex(ns.th,%peek,/^\[mts\]/i)) {
        %hdrdone = 1
        if (!%lf) bset &nsmout $calc($bvar(&nsmout,0) + 1) %nl
        %i = 1
        while ($gettok(%keys,%i,32) != $null) {
          %x = $v1
          inc %i
          if (!$istok(%have,%x,32)) && ($hget(ns.ted,$+(nl.,%x)) != $null) {
            bset -t &nsmout $calc($bvar(&nsmout,0) + 1) $hget(ns.ted,$+(nl.,%x))
            bset &nsmout $calc($bvar(&nsmout,0) + 1) %nl
          }
        }
      }
    }
    %pos = $calc(%pos + %len)
  }
  ; no [mts] line at all: they go at the end
  if (!%hdrdone) {
    if ($bvar(&nsmout,0) > 0) && ($bvar(&nsmout,$bvar(&nsmout,0)) != 10) bset &nsmout $calc($bvar(&nsmout,0) + 1) %nl
    %i = 1
    while ($gettok(%keys,%i,32) != $null) {
      %x = $v1
      inc %i
      if (!$istok(%have,%x,32)) && ($hget(ns.ted,$+(nl.,%x)) != $null) {
        bset -t &nsmout $calc($bvar(&nsmout,0) + 1) $hget(ns.ted,$+(nl.,%x))
        bset &nsmout $calc($bvar(&nsmout,0) + 1) %nl
      }
    }
  }
  hdel -w ns.ted nl.*
  bwrite -c $qt(%dst) 0 -1 &nsmout
  return $iif($file(%dst).size > 0,1,0)
}
alias ns.ted.delete {
  var %id = $1
  if ($ns.ted.kind(%id) == mts) {
    if (!$ns.ted.mine(%id)) return
    var %file = $mid(%id,5)
    if ($ns.get(mts,file) == %file) {
      ns.mts.off
      ns.theme.apply $ns.get(theme,lastbuiltin,neonnight)
    }
    .remove $qt($ns.mts.file(%file))
    .signal -n ns.mtschanged
    return
  }
  if ($left(%id,2) != u_) return
  var %rest = $ns.trim($remtok($ns.theme.uids,%id,1,32))
  remini $qt($ns.theme.ufile) %id
  if (%rest == $null) remini $qt($ns.theme.ufile) themes order
  else writeini -n $qt($ns.theme.ufile) themes order $replace(%rest,$chr(32),$chr(44))
  if ($ns.theme.current == %id) ns.theme.apply neonnight
  .signal -n ns.mtschanged
}

; ---------------------------------------------------------------- pictures (drawn into a hidden picture window)
; a sample of chat in the working copy's colours.  mIRC limits a picture window to the room available in its own
; window, so the real size is read back and everything is laid out relative to it.
alias ns.ted.preview {
  var %w = 600, %h = 170, %f = $ns.data(tmp\ted_preview.bmp), %lh = 15, %y = 6, %r = 1, %x, %tw, %lw, %bg, %fg, %col, %txt, %nick
  .mkdir $qt($ns.data(tmp))
  if ($window(@nstedpv)) window -c @nstedpv
  ; (a window's frame takes 16 x 39 pixels off the drawing area, so ask for that much more)
  window -hp @nstedpv 0 0 $calc(%w + 16) $calc(%h + 39)
  if ($window(@nstedpv).dw > 100) %w = $window(@nstedpv).dw
  if ($window(@nstedpv).dh > 60) %h = $window(@nstedpv).dh
  %bg = $ns.ted.pal($ns.ted.get(c1))
  %fg = $ns.ted.pal($ns.ted.get(c12))
  %tw = $int($calc(%w * 0.13))
  %lw = $int($calc(%w * 0.13))
  drawrect -rf @nstedpv %bg 1 0 0 %w %h
  ; treebar strip on the left, nick list on the right
  drawrect -rf @nstedpv $ns.ted.pal($ns.ted.get(c29)) 1 0 0 %tw %h
  drawtext -r @nstedpv $ns.ted.pal($ns.ted.get(c30)) Tahoma 10 5 6 Status
  drawtext -r @nstedpv $ns.ted.pal($ns.ted.get(c30)) Tahoma 10 5 21 #neon
  drawtext -r @nstedpv $ns.ted.pal($ns.ted.get(c30)) Tahoma 10 5 36 Kira
  drawrect -rf @nstedpv $ns.ted.pal($ns.ted.get(c24)) 1 $calc(%w - %lw) 0 %lw %h
  drawtext -r @nstedpv $ns.ted.pal($ns.ted.get(c25)) Tahoma 10 $calc(%w - %lw + 5) 6 @TestNick
  drawtext -r @nstedpv $ns.ted.pal($ns.ted.get(c25)) Tahoma 10 $calc(%w - %lw + 5) 21 $chr(37) $+ Half
  drawtext -r @nstedpv $ns.ted.pal($ns.ted.get(c25)) Tahoma 10 $calc(%w - %lw + 5) 36 +Zed
  drawtext -r @nstedpv $ns.ted.pal($ns.ted.get(c25)) Tahoma 10 $calc(%w - %lw + 5) 51 Nova
  %x = $calc(%tw + 8)
  var %lim = $calc(%h - 40)
  while (%r <= 10) && (%y < %lim) {
    %nick = $null
    if (%r == 1) { %col = $ns.ted.pal($ns.ted.get(c8)) | %txt = -> Nova (nova@host.example) has joined #neon }
    elseif (%r == 2) { %nick = Nova | %col = %fg | %txt = hey everyone, nice to be here }
    elseif (%r == 3) { %nick = TestNick | %col = $ns.ted.pal($ns.ted.get(c16)) | %txt = thanks, glad to be here }
    elseif (%r == 4) { %col = $ns.ted.pal($ns.ted.get(c4)) | %txt = <Kira> TestNick: your build is ready }
    elseif (%r == 5) { %col = $ns.ted.pal($ns.ted.get(c2)) | %txt = * Nova raises a glass }
    elseif (%r == 6) { %col = $ns.ted.pal($ns.ted.get(c10)) | %txt = * Owner sets mode +o Nova }
    elseif (%r == 7) { %col = $ns.ted.pal($ns.ted.get(c19)) | %txt = * Nova changed the topic to: Welcome }
    elseif (%r == 8) { %col = $ns.ted.pal($ns.ted.get(c9)) | %txt = * Kira was kicked by Owner (behave) }
    elseif (%r == 9) { %col = $ns.ted.pal($ns.ted.get(c13)) | %txt = -Admin:#neon- maintenance at midnight }
    else { %col = $ns.ted.pal($ns.ted.get(c26)) | %txt = (gray text: timestamps and quiet bits) }
    drawtext -r @nstedpv $ns.ted.pal($ns.ted.get(c26)) Consolas 10 %x %y 12:0 $+ %r
    if (%nick) {
      drawtext -r @nstedpv $ns.ted.pal($ns.nickcol(%nick)) Consolas 10 $calc(%x + 40) %y < $+ %nick $+ >
      drawtext -r @nstedpv %col Consolas 10 $calc(%x + 40 + ($len(%nick) + 3) * 7) %y %txt
    }
    else drawtext -r @nstedpv %col Consolas 10 $calc(%x + 40) %y %txt
    inc %y %lh
    inc %r
  }
  ; edit box along the bottom
  drawrect -rf @nstedpv $ns.ted.pal($ns.ted.get(c22)) 1 %tw $calc(%h - 20) $calc(%w - %tw - %lw) 20
  drawtext -r @nstedpv $ns.ted.pal($ns.ted.get(c23)) Consolas 10 $calc(%tw + 8) $calc(%h - 16) /neon themeedit_
  drawsave @nstedpv %f
  window -c @nstedpv
  return %f
}
; all 99 palette colours with their numbers
alias ns.ted.palette {
  var %w = 600, %h = 126, %cols = 11, %i = 0, %x, %y, %cw, %rh, %f = $ns.data(tmp\ted_palette.bmp), %sel = $1
  .mkdir $qt($ns.data(tmp))
  if ($window(@nstedpal)) window -c @nstedpal
  window -hp @nstedpal 0 0 $calc(%w + 16) $calc(%h + 39)
  if ($window(@nstedpal).dw > 100) %w = $window(@nstedpal).dw
  if ($window(@nstedpal).dh > 60) %h = $window(@nstedpal).dh
  %cw = $calc(%w / %cols)
  %rh = $calc(%h / 9)
  drawrect -rf @nstedpal $rgb(30,31,44) 1 0 0 %w %h
  while (%i <= 98) {
    %x = $int($calc($int($calc(%i % %cols)) * %cw + 1))
    %y = $int($calc($int($calc(%i / %cols)) * %rh + 1))
    drawrect -rf @nstedpal $ns.ted.pal(%i) 1 %x %y $int($calc(%cw - 2)) $int($calc(%rh - 2))
    drawtext -r @nstedpal $iif($calc($ns.r8($ns.ted.pal(%i)) + $ns.g8($ns.ted.pal(%i)) + $ns.b8($ns.ted.pal(%i))) > 380,$rgb(10,10,20),$rgb(240,240,250)) Tahoma 9 $calc(%x + 3) $calc(%y + 2) %i
    if (%i == %sel) drawrect -r @nstedpal $rgb(255,255,255) 2 %x %y $int($calc(%cw - 2)) $int($calc(%rh - 2))
    inc %i
  }
  drawsave @nstedpal %f
  window -c @nstedpal
  return %f
}
; a small thumbnail for the gallery (a user theme has no shipped picture): the same sample, smaller
alias ns.ted.thumb {
  ns.ted.load $1
  return $ns.ted.preview
}

; ---------------------------------------------------------------- export as a classic .mts
; ns.ted.exportmts <file>   - Colors / RGBColors / BaseColors from the working copy, templates from the shipped example
alias ns.ted.exportmts {
  var %out = $1, %tpl = $ns.data(mts\irssi_night.mts), %i = 1, %n = $lines(%tpl), %l, %cols, %rgb, %k, %c, %base
  if ($exists(%out)) .remove $qt(%out)
  %k = 1
  while (%k <= 26) {
    %cols = $+(%cols,$iif(%cols != $null,$chr(44)),$ns.ted.get($+(c,%k)))
    inc %k
  }
  %k = 0
  while (%k < 16) {
    %c = $ns.ted.pal(%k)
    %rgb = $+(%rgb,$iif(%rgb != $null,$chr(32)),$ns.r8(%c),$chr(44),$ns.g8(%c),$chr(44),$ns.b8(%c))
    inc %k
  }
  %base = $+($ns.ted.get(c12),$chr(44),$ns.ted.get(accent),$chr(44),$ns.ted.get(c4),$chr(44),$ns.ted.get(c26))
  write $qt(%out) [mts]
  write $qt(%out) MTSVersion 1.10
  write $qt(%out) Name $ns.ted.get(name)
  write $qt(%out) Author NeonScript theme editor
  write $qt(%out) Description $iif($ns.ted.get(desc) != $null,$ns.ted.get(desc),A theme made with the NeonScript theme editor.)
  write $qt(%out) Colors %cols
  write $qt(%out) RGBColors %rgb
  write $qt(%out) BaseColors %base
  write $qt(%out) FontDefault Consolas, 11
  write $qt(%out) Prefix -!-
  while (%i <= %n) {
    %l = $read(%tpl,n,%i)
    inc %i
    if ($left(%l,1) == $chr(59)) || ($regex(ns.tk,%l,/^(Textchan|ActionChan|NoticeChan|TextQuery|ActionQuery|Join|JoinSelf|Part|Quit|Kick|KickSelf|Nick|NickSelf|Mode|Topic|Invite|RAW\.)/i)) write $qt(%out) %l
  }
  return %out
}
; export whatever is being edited to a file: an MTS theme is copied (colours changed), the others get the shipped templates
alias ns.ted.exportfile {
  var %ok
  if ($ns.ted.get(kind) == mts) %ok = $ns.ted.mtswrite($ns.ted.get(file),$1)
  else %ok = $ns.ted.exportmts($1)
  .signal -n ns.mtschanged
  if ($isalias(ns.mts.changed)) ns.mts.changed
}

; ---------------------------------------------------------------- the dialog (used when the native helper is off)
alias neon.themeedit {
  var %id = $1
  if (%id == dialog) %id = $2
  if ($right(%id,4) == .mts) && ($left(%id,4) != mts:) %id = $+(mts:,%id)
  if (%id == $null) || (!$ns.ted.valid(%id)) %id = $ns.theme.current
  if (!$ns.ted.valid(%id)) %id = neonnight
  hadd -m ns.uis tedstart %id
  set -u120 %ns.ted.start %id
  if ($1 != dialog) && ($ns.ted.panel.ok) {
    if ($ns.ted.panel.open(%id)) return
  }
  ns.dlg ns_ted ns_ted
}
dialog ns_ted {
  title "Theme Editor"
  size -1 -1 410 282
  option dbu
  icon 1, 0 0 410 30, $mircexe, 0, noborder
  text "Start from:", 2, 6 37 36 9
  combo 3, 44 35 120 100, drop
  text "Name:", 4, 172 37 24 9
  edit "", 5, 198 35 110 11, autohs
  text "Mode:", 6, 314 37 22 9
  combo 7, 338 35 60 60, drop
  list 10, 6 50 124 168, size vsbar
  text "Colour (0-98):", 11, 138 52 42 9
  edit "", 12, 182 50 26 11, autohs limit 2
  button "<", 13, 212 49 14 12
  button ">", 14, 228 49 14 12
  text "", 15, 246 52 60 9
  text "Accent (NeonScript highlights):", 17, 138 66 100 9
  edit "", 18, 240 64 26 11, autohs limit 2
  text "", 19, 270 66 60 9
  icon 30, 138 80 266 80, $mircexe, 0, noborder
  icon 31, 138 164 266 54, $mircexe, 0, noborder
  text "Pick a line on the left, then type a number or use < and >.  The picture shows what chat will look like; the grid below it is every colour mIRC has.", 32, 6 222 398 18
  button "Save", 40, 6 244 50 13
  button "Apply", 41, 60 244 50 13
  button "Delete", 42, 114 244 50 13
  button "Export .mts...", 43, 168 244 60 13
  text "", 44, 6 262 300 9
  button "Close", 45, 356 262 48 13, ok cancel
}
on *:DIALOG:ns_ted:init:*:{
  did -g ns_ted 1 $ns.asset(header_tedit.png)
  did -a ns_ted 7 dark
  did -a ns_ted 7 light
  var %sel = $edfillcombo(%ns.ted.start)
  edload $gettok($edall,%sel,32)
}
alias -l edall return $ns.theme.entries
; the "Start from" list: built-in themes, then yours (marked *), then the imported MTS ones; returns the position of $1
alias -l edfillcombo {
  var %i = 1, %id, %all = $edall, %sel = 1
  did -r ns_ted 3
  while ($gettok(%all,%i,32) != $null) {
    %id = $v1
    inc %i
    did -a ns_ted 3 $iif($ns.ted.mine(%id),$+(*,$chr(32))) $+ $ns.theme.ename(%id)
    if (%id == $1) %sel = $calc(%i - 1)
  }
  did -c ns_ted 3 %sel
  return %sel
}
alias -l edload {
  ns.ted.load $1
  var %i = 1, %n = $ns.ted.count
  did -ra ns_ted 5 $ns.ted.get(name)
  did -c ns_ted 7 $iif($ns.ted.get(mode) == light,2,1)
  ; an MTS theme's light or dark follows from its background
  if ($ns.ted.get(kind) == mts) did -b ns_ted 7
  else did -e ns_ted 7
  did -r ns_ted 10
  while (%i <= %n) {
    did -a ns_ted 10 $edrow(%i)
    inc %i
  }
  did -c ns_ted 10 1
  edpick 1
  did -ra ns_ted 18 $ns.ted.get(accent)
  edredraw
}
alias -l edrow return $+($ns.ted.itemname($1),$chr(32),$chr(32),$chr(8212),$chr(32),$chr(32),$ns.ted.val($1),$chr(32),$chr(40),$ns.ted.hex($ns.ted.val($1)),$chr(41))
alias -l edpick {
  var %n = $1
  if (!%n) return
  did -ra ns_ted 12 $ns.ted.val(%n)
  did -ra ns_ted 15 $ns.ted.hex($ns.ted.val(%n))
}
alias -l edredraw {
  did -g ns_ted 30 $ns.ted.preview
  did -g ns_ted 31 $ns.ted.palette($ns.ted.val($did(ns_ted,10).sel))
  did -ra ns_ted 19 $ns.ted.hex($ns.ted.get(accent))
}
alias -l edset {
  var %sel = $did(ns_ted,10).sel, %v = $1
  if (!%sel) return
  if (%v !isnum) || (%v < 0) || (%v > 98) return
  ns.ted.setval %sel %v
  did -o ns_ted 10 %sel $edrow(%sel)
  did -ra ns_ted 15 $ns.ted.hex(%v)
  edredraw
}
on *:DIALOG:ns_ted:sclick:3:{
  var %id = $gettok($edall,$did(ns_ted,3).sel,32)
  if (%id) edload %id
}
on *:DIALOG:ns_ted:sclick:10:{ edpick $did(ns_ted,10).sel | edredraw }
on *:DIALOG:ns_ted:edit:12:{ if ($did(ns_ted,12).text isnum) edset $did(ns_ted,12).text }
on *:DIALOG:ns_ted:sclick:13:{
  var %v = $calc($did(ns_ted,12).text - 1)
  if (%v < 0) %v = 98
  did -ra ns_ted 12 %v
  edset %v
}
on *:DIALOG:ns_ted:sclick:14:{
  var %v = $calc($did(ns_ted,12).text + 1)
  if (%v > 98) %v = 0
  did -ra ns_ted 12 %v
  edset %v
}
on *:DIALOG:ns_ted:edit:18:{
  var %v = $did(ns_ted,18).text
  if (%v isnum) && (%v >= 0) && (%v <= 98) {
    hadd -m ns.ted accent %v
    ns.ted.derive
    did -ra ns_ted 19 $ns.ted.hex(%v)
  }
}
on *:DIALOG:ns_ted:edit:5:{ hadd -m ns.ted name $did(ns_ted,5).text }
on *:DIALOG:ns_ted:sclick:7:{ hadd -m ns.ted mode $did(ns_ted,7).text }
; accents (the two hex colours used for gradients): the nearest palette colours' hex values
alias -l edaccents {
  var %a = $ns.ted.get(accent)
  if ($ns.ted.get(kind) == mts) return
  hadd -m ns.ted acc1 $ns.ted.hex(%a)
  hadd -m ns.ted acc2 $ns.ted.hex($ns.ted.get(c26))
}
on *:DIALOG:ns_ted:sclick:40:{
  edaccents
  hadd -m ns.ted name $did(ns_ted,5).text
  var %id = $ns.ted.commit
  if (!%id) {
    did -ra ns_ted 44 $iif($ns.ted.get(err) != $null,$ns.ted.get(err),Give the theme a name first.)
    return
  }
  did -ra ns_ted 44 Saved as %id $+ . It is in the gallery now.
  var %sel = $edfillcombo(%id)
  hadd -m ns.ted base %id
}
on *:DIALOG:ns_ted:sclick:41:{
  edaccents
  hadd -m ns.ted name $did(ns_ted,5).text
  var %id = $ns.ted.commit
  if (!%id) {
    did -ra ns_ted 44 $iif($ns.ted.get(err) != $null,$ns.ted.get(err),Give the theme a name first.)
    return
  }
  ns.theme.apply %id
  did -ra ns_ted 44 Applied $ns.ted.get(name) $+ .
}
on *:DIALOG:ns_ted:sclick:42:{
  var %id = $ns.ted.get(base)
  if (!$ns.ted.mine(%id)) {
    did -ra ns_ted 44 Only your own themes (marked *) can be deleted.
    return
  }
  ns.ted.delete %id
  did -ra ns_ted 44 Deleted.
  dialog -x ns_ted
}
on *:DIALOG:ns_ted:sclick:43:{ ns.later ns.ted.exportask }
alias ns.ted.exportask {
  if (!$dialog(ns_ted)) return
  var %slug = $ns.ted.mtsslug($ns.ted.get(name)), %f = $sfile($+($ns.mts.dir,%slug,.mts),Export as an MTS theme,Save)
  if (!%f) return
  ns.ted.exportfile %f
  did -ra ns_ted 44 Exported $nopath(%f) - it is in the MTS list too.
}

; ============================================================================
;  Theme Studio - the HTML front end (data\ui\ted.html).  Needs the native helper (WebView2).
;  The page sends text lines (ready, load <id>, save|apply|export <payload>, delete <id>, close); what comes back is JSON
;  in small pieces: list items, template lines of an MTS theme, the theme as key/value pieces, status text.
;  Whatever the page sends is untrusted: ids must be in the theme list, every colour is checked, names are cleaned.
; ============================================================================
alias ns.ted.panel.ok return $iif($ns.ui.wv.ready && $ns.flag(ui,tedpanel,1),1,0)
alias ns.ted.panel.open {
  hadd -m ns.uis tedstart $1
  return $ns.ui.panel.open(ted,ted.html,1260,780,Theme Studio)
}
alias ns.ui.h.ted {
  if ($1 != msg) return
  var %v = $gettok($2-,1,32), %rest = $gettok($2-,2-,32)
  if (%v == ready) ns.ted.p.init
  elseif (%v == load) ns.ted.p.load $gettok(%rest,1,32)
  elseif (%v == save) ns.ted.p.save save %rest
  elseif (%v == apply) ns.ted.p.save apply %rest
  elseif (%v == export) ns.ted.p.export %rest
  elseif (%v == delete) ns.ted.p.delete $gettok(%rest,1,32)
  elseif (%v == close) ns.ui.panel.close ted
}
; JSON pieces
alias -l jq return $chr(34)
alias -l jx return $+($chr(123),$chr(34),type,$chr(34),:,$chr(34),$1,$chr(34))
; text made safe for a JSON string (taken from the ns.ted "jtmp" item, so commas and quotes in it are harmless)
alias ns.ted.jenc {
  var %b = $chr(92), %t = $hget(ns.ted,jtmp)
  %t = $replace(%t,%b,$+(%b,%b))
  %t = $replace(%t,$chr(34),$+(%b,$chr(34)),$chr(13),,$chr(10),$+(%b,n),$chr(9),$+(%b,t))
  %t = $replace(%t,$chr(2),$+(%b,u0002),$chr(3),$+(%b,u0003),$chr(15),$+(%b,u000f),$chr(22),$+(%b,u0016),$chr(29),$+(%b,u001d),$chr(31),$+(%b,u001f))
  return $regsubex(%t,/[\x00-\x1F]/g,)
}
alias -l p.post ns.ui.panel.post ted $1-
; the text the next $ns.ted.jenc encodes (an empty text really is empty)
alias -l jset {
  if ($hget(ns.ted,jtmp) != $null) hdel ns.ted jtmp
  if ($1- != $null) hadd -m ns.ted jtmp $1-
}
; {"type":"set","k":"<key>","v":"<value>"} - plain values only (numbers, hex, ids)
alias -l p.set p.post $jx(set) $+ $chr(44) $+ $jq $+ k $+ $jq $+ : $+ $jq $+ $1 $+ $jq $+ $chr(44) $+ $jq $+ v $+ $jq $+ : $+ $jq $+ $2- $+ $jq $+ $chr(125)
; the same for free text (names, templates, prefixes): goes through ns.ted.jenc
alias -l p.sets {
  jset $2-
  p.post $jx(set) $+ $chr(44) $+ $jq $+ k $+ $jq $+ : $+ $jq $+ $1 $+ $jq $+ $chr(44) $+ $jq $+ v $+ $jq $+ : $+ $jq $+ $ns.ted.jenc $+ $jq $+ $chr(125)
}
alias ns.ted.p.say {
  jset $2-
  p.post $jx(status) $+ $chr(44) $+ $jq $+ ok $+ $jq $+ : $+ $1 $+ $chr(44) $+ $jq $+ text $+ $jq $+ : $+ $jq $+ $ns.ted.jenc $+ $jq $+ $chr(125)
}
; the page is up: the list of themes, then the one to start from
alias ns.ted.p.init {
  var %id = $hget(ns.uis,tedstart)
  if (!$ns.ted.valid(%id)) %id = neonnight
  ns.ted.p.list %id
  ns.ted.p.load %id
}
alias ns.ted.p.list {
  var %all = $ns.theme.entries, %i = 1, %id
  p.post $jx(listreset) $+ $chr(125)
  while ($gettok(%all,%i,32) != $null) {
    %id = $v1
    inc %i
    jset $iif($ns.ted.kind(%id) == mts,$ns.mts.name($mid(%id,5)),$ns.theme.name(%id))
    p.post $jx(item) $+ $chr(44) $+ $jq $+ id $+ $jq $+ : $+ $jq $+ %id $+ $jq $+ $chr(44) $+ $jq $+ name $+ $jq $+ : $+ $jq $+ $ns.ted.jenc $+ $jq $+ $chr(44) $+ $jq $+ kind $+ $jq $+ : $+ $jq $+ $ns.ted.kind(%id) $+ $jq $+ $chr(44) $+ $jq $+ mine $+ $jq $+ : $+ $ns.ted.mine(%id) $+ $chr(125)
  }
  p.post $jx(listend) $+ $chr(44) $+ $jq $+ cur $+ $jq $+ : $+ $jq $+ $1 $+ $jq $+ $chr(125)
}
; palette integers -> "rrggbb,rrggbb,..."
alias -l hexlist {
  var %i = 1, %o, %v
  while (%i <= 16) {
    %v = $gettok($1-,%i,32)
    %o = $+(%o,$iif(%o != $null,$chr(44)),$base($ns.r8(%v),10,16,2),$base($ns.g8(%v),10,16,2),$base($ns.b8(%v),10,16,2))
    inc %i
  }
  return $lower(%o)
}
alias ns.ted.p.load {
  var %id = $1, %kind, %i, %k, %v, %keys = textchan actionchan noticechan textquery actionquery join joinself part quit kick kickself nick nickself mode topic invite, %cols, %evs
  if (!$ns.ted.valid(%id)) {
    ns.ted.p.say 0 That theme is not in the list.
    return
  }
  ns.ted.load %id
  %kind = $ns.ted.get(kind)
  p.post $jx(tplreset) $+ $chr(125)
  if (%kind == mts) {
    %i = 1
    while ($gettok(%keys,%i,32) != $null) {
      %k = $v1
      inc %i
      %v = $ns.ted.mtsval($ns.ted.get(file),%k)
      if (%v == $null) continue
      if ($left($ns.trim(%v),7) == !script) continue
      jset $left(%v,900)
      p.post $jx(tpl) $+ $chr(44) $+ $jq $+ k $+ $jq $+ : $+ $jq $+ %k $+ $jq $+ $chr(44) $+ $jq $+ v $+ $jq $+ : $+ $jq $+ $ns.ted.jenc $+ $jq $+ $chr(125)
    }
  }
  p.set id %id
  p.set kind %kind
  p.set mine $ns.ted.mine(%id)
  p.sets name $ns.ted.get(name)
  p.sets desc $ns.ted.get(desc)
  p.set mode $ns.ted.get(mode)
  p.set accent $ns.ted.get(accent)
  p.set acc1 $remove($ns.ted.get(acc1),$chr(35))
  p.set acc2 $remove($ns.ted.get(acc2),$chr(35))
  %i = 1
  while (%i <= 31) {
    %cols = $+(%cols,$iif(%cols != $null,$chr(44)),$ns.ted.get($+(c,%i)))
    inc %i
  }
  p.set c %cols
  %i = 1
  while (%i <= 17) {
    %evs = $+(%evs,$iif(%evs != $null,$chr(44)),$ns.ted.get($+(e,%i)))
    inc %i
  }
  p.set e %evs
  p.set nick $replace($ns.ted.get(nickcols),$chr(32),$chr(44))
  p.set pal $hexlist($ns.ted.get(pal))
  p.set pal0 $hexlist($ns.ted.get(pal0))
  p.set pc $ns.ted.get(pc)
  if (%kind == mts) {
    p.set base4 $+($ns.ted.get(b1),$chr(44),$ns.ted.get(b2),$chr(44),$ns.ted.get(b3),$chr(44),$ns.ted.get(b4))
    p.sets prefix $ns.ted.get(prefix)
    p.sets font $ns.ted.get(font)
  }
  p.post $jx(editend) $+ $chr(125)
}
; ---- what the page sends back
alias -l pl.int return $iif($1 isnum && $1 == $int($1) && $1 >= 0 && $1 <= 98,1,0)
; take the page's payload into the working copy ("kind=.. base=.. mode=.. accent=.. acc1=.. acc2=.. pc=.. c=.. e=.. pal=.. nick=.. name=<rest>")
alias -l ns.ted.p.take {
  var %p = $1-, %np = $pos(%p,$+($chr(32),name=)), %head, %name, %i = 1, %t, %k, %v, %id, %n, %c, %want
  if (!%np) return 0
  %head = $left(%p,$calc(%np - 1))
  %name = $left($regsubex($ns.trim($mid(%p,$calc(%np + 6))),/[\x00-\x1F]/g,),60)
  if ($hget(ns.tin)) hfree ns.tin
  hmake ns.tin 20
  while ($gettok(%head,%i,32) != $null) {
    %t = $v1
    inc %i
    hadd ns.tin $gettok(%t,1,61) $gettok(%t,2-,61)
  }
  %id = $hget(ns.tin,base)
  if (!$ns.ted.valid(%id)) return 0
  ns.ted.load %id
  ; the item colours (26 for an MTS theme, 31 otherwise)
  %want = $iif($ns.ted.get(kind) == mts,26,31)
  %c = $hget(ns.tin,c)
  if ($numtok(%c,44) < %want) return 0
  %i = 1
  while (%i <= %want) {
    %v = $gettok(%c,%i,44)
    if (!$pl.int(%v)) return 0
    hadd -m ns.ted $+(c,%i) %v
    inc %i
  }
  %v = $hget(ns.tin,accent)
  if (!$pl.int(%v)) return 0
  hadd -m ns.ted accent %v
  if ($ns.ted.get(kind) != mts) {
    %c = $hget(ns.tin,e)
    if ($numtok(%c,44) != 17) return 0
    %i = 1
    while (%i <= 17) {
      %v = $gettok(%c,%i,44)
      if (!$pl.int(%v)) return 0
      hadd -m ns.ted $+(e,%i) %v
      inc %i
    }
    if (!$regex(ns.tin,$hget(ns.tin,acc1),/^[0-9a-f]{6}$/i)) return 0
    if (!$regex(ns.tin,$hget(ns.tin,acc2),/^[0-9a-f]{6}$/i)) return 0
    hadd -m ns.ted acc1 $+(#,$lower($hget(ns.tin,acc1)))
    hadd -m ns.ted acc2 $+(#,$lower($hget(ns.tin,acc2)))
    %c = $replace($hget(ns.tin,nick),$chr(44),$chr(32))
    %n = $numtok(%c,32)
    if (%n < 1) || (%n > 24) return 0
    %i = 1
    while (%i <= %n) {
      if (!$pl.int($gettok(%c,%i,32))) return 0
      inc %i
    }
    hadd -m ns.ted nickcols %c
    if (!$istok(dark light,$hget(ns.tin,mode),32)) return 0
    hadd -m ns.ted mode $hget(ns.tin,mode)
    ; the theme's own 16 colours
    if ($hget(ns.tin,pc) == 1) {
      %c = $hget(ns.tin,pal)
      if ($numtok(%c,44) != 16) return 0
      var %o
      %i = 1
      while (%i <= 16) {
        %v = $gettok(%c,%i,44)
        if (!$regex(ns.tin,%v,/^[0-9a-f]{6}$/i)) return 0
        %o = %o $rgb($base($mid(%v,1,2),16,10),$base($mid(%v,3,2),16,10),$base($mid(%v,5,2),16,10))
        inc %i
      }
      hadd -m ns.ted pal $ns.trim(%o)
      hadd -m ns.ted pc 1
    }
  }
  else ns.ted.derive
  hadd -m ns.ted name %name
  hfree ns.tin
  return 1
}
alias ns.ted.p.save {
  var %mode = $1, %id
  if (!$ns.ted.p.take($2-)) {
    ns.ted.p.say 0 That did not look right - nothing was saved.
    return
  }
  %id = $ns.ted.commit
  if (!%id) {
    ns.ted.p.say 0 $iif($ns.ted.get(err) != $null,$ns.ted.get(err),Could not save.)
    return
  }
  if (%mode == apply) ns.theme.apply %id
  ns.ted.p.list %id
  ns.ted.p.load %id
  ns.ted.p.say 1 $iif(%mode == apply,Saved and applied,Saved) as $+($chr(34),$ns.theme.ename(%id),$chr(34)) $+ .
}
alias ns.ted.p.export {
  if (!$ns.ted.p.take($1-)) {
    ns.ted.p.say 0 That did not look right - nothing was exported.
    return
  }
  ns.later ns.ted.p.exportask
}
alias ns.ted.p.exportask {
  var %slug = $ns.ted.mtsslug($ns.ted.get(name)), %f
  if (%slug == $null) %slug = mytheme
  %f = $sfile($+($ns.mts.dir,%slug,.mts),Export as an MTS theme,Save)
  if (!%f) {
    ns.ted.p.say 1 Export cancelled.
    return
  }
  ns.ted.exportfile %f
  ns.ted.p.say 1 Exported $nopath(%f) $+ .
}
alias ns.ted.p.delete {
  var %id = $1
  if (!$ns.ted.valid(%id)) || (!$ns.ted.mine(%id)) {
    ns.ted.p.say 0 Only your own themes can be deleted.
    return
  }
  ns.ted.delete %id
  ns.ted.p.list neonnight
  ns.ted.p.load neonnight
  ns.ted.p.say 1 Deleted.
}
