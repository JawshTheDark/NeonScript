; ============================================================================
;  NeonScript 2026  ::  splash screen + live dashboard
;  The dashboard is a picture window drawn with /draw* commands: connection
;  card (lag, uptime, TLS), you card (nick, away, modes), channel card (with
;  your rank in each channel: ~ & @ % +), activity sparkline, and clickable
;  quick buttons with hover highlights.
; ============================================================================

; ---------------------------------------------------------------- lag + statistics
; lag is measured with our own PING so it works on every server
alias ns.lag.ping {
  var %i = $scon(0)
  while (%i) {
    scid $scon(%i) if ($status == connected) raw -q PING $+(:nslag,$ticks)
    dec %i
  }
}
raw PONG:*nslag*:{
  var %t = $remove($gettok($1-,-1,32),:)
  if ($left(%t,5) != nslag) return
  hadd -m ns.lag $cid $calc($ticks - $mid(%t,6))
  halt
}
; $ns.lag -> "42 ms" or "-" for the active connection
alias ns.lag {
  var %v = $hget(ns.lag,$cid)
  if (%v == $null) return -
  return %v $+ $chr(32) $+ ms
}
alias ns.stat.inc {
  if ($isalias(ns.bnc.q)) && ($ns.bnc.q) return
  hinc -m ns.stat $1
  if ($2 == m) hinc -m ns.stat b0
}
alias ns.stat.tick {
  var %i = 29
  while (%i > 0) {
    hadd -m ns.stat $+(b,%i) $hget(ns.stat,$+(b,$calc(%i - 1)))
    dec %i
  }
  hadd -m ns.stat b0 0
}
on *:TEXT:*:*:{
  ns.stat.inc msg m
  if ($chan == $null) ns.stat.inc pm
  elseif ($me isin $1-) && (!$ns.hl.muted($fulladdress)) ns.stat.inc hl
}
on *:ACTION:*:*:{ ns.stat.inc msg m }
on *:INPUT:*:{
  if ($left($1,1) != /) ns.stat.inc msg m
}

alias ns.hud.init {
  .timer.nsstat 0 60 ns.stat.tick
  .timer.nslag 0 30 ns.lag.ping
  if ($ns.flag(general,splash,1)) .timer.nssplash -o 1 1 ns.splash.show
  if ($ns.flag(hud,autoopen,0)) .timer.nsdashopen -o 1 2 neon dash
}
on *:SIGNAL:ns.boot:{ ns.hud.init }
on *:SIGNAL:ns.uninstall:{ .timer.nsdash off | .timer.nslag off | .timer.nsstat off | if ($window(@NeonDash)) window -c @NeonDash }
on *:LOAD:{ .timer.nshudinit -o 1 1 ns.hud.init }

; ---------------------------------------------------------------- splash
alias neon.splash ns.splash.show
alias ns.splash.show {
  var %w = @NeonSplash
  if ($window(%w)) window -c %w
  window -pBdfCo +dL %w -1 -1 480 270
  setlayer 0 %w
  drawpic -n %w 0 0 $qt($ns.asset(splash.png))
  drawtext -rn %w $rgb(255,255,255) "Segoe UI" 11 18 236 Loading $ns.tag $+ ...
  drawrect %w
  set -u15 %ns.sp.a 0
  set -u15 %ns.sp.phase 0
  set -u15 %ns.sp.hold 0
  .timer.nsspl -m 0 30 ns.splash.tick
}
alias ns.splash.tick {
  var %w = @NeonSplash
  if (!$window(%w)) { .timer.nsspl off | return }
  if (%ns.sp.phase == 0) {
    set -u15 %ns.sp.a $calc(%ns.sp.a + 28)
    if (%ns.sp.a >= 255) {
      set -u15 %ns.sp.a 255
      set -u15 %ns.sp.phase 1
    }
  }
  elseif (%ns.sp.phase == 1) {
    set -u15 %ns.sp.hold $calc(%ns.sp.hold + 1)
    var %pct = $calc(%ns.sp.hold * 100 / 40)
    ; progress bar along the bottom
    drawrect -rfn %w $rgb(20,10,40) 1 18 258 444 6
    drawrect -rfn %w $ns.acc2 1 18 258 $calc(444 * %pct / 100) 6
    drawrect %w
    if (%ns.sp.hold >= 40) set -u15 %ns.sp.phase 2
  }
  else {
    set -u15 %ns.sp.a $calc(%ns.sp.a - 36)
    if (%ns.sp.a <= 0) {
      .timer.nsspl off
      window -c %w
      return
    }
  }
  setlayer %ns.sp.a %w
}
; click the splash to dismiss it
menu @NeonSplash {
  sclick:{ .timer.nsspl off | window -c @NeonSplash }
}

