; ============================================================================
;  NeonScript 2026  ::  secret protection
;  Saved passwords and bouncer tokens (profiles.ini: pass, srvpass, bnctoken) are encrypted with
;  Windows DPAPI by neonsec.dll - a 5 KB open-source helper (tools\dll\neonsec.c, MIT licence).
;  The DLL is optional: without it everything works and secrets stay plain text, as in stock mIRC.
;
;  * The DLL is only used if its SHA-256 matches data\neonsec.sha256.
;  * DPAPI ties the data to your Windows account on this PC - copied to another machine the
;    tokens cannot be unlocked and you simply enter them again.
;  * Backups never contain secrets either way (see /neon export).
; ============================================================================

alias ns.sec.dll return $+($scriptdir,neonsec.dll)
alias ns.sec.items return pass srvpass bnctoken

; is the helper present, and is it the exact build we published?  (cached for the session)
alias ns.sec.ready {
  if (!$exists($ns.sec.dll)) return 0
  if ($hget(ns.secs,ok) != $null) return $hget(ns.secs,ok)
  var %want = $read($ns.data(neonsec.sha256),n,1), %have = $sha256($ns.sec.dll,2), %ok = 0
  if (%want != $null) && (%have == %want) %ok = 1
  hadd -m ns.secs ok %ok
  if (!%ok) ns.log sec neonsec.dll does not match data\neonsec.sha256 - not used
  return %ok
}
; protection is on when the user wants it AND the helper is usable
alias ns.sec.on return $iif($ns.flag(security,protect,1) && $ns.sec.ready,1,0)
alias ns.sec.isprot return $iif($left($1-,6) == dpapi:,1,0)

; plain text -> "dpapi:..." (or the text unchanged when protection is off / unavailable)
alias ns.sec.enc {
  var %t = $1-
  if (%t == $null) || ($left(%t,6) == dpapi:) || (!$ns.sec.on) return %t
  var %r = $dll($ns.sec.dll,Protect,%t)
  if ($left(%r,6) == dpapi:) return %r
  ns.log sec could not protect a value ( $+ %r $+ ) - kept as plain text
  return %t
}
; "dpapi:..." -> plain text ($null when it cannot be unlocked here)
alias ns.sec.dec {
  var %t = $1-
  if ($left(%t,6) != dpapi:) return %t
  if (!$ns.sec.ready) {
    ns.log sec a protected value cannot be read: neonsec.dll missing or changed
    return $null
  }
  var %r = $dll($ns.sec.dll,Unprotect,%t)
  if ($left(%r,6) == error:) {
    ns.log sec a protected value could not be unlocked ( $+ $mid(%r,7) $+ )
    return $null
  }
  return %r
}

; convert every stored secret:  ns.sec.convert protect | plain  ->  number of values changed
alias ns.sec.convert {
  var %to = $1, %i = 1, %sec, %k, %item, %raw, %new, %n = 0
  while ($ini($ns.profini,%i) != $null) {
    %sec = $ini($ns.profini,%i)
    inc %i
    %k = 1
    while ($gettok($ns.sec.items,%k,32) != $null) {
      %item = $gettok($ns.sec.items,%k,32)
      inc %k
      %raw = $readini($ns.profini,n,%sec,%item)
      if (%raw == $null) continue
      if (%to == protect) && ($left(%raw,6) != dpapi:) {
        %new = $ns.sec.enc(%raw)
        if ($left(%new,6) == dpapi:) { writeini -n $qt($ns.profini) %sec %item %new | inc %n }
      }
      elseif (%to == plain) && ($left(%raw,6) == dpapi:) {
        %new = $ns.sec.dec(%raw)
        if (%new != $null) { writeini -n $qt($ns.profini) %sec %item %new | inc %n }
      }
    }
  }
  flushini $ns.profini
  ; the AI helpers key lives in a file of its own (never in a backup)
  %raw = $readini($ns.ai.keyfile,n,ai,key)
  if (%raw != $null) {
    if (%to == protect) && ($left(%raw,6) != dpapi:) {
      %new = $ns.sec.enc(%raw)
      if ($left(%new,6) == dpapi:) {
        writeini -n $qt($ns.ai.keyfile) ai key %new
        inc %n
      }
    }
    elseif (%to == plain) && ($left(%raw,6) == dpapi:) {
      %new = $ns.sec.dec(%raw)
      if (%new != $null) {
        writeini -n $qt($ns.ai.keyfile) ai key %new
        inc %n
      }
    }
    flushini $ns.ai.keyfile
  }
  return %n
}
; how many stored secrets are protected / plain:  $ns.sec.count(protected|plain)
alias ns.sec.count {
  var %i = 1, %sec, %k, %item, %raw, %p = 0, %q = 0
  while ($ini($ns.profini,%i) != $null) {
    %sec = $ini($ns.profini,%i)
    inc %i
    %k = 1
    while ($gettok($ns.sec.items,%k,32) != $null) {
      %item = $gettok($ns.sec.items,%k,32)
      inc %k
      %raw = $readini($ns.profini,n,%sec,%item)
      if (%raw == $null) continue
      if ($left(%raw,6) == dpapi:) inc %p
      else inc %q
    }
  }
  %raw = $readini($ns.ai.keyfile,n,ai,key)
  if (%raw != $null) {
    if ($left(%raw,6) == dpapi:) inc %p
    else inc %q
  }
  return $iif($1 == protected,%p,%q)
}

; protect what is already stored the first time the helper is available
on *:SIGNAL:ns.boot:{
  if (!$ns.sec.on) return
  if (!$ns.flag(security,autoprotect,1)) return
  var %n = $ns.sec.convert(protect)
  if (%n) ns.say $+(%n,$chr(32),saved password/token,$iif(%n != 1,s)) now protected with Windows DPAPI (/neon secure for details).
}

; /neon secure [status|on|off]
alias neon.secure {
  var %c = $lower($1)
  if (%c == on) {
    if (!$ns.sec.ready) {
      ns.err the protection helper is not available - neonsec.dll is $iif($exists($ns.sec.dll),different from the published build,missing) $+ .
      return
    }
    ns.set security protect 1
    ns.say $ns.sec.convert(protect) value(s) protected. New passwords and tokens are protected as you save them.
    return
  }
  if (%c == off) {
    if (!$input(Store passwords and tokens as plain text again? $+ $crlf $+ (Anyone who can read profiles.ini will be able to read them.),yq,Turn protection off)) return
    var %n = $ns.sec.convert(plain)
    ns.set security protect 0
    ns.say protection is off - %n value(s) are plain text again.
    return
  }
  ns.say password / token protection: $iif($ns.sec.on,$+($ns.ec(join),ON,$ns.o),$+($ns.ec(kick),off,$ns.o))
  ns.say helper neonsec.dll: $iif(!$exists($ns.sec.dll),not installed (optional),$iif($ns.sec.ready,verified (SHA-256 matches),does NOT match the published hash - not used))
  ns.say stored: $ns.sec.count(protected) protected, $ns.sec.count(plain) plain text. Use $+($ns.cc(11),/neon secure on,$ns.o) or $+($ns.cc(11),/neon secure off,$ns.o) $+ .
}
