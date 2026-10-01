; ============================================================================
;  NeonScript 2026  ::  channel stats
;  Counts lines, words and actions per person and messages per hour of the day, per channel, as they
;  happen (live lines only - a bouncer's replayed history is not counted).  /neon stats [#channel]
;  Everything stays on this PC in data\stats.dat; switch it off in Control Panel > Privacy.
;
;  ns.cs hash:   <net>|<#chan>|u|<nick>  -> lines words actions chars lastseen Nick
;                <net>|<#chan>|h|HH      -> lines in that hour (00..23)
;                <net>|<#chan>|t         -> total lines      |s -> first counted     |n -> people counted
; ============================================================================

alias ns.cs.file return $ns.data(stats.dat)
alias ns.cs.sec return $+($ns.mod.net,|,$lower($1))

on *:TEXT:*:#:{ ns.cs.count $chan $nick l $1- }
on *:ACTION:*:#:{ ns.cs.count $chan $nick a $1- }
; ns.cs.count <chan> <nick> <l|a> <text...>
alias ns.cs.count {
  if (!$ns.flag(stats,on,1)) return
  if ($ns.bnc.q) return
  if ($2 == $me) && (!$ns.flag(stats,mine,1)) return
  var %s = $ns.cs.sec($1), %k = $+(%s,|u|,$lower($2)), %v = $hget(ns.cs,%k), %w = $numtok($strip($4-),32), %c = $len($4-)
  if (%v == $null) {
    hinc -m ns.cs $+(%s,|n)
    %v = 0 0 0 0 0 $2
  }
  hadd -m ns.cs %k $+($calc($gettok(%v,1,32) + 1),$chr(32),$calc($gettok(%v,2,32) + %w),$chr(32),$calc($gettok(%v,3,32) + $iif($3 == a,1,0)),$chr(32),$calc($gettok(%v,4,32) + %c),$chr(32),$ctime,$chr(32),$2)
  hinc -m ns.cs $+(%s,|h|,$asctime($ctime,HH))
  hinc -m ns.cs $+(%s,|t)
  if (!$hget(ns.cs,$+(%s,|s))) hadd -m ns.cs $+(%s,|s) $ctime
  set -u600 %ns.cs.dirty 1
}

; ---------------------------------------------------------------- save / load / tidy
on *:SIGNAL:ns.boot:{
  if ($exists($ns.cs.file)) && (!$hget(ns.cs)) hload -m ns.cs $qt($ns.cs.file)
  .timer.nscsv 0 300 ns.cs.save
}
on *:SIGNAL:ns.exit:{ ns.cs.save }
alias ns.cs.save {
  if (!$hget(ns.cs)) return
  ns.cs.prune
  hsave -o ns.cs $qt($ns.cs.file)
}
; a channel that has more than 800 people counted loses the ones with 1-2 lines who have not spoken for a month
alias ns.cs.prune {
  var %i = 1, %n = $hget(ns.cs,0).item, %k, %v, %del, %sec
  while (%i <= %n) {
    %k = $hget(ns.cs,%i).item
    inc %i
    if ($gettok(%k,3,124) != u) continue
    %sec = $+($gettok(%k,1,124),|,$gettok(%k,2,124))
    if ($hget(ns.cs,$+(%sec,|n)) <= 800) continue
    %v = $hget(ns.cs,%k)
    if ($gettok(%v,1,32) <= 2) && ($calc($ctime - $gettok(%v,5,32)) > 2592000) %del = %del %k
  }
  %i = 1
  while ($gettok(%del,%i,32) != $null) {
    %k = $v1
    hdel ns.cs %k
    hdec ns.cs $+($gettok(%k,1,124),|,$gettok(%k,2,124),|n)
    inc %i
  }
}
; forget one channel's numbers
alias ns.cs.reset {
  var %s = $1, %i = 1, %n = $hget(ns.cs,0).item, %k, %del
  while (%i <= %n) {
    %k = $hget(ns.cs,%i).item
    inc %i
    if ($left(%k,$calc($len(%s) + 1)) == $+(%s,|)) %del = %del %k
  }
  %i = 1
  while ($gettok(%del,%i,32) != $null) {
    hdel ns.cs $v1
    inc %i
  }
}

; ---------------------------------------------------------------- reading the numbers
; every channel that has numbers, as "net|#chan" tokens
alias ns.cs.secs {
  var %i = 1, %n = $hget(ns.cs,0).item, %k, %o
  while (%i <= %n) {
    %k = $hget(ns.cs,%i).item
    inc %i
    if ($gettok(%k,3,124) == t) %o = %o $+($gettok(%k,1,124),|,$gettok(%k,2,124))
  }
  return $ns.trim(%o)
}
; the top N talkers of a channel: "nick:lines nick:lines ..." (nicks never contain spaces or colons)
alias ns.cs.top {
  var %s = $1, %max = $2, %i = 1, %n = $hget(ns.cs,0).item, %k, %v, %pre = $+(%s,|u|), %list, %o, %best, %bl, %j, %pick, %cnt
  while (%i <= %n) {
    %k = $hget(ns.cs,%i).item
    inc %i
    if ($left(%k,$len(%pre)) != %pre) continue
    %v = $hget(ns.cs,%k)
    %list = %list $+($gettok(%v,6,32),:,$gettok(%v,1,32))
  }
  %cnt = 0
  while (%cnt < %max) && ($gettok(%list,1,32) != $null) {
    %best = $gettok(%list,1,32)
    %bl = $gettok(%best,2,58)
    %j = 2
    while ($gettok(%list,%j,32) != $null) {
      %pick = $gettok(%list,%j,32)
      if ($gettok(%pick,2,58) > %bl) {
        %best = %pick
        %bl = $gettok(%best,2,58)
      }
      inc %j
    }
    %o = %o %best
    %list = $remtok(%list,%best,1,32)
    inc %cnt
  }
  return $ns.trim(%o)
}
; "21:00" - the busiest hour, "" when there is nothing
alias ns.cs.busiest {
  var %h = 0, %best = -1, %bh, %v
  while (%h < 24) {
    %v = $hget(ns.cs,$+($1,|h|,$base(%h,10,10,2)))
    if (%v > %best) {
      %best = %v
      %bh = $base(%h,10,10,2)
    }
    inc %h
  }
  if (%best < 1) return $null
  return %bh $+ :00
}

; ---------------------------------------------------------------- the dialog
alias neon.stats {
  set -u60 %ns.cs.pick $iif($ns.ischan($1),$ns.cs.sec($1),$iif($ns.ischan($active),$ns.cs.sec($active)))
  ns.dlg ns_stats ns_stats
}
dialog ns_stats {
  title "Channel Stats"
  size -1 -1 330 254
  option dbu
  icon 1, 0 0 330 30, $mircexe, 0, noborder
  text "Channel:", 2, 6 38 30 9
  combo 3, 38 36 170 90, drop
  button "Refresh", 4, 214 35 40 12
  text "", 5, 6 52 318 9
  list 6, 6 64 318 78, size vsbar
  text "Messages by hour of the day (your PC's clock)", 7, 6 146 318 9
  icon 8, 6 156 318 64, $mircexe, 0, noborder
  text "", 9, 6 224 318 9
  button "Say the top 5", 10, 6 236 60 13
  button "Reset this channel...", 11, 70 236 74 13
  button "Close", 12, 276 236 48 13, ok cancel
}
alias -l cssec return $gettok($ns.cs.secs,$did(ns_stats,3).sel,32)
on *:DIALOG:ns_stats:init:*:{
  did -g ns_stats 1 $ns.asset(header_stats.png)
  var %i = 1, %s, %sel = 1
  while ($gettok($ns.cs.secs,%i,32) != $null) {
    %s = $v1
    did -a ns_stats 3 $+($gettok(%s,2,124),$chr(32),$chr(40),$gettok(%s,1,124),$chr(41))
    if (%s == %ns.cs.pick) %sel = %i
    inc %i
  }
  if (%i > 1) did -c ns_stats 3 %sel
  csfill
}
on *:DIALOG:ns_stats:sclick:3,4:{ csfill }
alias -l csfill {
  var %s = $cssec, %tot, %top, %i = 1, %n, %p, %nick, %lines, %v, %pct, %since
  did -r ns_stats 6
  if (!%s) {
    did -ra ns_stats 5 Nothing counted yet - chat in a channel and come back. (Counting is on in Control Panel > Privacy.)
    did -ra ns_stats 9 $chr(160)
    csdraw $null
    return
  }
  %tot = $hget(ns.cs,$+(%s,|t))
  %since = $hget(ns.cs,$+(%s,|s))
  did -ra ns_stats 5 %tot lines from $hget(ns.cs,$+(%s,|n)) people since $asctime(%since,d mmm yyyy) $+ $iif($ns.cs.busiest(%s) != $null,$chr(44) busiest hour $ns.cs.busiest(%s))
  %top = $ns.cs.top(%s,25)
  %n = $numtok(%top,32)
  while (%i <= %n) {
    %p = $gettok(%top,%i,32)
    %nick = $gettok(%p,1,58)
    %lines = $gettok(%p,2,58)
    %v = $hget(ns.cs,$+(%s,|u|,$lower(%nick)))
    %pct = $round($calc(%lines * 100 / %tot),1)
    did -a ns_stats 6 $+(%i,.,$chr(32),$chr(32),%nick,$chr(32),$chr(32),$chr(8212),$chr(32),$chr(32),%lines,$chr(32),lines,$chr(32),$chr(40),%pct,$chr(37),$chr(41),$chr(44),$chr(32),$iif($gettok(%v,1,32) > 0,$round($calc($gettok(%v,2,32) / $gettok(%v,1,32)),1),0),$chr(32),words per line,$iif($gettok(%v,3,32) > 0,$chr(44) $gettok(%v,3,32) actions))
    inc %i
  }
  did -ra ns_stats 9 $chr(160)
  csdraw %s
}
; the 24-bar histogram, drawn into a hidden picture window and shown through the dialog's picture control
alias -l csdraw {
  var %s = $1, %w = 620, %h = 124, %h24 = 0, %max = 1, %v, %bw = $calc(%w / 24), %bh, %x, %col, %f = $ns.data(tmp\stats_hours.bmp), %hh
  .mkdir $qt($ns.data(tmp))
  if ($window(@nscsdraw)) window -c @nscsdraw
  window -hp @nscsdraw 0 0 $calc(%w + 16) $calc(%h + 39)
  if ($window(@nscsdraw).dw > 100) %w = $window(@nscsdraw).dw
  if ($window(@nscsdraw).dh > 60) %h = $window(@nscsdraw).dh
  %bw = $calc(%w / 24)
  drawrect -rf @nscsdraw $rgb(17,18,30) 1 0 0 %w %h
  if (%s) {
    while (%h24 < 24) {
      %v = $hget(ns.cs,$+(%s,|h|,$base(%h24,10,10,2)))
      if (%v > %max) %max = %v
      inc %h24
    }
    %h24 = 0
    while (%h24 < 24) {
      %v = $hget(ns.cs,$+(%s,|h|,$base(%h24,10,10,2)))
      %bh = $round($calc((%h - 36) * %v / %max),0)
      %x = $calc(%h24 * %bw + 4)
      %col = $iif(%v == %max,$rgb(255,46,136),$rgb(46,230,255))
      if (%bh > 0) drawrect -rf @nscsdraw %col 1 %x $calc(%h - 20 - %bh) $calc(%bw - 8) %bh
      drawrect -rf @nscsdraw $rgb(60,62,90) 1 %x $calc(%h - 20) $calc(%bw - 8) 2
      if ($calc(%h24 % 3) == 0) drawtext -r @nscsdraw $rgb(190,194,220) Tahoma 9 %x $calc(%h - 17) $base(%h24,10,10,2)
      inc %h24
    }
  }
  drawsave @nscsdraw %f
  window -c @nscsdraw
  did -g ns_stats 8 %f
}
on *:DIALOG:ns_stats:sclick:10:{
  var %s = $cssec, %c = $gettok(%s,2,124), %top = $ns.cs.top(%s,5), %i = 1, %o, %p
  if (!$ns.ischan(%c)) || ($gettok(%s,1,124) != $ns.mod.net) {
    did -ra ns_stats 9 Open that channel on this network first, then try again.
    return
  }
  while ($gettok(%top,%i,32) != $null) {
    %p = $v1
    %o = %o $+($gettok(%p,1,58),$chr(32),$chr(40),$gettok(%p,2,58),$chr(41)) $+ $iif(%i < $numtok(%top,32),$chr(44))
    inc %i
  }
  msg %c Top talkers: %o
  did -ra ns_stats 9 Sent to %c $+ .
}
on *:DIALOG:ns_stats:sclick:11:{ ns.later ns.cs.resetask }
alias ns.cs.resetask {
  if (!$dialog(ns_stats)) return
  var %s = $cssec
  if (!%s) return
  if (!$input(Forget all the numbers counted for $gettok(%s,2,124) $+ $chr(63),yq,Reset channel stats)) return
  ns.cs.reset %s
  csfillnow
}
alias -l csfillnow {
  did -r ns_stats 3
  var %i = 1
  while ($gettok($ns.cs.secs,%i,32) != $null) {
    did -a ns_stats 3 $+($gettok($v1,2,124),$chr(32),$chr(40),$gettok($v1,1,124),$chr(41))
    inc %i
  }
  if (%i > 1) did -c ns_stats 3 1
  csfill
}