; ---------------------------------------------------------------- dashboard
alias neon.dash {
  if ($window(@NeonDash)) { window -c @NeonDash | .timer.nsdash off | return }
  ns.dash.open
}
alias ns.dash.open {
  window -pBf @NeonDash 14 14 760 236
  titlebar @NeonDash NeonScript Dashboard
  ns.dash.draw
  .timer.nsdash 0 2 ns.dash.draw
}
on *:SIGNAL:ns.theme:{ if ($window(@NeonDash)) ns.dash.draw }
on *:SIGNAL:ns.sync:{ if ($window(@NeonDash)) ns.dash.draw }
on *:CLOSE:@NeonDash:{ .timer.nsdash off }

alias -l btns return connect away dnd sound theme options help
alias -l bx return $calc(14 + ($1 - 1) * 106)
alias -l by return 176
alias -l bw return 100
alias -l bh return 46
alias -l blabel {
  var %b = $1
  if (%b == connect) return $iif($status == connected,Disconnect,Connect)
  if (%b == away) return $iif($away,Back,Away)
  if (%b == dnd) return $iif($donotdisturb,DND on,DND)
  if (%b == sound) return $iif($ns.flag(sound,enabled,1),Sound,Muted)
  if (%b == theme) return Themes
  if (%b == options) return Options
  return Help
}
alias -l bicon {
  var %b = $1
  if (%b == connect) return $iif($status == connected,disconnect,connect) $+ .png
  if (%b == away) return away.png
  if (%b == dnd) return $iif($donotdisturb,dnd_on,dnd_off) $+ .png
  if (%b == sound) return $iif($ns.flag(sound,enabled,1),sound_on,sound_off) $+ .png
  return %b $+ .png
}
; filled rounded card with a thin border
alias -l card {
  drawrect -rfdn @NeonDash $1 1 $3 $4 $5 $6 12 12
  drawrect -rdn @NeonDash $2 1 $3 $4 $5 $6 12 12
}
alias -l txt {
  ; txt <color> <size> <x> <y> <text...>   (bold: prefix text with ^B handled by -o via $ns.hud.bold)
  drawtext -rn @NeonDash $1 "Segoe UI" $2 $3 $4 $5-
}
alias -l btxt drawtext -rno @NeonDash $1 "Segoe UI" $2 $3 $4 $5-

