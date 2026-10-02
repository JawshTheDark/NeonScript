; ============================================================================
;  NeonScript 2026  ::  log viewer          /neon logs   (or /logs, the toolbar's Logs button)
;  mIRC writes one log per window into its log folder:  <window>.<network>.log   (#chan.Libera.Chat.log, nick.Rizon.log,
;  status.irc.so.log ...).  The viewer sorts them into categories you can browse:
;      by type     channels, private messages, status windows, other (DCC chats, custom windows)
;      by network  every network that has logs, with counts
;      by age      today, last 7 days, older
;  and shows one in a window of its own (colours and all), searches the text of one log or of every listed log, and jumps to a
;  hit in context.  Nothing is changed or moved: your log files stay exactly where mIRC wrote them.
;      /neon logs                  open the viewer
;      /neon logs here             open the viewer on the log of the window you are in
;      /neon logs search <text>    search every log for text (wildcards * ? allowed) and show the hits
; ============================================================================

; ---------------------------------------------------------------- finding and classifying the files
; every log file (the folder itself and up to two levels below it)
alias ns.lg.count return $findfile($logdir,*.log,0,2)
alias ns.lg.file return $findfile($logdir,*.log,$1,2)
; networks that have a log of their own ("status.<network>.log") plus the ones connected right now, "|" separated
alias ns.lg.nets {
  var %n = $ns.lg.count, %i = 1, %b, %o = $chr(124), %k
  while (%i <= %n) {
    %b = $nopath($ns.lg.file(%i))
    inc %i
    if ($left(%b,7) == status.) && ($right(%b,4) == .log) {
      %k = $mid($left(%b,-4),8)
      if (%k != $null) && (!$istok(%o,%k,124)) %o = $+(%o,%k,$chr(124))
    }
  }
  %i = 1
  while (%i <= $scon(0)) {
    %k = $scon(%i).network
    inc %i
    if (%k != $null) && (!$istok(%o,%k,124)) %o = $+(%o,%k,$chr(124))
  }
  return %o
}
; record of one file:  path TAB kind TAB target TAB network TAB size TAB mtime      kind: channel query status other
alias ns.lg.classify {
  var %f = $1, %nets = $2, %b = $left($nopath(%f),-4), %net, %t, %kind, %i = 1, %k, %best = 0, %c, %ct = $+($chr(35),&!+)
  if ($left(%b,7) == status.) {
    %t = status
    %net = $mid(%b,8)
    %kind = status
  }
  else {
    while ($gettok(%nets,%i,124) != $null) {
      %k = $gettok(%nets,%i,124)
      inc %i
      if ($len(%k) > %best) && ($right(%b,$calc($len(%k) + 1)) == $+(.,%k)) {
        %net = %k
        %best = $len(%k)
      }
    }
    if (%net != $null) %t = $left(%b,$calc($len(%b) - $len(%net) - 1))
    elseif ($pos(%b,.)) {
      %t = $left(%b,$calc($pos(%b,.) - 1))
      %net = $mid(%b,$calc($pos(%b,.) + 1))
    }
    else %t = %b
    %c = $left(%t,1)
    if (%c != $null) && ($pos(%ct,%c)) %kind = channel
    elseif (%c == $null) || (%c == =) || (%c == @) %kind = other
    else %kind = query
  }
  if (%net == $null) %net = (no network)
  return $+(%f,$chr(9),%kind,$chr(9),%t,$chr(9),%net,$chr(9),$file(%f).size,$chr(9),$file(%f).mtime)
}
; read every log's name, size and date into hash table ns.lg  (1..n)
alias ns.lg.scan {
  var %n = $ns.lg.count, %i = 1, %nets = $ns.lg.nets
  if ($hget(ns.lg)) hfree ns.lg
  hmake ns.lg 100
  while (%i <= %n) {
    hadd ns.lg %i $ns.lg.classify($ns.lg.file(%i),%nets)
    inc %i
  }
  hadd ns.lg n %n
  return %n
}
alias ns.lg.rec return $hget(ns.lg,$1)
alias ns.lg.path return $gettok($ns.lg.rec($1),1,9)
alias ns.lg.kind return $gettok($ns.lg.rec($1),2,9)
alias ns.lg.target return $gettok($ns.lg.rec($1),3,9)
alias ns.lg.net return $gettok($ns.lg.rec($1),4,9)
alias ns.lg.netkey return $replace($ns.lg.net($1),$chr(32),$chr(160))
alias ns.lg.size return $gettok($ns.lg.rec($1),5,9)
alias ns.lg.mtime return $gettok($ns.lg.rec($1),6,9)
; 1234 -> "1.2 KB"
alias ns.lg.sz {
  var %n = $1
  if (%n < 1024) return %n B
  if (%n < 1048576) return $round($calc(%n / 1024),1) KB
  return $round($calc(%n / 1048576),1) MB
}
alias ns.lg.when {
  var %t = $1, %d = $calc($ctime - %t)
  if ($asctime(%t,yyyymmdd) == $asctime($ctime,yyyymmdd)) return today $asctime(%t,HH:nn)
  if (%d < 604800) return $asctime(%t,ddd HH:nn)
  return $asctime(%t,d mmm yyyy)
}
alias ns.lg.age {
  var %t = $ns.lg.mtime($1), %d = $calc($ctime - %t)
  if ($asctime(%t,yyyymmdd) == $asctime($ctime,yyyymmdd)) return today
  if (%d < 604800) return week
  return older
}
; does log $1 belong to category spec $2?   all | kind:<k> | net:<n> | age:<a>
alias ns.lg.in {
  var %s = $2, %a
  if (%s == all) return 1
  if ($left(%s,5) == kind:) return $iif($ns.lg.kind($1) == $mid(%s,6),1,0)
  if ($left(%s,4) == net:) return $iif($ns.lg.netkey($1) == $mid(%s,5),1,0)
  if ($left(%s,4) == age:) {
    %a = $ns.lg.age($1)
    if ($mid(%s,5) == week) return $iif(%a == today || %a == week,1,0)
    return $iif($mid(%s,5) == %a,1,0)
  }
  return 1
}

; ---------------------------------------------------------------- the dialog
alias neon.logs {
  var %c = $lower($1), %w, %f
  if (%c == search) { ns.lg.searchall $2- | return }
  if (%c == here) {
    %w = $active
    %f = $window(%w).logfile
    if (%f == $null) || (!$exists(%f)) { ns.err no log for $iif(%w,%w,this window) yet (is logging switched on for it?) | return }
    set -u60 %ns.lg.want $longfn(%f)
  }
  ns.dlg ns_logs ns_logs
}
alias logs neon.logs $1-
dialog ns_logs {
  title "Log viewer"
  size -1 -1 400 232
  option dbu
  icon 1, 0 0 400 30, $mircexe, 0, noborder
  text "Categories", 2, 6 34 60 9
  list 3, 6 44 100 132, size vsbar
  text "Logs:", 4, 112 34 22 9
  edit "", 5, 134 32 116 11, autohs
  text "Sort:", 6, 256 34 20 9
  combo 7, 278 32 64 50, drop
  list 8, 112 44 282 132, size vsbar hsbar
  text "", 9, 6 180 388 9
  button "Open", 10, 6 192 44 12, default
  text "Show:", 11, 56 194 22 9
  combo 12, 78 192 66 60, drop
  button "Folder", 13, 150 192 40 12
  button "Delete", 14, 194 192 40 12
  button "Rescan", 20, 238 192 40 12
  button "Close", 19, 346 192 48 12, ok cancel
  edit "", 15, 6 212 150 11, autohs
  check "Regex", 16, 160 213 34 9
  button "Find in this log", 17, 198 211 58 12
  button "Find in all listed logs", 18, 260 211 72 12
}
on *:DIALOG:ns_logs:init:*:{
  did -g ns_logs 1 $ns.asset(header_logs.png)
  did -a ns_logs 7 Name
  did -a ns_logs 7 Most recent
  did -a ns_logs 7 Largest
  did -c ns_logs 7 $iif($ns.get(logs,sort,2) isnum 1-3,$ns.get(logs,sort,2),2)
  did -a ns_logs 12 Last 500 lines
  did -a ns_logs 12 Last 2000 lines
  did -a ns_logs 12 Last 10000 lines
  did -a ns_logs 12 Everything
  did -c ns_logs 12 $iif($ns.get(logs,show,2) isnum 1-4,$ns.get(logs,show,2),2)
  ns.lg.rescan
  if (%ns.lg.want != $null) ns.lg.pickfile %ns.lg.want
}
; (re)read the folder and rebuild both lists
alias ns.lg.rescan {
  if (!$dialog(ns_logs)) return
  var %n = $ns.lg.scan
  ns.lg.fillcats
  ns.lg.fill
}
; the category list.  Header rows have spec "-" and cannot be chosen.  ns.lgc: row -> spec
alias ns.lg.cat {
  var %r = $calc($hget(ns.lgc,0).item + 1)
  hadd -m ns.lgc %r $1
  did -a ns_logs 3 $2-
}
alias ns.lg.fillcats {
  var %n = $hget(ns.lg,n), %i = 1, %k, %nets, %keep = $hget(ns.lgc,$did(ns_logs,3).sel), %row, %sel = 1, %c, %j, %a
  var %ch = 0, %q = 0, %st = 0, %ot = 0, %td = 0, %wk = 0, %old = 0, %sp = $+($chr(32),$chr(32))
  if ($hget(ns.lgc)) hfree ns.lgc
  hmake ns.lgc 20
  did -r ns_logs 3
  while (%i <= %n) {
    %k = $ns.lg.kind(%i)
    if (%k == channel) inc %ch
    elseif (%k == query) inc %q
    elseif (%k == status) inc %st
    else inc %ot
    %a = $ns.lg.age(%i)
    if (%a == today) { inc %td | inc %wk }
    elseif (%a == week) inc %wk
    else inc %old
    %k = $ns.lg.net(%i)
    if (%k != $null) && (!$istok(%nets,%k,124)) %nets = $+(%nets,$iif(%nets != $null,$chr(124)),%k)
    inc %i
  }
  ns.lg.cat all All logs ( $+ %n $+ )
  ns.lg.cat - By type
  if (%ch) ns.lg.cat kind:channel %sp $+ Channels ( $+ %ch $+ )
  if (%q) ns.lg.cat kind:query %sp $+ Private messages ( $+ %q $+ )
  if (%st) ns.lg.cat kind:status %sp $+ Status windows ( $+ %st $+ )
  if (%ot) ns.lg.cat kind:other %sp $+ Other ( $+ %ot $+ )
  ns.lg.cat - By network
  %nets = $sorttok(%nets,124,a)
  %i = 1
  while ($gettok(%nets,%i,124) != $null) {
    %k = $gettok(%nets,%i,124)
    inc %i
    %c = 0
    %j = 1
    while (%j <= %n) {
      if ($ns.lg.net(%j) == %k) inc %c
      inc %j
    }
    ns.lg.cat $+(net:,$replace(%k,$chr(32),$chr(160))) %sp $+ %k ( $+ %c $+ )
  }
  ns.lg.cat - By age
  if (%td) ns.lg.cat age:today %sp $+ Today ( $+ %td $+ )
  if (%wk) ns.lg.cat age:week %sp $+ Last 7 days ( $+ %wk $+ )
  if (%old) ns.lg.cat age:older %sp $+ Older ( $+ %old $+ )
  ; keep the chosen category when it still exists
  %i = 1
  %row = $hget(ns.lgc,0).item
  while (%i <= %row) {
    if ($hget(ns.lgc,%i) == %keep) && (%keep != -) && (%keep != $null) %sel = %i
    inc %i
  }
  did -c ns_logs 3 %sel
}
; the log list: category + name filter + sort
alias ns.lg.fill {
  if (!$dialog(ns_logs)) return
  var %spec = $hget(ns.lgc,$did(ns_logs,3).sel), %flt = $did(ns_logs,5).text, %srt = $did(ns_logs,7).sel, %n = $hget(ns.lg,n), %i = 1, %list, %bytes = 0, %key, %row = 0, %idx, %prev
  %prev = $hget(ns.lgr,$did(ns_logs,8).sel)
  if (%spec == -) || (%spec == $null) %spec = all
  if ($hget(ns.lgr)) hfree ns.lgr
  hmake ns.lgr 50
  did -r ns_logs 8
  while (%i <= %n) {
    if ($ns.lg.in(%i,%spec)) && ((%flt == $null) || (%flt isin $+($ns.lg.target(%i),$chr(32),$ns.lg.net(%i)))) {
      if (%srt == 2) %key = $base($ns.lg.mtime(%i),10,10,12)
      elseif (%srt == 3) %key = $base($ns.lg.size(%i),10,10,12)
      else %key = $+($lower($ns.lg.target(%i)),$chr(30),$lower($ns.lg.net(%i)))
      %list = $+(%list,$iif(%list != $null,$chr(31)),%key,$chr(29),%i)
      inc %bytes $ns.lg.size(%i)
    }
    inc %i
  }
  ; name: A to Z;  most recent / largest: biggest number first
  %list = $sorttok(%list,31,$iif(%srt == 1,a,ar))
  %i = 1
  while ($gettok(%list,%i,31) != $null) {
    %idx = $gettok($gettok(%list,%i,31),2,29)
    inc %i
    inc %row
    hadd ns.lgr %row %idx
    did -a ns_logs 8 $ns.lg.rowtext(%idx)
    if (%prev == %idx) did -c ns_logs 8 %row
  }
  did -ra ns_logs 9 $+(%row,$chr(32),log,$iif(%row != 1,s),$chr(32),shown,$chr(44),$chr(32),$ns.lg.sz(%bytes),$chr(32),of,$chr(32),%n,$chr(32),logs)
  if (%row) && (!$did(ns_logs,8).sel) did -c ns_logs 8 1
}
alias ns.lg.rowtext {
  var %i = $1
  return $+($ns.lg.target(%i),$chr(32),$chr(32),$chr(183),$chr(32),$ns.lg.net(%i),$chr(32),$chr(32),$chr(183),$chr(32),$ns.lg.sz($ns.lg.size(%i)),$chr(32),$chr(32),$chr(183),$chr(32),$ns.lg.when($ns.lg.mtime(%i)))
}
; select a log by its full path (used by /neon logs here)
alias ns.lg.pickfile {
  var %want = $1-, %i = 1, %n
  did -c ns_logs 3 1
  did -r ns_logs 5
  ns.lg.fill
  %n = $hget(ns.lgr,0).item
  while (%i <= %n) {
    if ($ns.lg.path($hget(ns.lgr,%i)) == %want) {
      did -c ns_logs 8 %i
      ns.lg.open $hget(ns.lgr,%i)
      return
    }
    inc %i
  }
}
on *:DIALOG:ns_logs:sclick:3:{
  if ($hget(ns.lgc,$did(ns_logs,3).sel) == -) did -c ns_logs 3 1
  ns.lg.fill
}
on *:DIALOG:ns_logs:edit:5:{ ns.lg.fill }
on *:DIALOG:ns_logs:sclick:7:{
  ns.set logs sort $did(ns_logs,7).sel
  ns.lg.fill
}
on *:DIALOG:ns_logs:sclick:12:{ ns.set logs show $did(ns_logs,12).sel }
on *:DIALOG:ns_logs:dclick:8:{ ns.lg.openpicked }
on *:DIALOG:ns_logs:sclick:10:{ ns.lg.openpicked }
on *:DIALOG:ns_logs:sclick:13:{
  var %i = $hget(ns.lgr,$did(ns_logs,8).sel)
  if (%i) run explorer $+(/select,$chr(44),$qt($ns.lg.path(%i)))
  else run explorer $qt($logdir)
}
on *:DIALOG:ns_logs:sclick:14:{ ns.later ns.lg.askdel }
on *:DIALOG:ns_logs:sclick:17:{ ns.lg.findone }
on *:DIALOG:ns_logs:sclick:18:{ ns.lg.findlisted }
on *:DIALOG:ns_logs:sclick:20:{ ns.lg.rescan }
alias ns.lg.openpicked {
  var %i = $hget(ns.lgr,$did(ns_logs,8).sel)
  if (!%i) { did -ra ns_logs 9 Pick a log first. | return }
  ns.lg.open %i
}
alias ns.lg.askdel {
  var %i = $hget(ns.lgr,$did(ns_logs,8).sel)
  if (!%i) return
  if (!$input(Move the log of $ns.lg.target(%i) $+($chr(40),$ns.lg.net(%i),$chr(41)) to the recycle bin $+ $chr(63) $+ $crlf $+ $nopath($ns.lg.path(%i)),yq,Delete log)) return
  .remove -b $qt($ns.lg.path(%i))
  ns.lg.rescan
}

; ---------------------------------------------------------------- showing a log
; the viewer window is opened once and reused; the text keeps its colours exactly as mIRC logged it
alias ns.lg.win {
  if (!$window(@NeonLog)) window -Cz @NeonLog 140 70 900 600
  else window -a @NeonLog
  clear @NeonLog
}
alias ns.lg.open {
  var %i = $1, %f = $ns.lg.path(%i), %show = $ns.get(logs,show,2), %lines = $gettok(500 2000 10000 0,%show,32), %total, %what
  if (%f == $null) || (!$exists(%f)) { ns.err that log is gone - press Rescan. | return }
  %total = $lines(%f)
  if (!%total) { ns.err that log is empty. | return }
  if (%lines == 0) && (%total > 100000) && (!$input(This log has %total lines. Load all of it $+ $chr(63),yq,Big log)) %lines = 2000
  ns.lg.win
  if (%lines == 0) || (%lines >= %total) {
    loadbuf -pim @NeonLog $qt(%f)
    %what = all %total lines
  }
  else {
    loadbuf %lines -pim @NeonLog $qt(%f)
    %what = last %lines of %total lines
  }
  titlebar @NeonLog $+(Log:,$chr(32),$ns.lg.target(%i),$chr(32),$chr(40),$ns.lg.net(%i),$chr(41),$chr(32),$chr(183),$chr(32),%what)
  set -u3600 %ns.lg.cur %i
}
; open the file $1 around line $2 (from a search hit)
alias ns.lg.openat {
  var %f = $1, %ln = $2, %a = $max(1,$calc(%ln - 80)), %b = $calc(%ln + 160), %t = $lines(%f), %row
  if (%b > %t) %b = %t
  ns.lg.win
  loadbuf $+(%a,-,%b) -pim @NeonLog $qt(%f)
  titlebar @NeonLog $+(Log:,$chr(32),$nopath($left(%f,-4)),$chr(32),$chr(183),$chr(32),lines,$chr(32),%a,-,%b,$chr(32),$chr(40),hit at line,$chr(32),%ln,$chr(41))
  %row = $calc(%ln - %a + 1)
  if (%row >= 1) && (%row <= $line(@NeonLog,0)) sline @NeonLog %row
}

; ---------------------------------------------------------------- searching
; the question goes in hash ns.lgq (text, regex 0/1) so it can contain anything; ns.lg.search takes the record numbers
alias ns.lg.ask {
  if (!$hget(ns.lgq)) hmake ns.lgq 5
  hadd -m ns.lgq text $1
  hadd -m ns.lgq rx $2
}
alias ns.lg.findone {
  var %i = $hget(ns.lgr,$did(ns_logs,8).sel), %t = $did(ns_logs,15).text
  if (%t == $null) { did -ra ns_logs 9 Type what to look for first. | return }
  if (!%i) { did -ra ns_logs 9 Pick a log first. | return }
  ns.lg.ask %t $did(ns_logs,16).state
  ns.lg.search %i
}
alias ns.lg.findlisted {
  var %t = $did(ns_logs,15).text, %i = 1, %n = $hget(ns.lgr,0).item, %list
  if (%t == $null) { did -ra ns_logs 9 Type what to look for first. | return }
  while (%i <= %n) {
    %list = %list $hget(ns.lgr,%i)
    inc %i
  }
  ns.lg.ask %t $did(ns_logs,16).state
  ns.lg.search $ns.trim(%list)
}
; /neon logs search <text>: every log in the folder
alias ns.lg.searchall {
  if ($1- == $null) { ns.err usage: /neon logs search <text>   (wildcards * and ? work) | return }
  var %n = $ns.lg.scan, %i = 1, %list
  while (%i <= %n) {
    %list = %list %i
    inc %i
  }
  ns.lg.ask $1- 0
  ns.lg.search $ns.trim(%list)
}
; ns.lg.search <record numbers...>   (the text is in ns.lgq)
alias ns.lg.search {
  var %idxs = $1-, %text = $hget(ns.lgq,text), %rx = $hget(ns.lgq,rx), %pat, %sw, %cap = 3000, %hits = 0, %files = 0, %m = 1, %f, %ln, %l, %first, %i, %name, %row
  if (%text == $null) || (%idxs == $null) return
  if (!$window(@NeonLogFind)) window -Cz @NeonLogFind 160 90 900 560
  else window -a @NeonLogFind
  clear @NeonLogFind
  if ($hget(ns.lgres)) hfree ns.lgres
  hmake ns.lgres 50
  %pat = $iif(%rx,%text,$+(*,%text,*))
  %sw = $iif(%rx,nr,nw)
  while ($gettok(%idxs,%m,32) != $null) && (%hits < %cap) {
    %i = $gettok(%idxs,%m,32)
    inc %m
    %f = $ns.lg.path(%i)
    if (!$exists(%f)) continue
    %name = $+($ns.lg.target(%i),$chr(32),$chr(40),$ns.lg.net(%i),$chr(41))
    %ln = 1
    %first = 1
    while (%ln) && (%hits < %cap) {
      %l = $read(%f,%sw,%pat,%ln)
      if (%l == $null) break
      %ln = $readn
      if (%first) {
        aline -p @NeonLogFind $+($chr(2),%name,$chr(2))
        hadd -m ns.lgres $line(@NeonLogFind,0) -
        %first = 0
        inc %files
      }
      aline -pi2 @NeonLogFind $+($chr(32),$chr(32),$chr(183),$chr(32),L,%ln,$chr(32),%l)
      hadd -m ns.lgres $line(@NeonLogFind,0) $+(%f,$chr(9),%ln)
      inc %hits
      inc %ln
    }
  }
  titlebar @NeonLogFind $+(Search:,$chr(32),%text,$chr(32),$chr(183),$chr(32),%hits,$chr(32),match,$iif(%hits != 1,es),$chr(32),in,$chr(32),%files,$chr(32),log,$iif(%files != 1,s),$iif(%hits >= %cap,$chr(32) $+ $chr(40) $+ first %cap $+ $chr(41)))
  if (!%hits) aline -p @NeonLogFind No match for $qt(%text) $+ $chr(46)
  else aline -p @NeonLogFind Double-click a line to open that log at the hit.
  if ($dialog(ns_logs)) did -ra ns_logs 9 %hits match $+ $iif(%hits != 1,es) for $qt(%text) in %files log $+ $iif(%files != 1,s) - see the Search window.
}
on *:DBLCLICK:@NeonLogFind:{
  var %r = $hget(ns.lgres,$sline(@NeonLogFind,1).ln)
  if (%r == $null) || (%r == -) return
  ns.lg.openat $gettok(%r,1,9) $gettok(%r,2,9)
}
menu @NeonLog {
  Reload this log:if (%ns.lg.cur) ns.lg.open %ns.lg.cur
  Open the log folder:run explorer $qt($logdir)
  -
  Close:window -c @NeonLog
}