alias ns.dash.draw {
  var %w = @NeonDash
  if (!$window(%w)) { .timer.nsdash off | return }
  var %bg = $ns.pal($color(background)), %fg = $ns.pal($color(normal)), %dim = $ns.pal($color(gray))
  var %a1 = $ns.acc1, %a2 = $ns.acc2
  var %card = $ns.mix(%bg,%fg,0.07), %edge = $ns.mix(%bg,%fg,0.18), %mut = $ns.mix(%bg,%fg,0.55)
  var %good = $rgb(70,220,140), %bad = $rgb(255,90,110), %warn = $rgb(255,200,80)
  drawrect -rfn %w %bg 1 0 0 760 236
  ; accent gradient strip
  var %i = 0
  while (%i < 38) {
    drawrect -rfn %w $ns.mix(%a1,%a2,$calc(%i / 37)) 1 $calc(%i * 20) 0 20 3
    inc %i
  }
  btxt %fg 14 16 10 NeonScript
  txt %mut 9 124 15 $ns.ver $+ $chr(32) $+ $chr(183) $+ $chr(32) $+ $ns.theme.ename($ns.theme.current)
  txt %mut 10 650 12 $time(HH:nn) $+ $chr(32) $+ $chr(183) $+ $chr(32) $+ $date

  ; ---- card 1: connection ------------------------------------------------
  var %y = 40, %h = 126
  card %card %edge 14 %y 178 %h
  txt %mut 8 28 $calc(%y + 8) CONNECTION
  var %on = $iif($status == connected,1,0)
  drawrect -rfen %w $iif(%on,%good,%bad) 1 28 $calc(%y + 30) 9 9
  btxt %fg 11 44 $calc(%y + 26) $iif($network,$network,$iif(%on,$server,Not connected))
  txt %mut 9 28 $calc(%y + 48) $iif(%on,$server,$iif($servertarget,$servertarget,no server))
  txt %fg 9 28 $calc(%y + 66) Lag: $ns.lag
  txt %fg 9 28 $calc(%y + 82) Uptime: $iif(%on,$uptime(server,1),-)
  var %bp = $ns.bnc.cur
  txt $iif($ssl,%good,%mut) 9 28 $calc(%y + 98) $iif($ssl,Encrypted (TLS),$iif(%on,Not encrypted,$chr(160)))
  if (%bp) txt %a2 9 28 $calc(%y + 112) via $ns.bnc.tname($ns.bnc.type(%bp)) bouncer

  ; ---- card 2: you -------------------------------------------------------
  var %x = 200
  card %card %edge %x %y 178 %h
  txt %mut 8 $calc(%x + 14) $calc(%y + 8) YOU
  btxt %fg 12 $calc(%x + 14) $calc(%y + 26) $me
  txt $iif($away,%warn,%good) 9 $calc(%x + 14) $calc(%y + 50) $iif($away,Away: $awaymsg,Available)
  txt %fg 9 $calc(%x + 14) $calc(%y + 68) Modes: $iif($usermode,$usermode,-)
  txt %fg 9 $calc(%x + 14) $calc(%y + 84) Idle: $duration($idle)
  txt %mut 9 $calc(%x + 14) $calc(%y + 100) mIRC $version

  ; ---- card 3: channels with my rank -------------------------------------
  %x = 386
  card %card %edge %x %y 178 %h
  txt %mut 8 $calc(%x + 14) $calc(%y + 8) CHANNELS ( $+ $chan(0) $+ )
  var %n = $chan(0), %k = 1, %cy = $calc(%y + 26), %rk, %col
  if (!%n) txt %mut 9 $calc(%x + 14) %cy not on any channel
  while (%k <= %n) && (%k <= 5) {
    var %c = $chan(%k)
    %rk = $ns.rk.of(%c,$me)
    %col = $ns.pal($ns.ecn($iif(%rk,$ns.rk.letter(%rk),dim)))
    if (%rk) btxt %col 10 $calc(%x + 14) %cy %rk
    txt %fg 9 $calc(%x + 28) %cy $left(%c,14)
    txt %mut 9 $calc(%x + 128) %cy $nick(%c,0)
    inc %cy 17
    inc %k
  }

  ; ---- card 4: activity --------------------------------------------------
  %x = 572
  card %card %edge %x %y 174 %h
  txt %mut 8 $calc(%x + 14) $calc(%y + 8) ACTIVITY (30 min)
  var %max = 1, %b = 0
  while (%b < 30) {
    if ($hget(ns.stat,$+(b,%b)) > %max) %max = $v1
    inc %b
  }
  %b = 29
  var %bx = $calc(%x + 14)
  while (%b >= 0) {
    var %val = $hget(ns.stat,$+(b,%b)), %bh = $int($calc(%val / %max * 46))
    if (%bh < 2) %bh = 2
    drawrect -rfn %w $ns.mix(%a1,%a2,$calc(%bh / 46)) 1 %bx $calc(%y + 80 - %bh) 4 %bh
    inc %bx 5
    dec %b
  }
  txt %fg 9 $calc(%x + 14) $calc(%y + 88) Messages: $calc($hget(ns.stat,msg) + 0)
  txt %fg 9 $calc(%x + 14) $calc(%y + 104) Mentions: $calc($hget(ns.stat,hl) + 0) $+ $chr(32) $+ $chr(183) $+ $chr(32) $+ PMs: $calc($hget(ns.stat,pm) + 0)

  ; ---- quick buttons -----------------------------------------------------
  var %j = 1
  while ($gettok($btns,%j,32)) {
    var %bn = $v1, %xx = $bx(%j), %yy = $by, %hot = $iif(%ns.dash.hot == %j,1,0)
    drawrect -rfdn %w $iif(%hot,$ns.mix(%card,%a1,0.35),%card) 1 %xx %yy $bw $bh 10 10
    drawrect -rdn %w $iif(%hot,%a1,%edge) 1 %xx %yy $bw $bh 10 10
    drawpic -scn %w %xx $calc(%yy + 7) 32 32 $qt($ns.asset($bicon(%bn)))
    btxt %fg 10 $calc(%xx + 42) $calc(%yy + 14) $blabel(%bn)
    inc %j
  }
  drawrect %w
}

; which quick button is under the mouse? (0 = none)
alias -l hit {
  var %j = 1
  while (%j <= 7) {
    if ($inrect($mouse.x,$mouse.y,$bx(%j),$by,$bw,$bh)) return %j
    inc %j
  }
  return 0
}
menu @NeonDash {
  mouse:{
    var %h = $hit
    if (%h != %ns.dash.hot) {
      set -u300 %ns.dash.hot %h
      ns.dash.draw
    }
  }
  leave:{
    if (%ns.dash.hot) {
      set -u300 %ns.dash.hot 0
      ns.dash.draw
    }
  }
  sclick:{
    var %h = $hit
    if (%h) ns.dash.click $gettok($btns,%h,32)
  }
  $iif($window(@NeonDash),Refresh):ns.dash.draw
  Close dashboard:window -c @NeonDash
}
alias ns.dash.click {
  var %b = $1
  if (%b == connect) ns.tb.connect
  elseif (%b == away) {
    if ($away) neon back
    else neon away
  }
  elseif (%b == dnd) neon dnd
  elseif (%b == sound) neon mute
  elseif (%b == theme) neon themes
  elseif (%b == options) neon options
  elseif (%b == help) neonhelp
  .timer.nsdashr -o 1 1 ns.dash.draw
}
