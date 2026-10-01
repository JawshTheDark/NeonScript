; ============================================================================
;  NeonScript 2026  ::  custom toolbar
;  Replaces mIRC's toolbar with state-aware PNG buttons (alpha transparency),
;  per-button right-click menus, a toolbar editor, and USER-DEFINED buttons:
;  any icon (bundled, PNG/ICO/BMP, or an icon inside an EXE/DLL), any command,
;  and a right-click menu of your own.  Stored in custom.ini.
; ============================================================================

alias ns.tb.all return connect servers channels favorites chanctl query away dnd sound notify mentions mprev mplay mnext dash theme fx symbols protect access dcc logs options help
alias ns.tb.default return connect servers channels favorites chanctl query - away dnd sound notify mentions - mprev mplay mnext - dash theme fx symbols - protect access dcc logs - options help
alias ns.tb.order return $ns.get(toolbar,order,$ns.tb.default)
alias ns.tb.size return $ns.get(toolbar,size,2)

; ---------------------------------------------------------------- custom button storage
alias ns.cb.ini return $+($scriptdir,custom.ini)
alias ns.cb.ids {
  var %i = 1, %o
  while ($ini($ns.cb.ini,%i)) {
    %o = %o $v1
    inc %i
  }
  return %o
}
alias ns.cb.exists return $iif($readini($ns.cb.ini,n,$1,tip) != $null,$true,$false)
alias ns.cb.get {
  var %v = $readini($ns.cb.ini,n,$1,$2)
  if ($len(%v) == 0) return $3-
  return %v
}
alias ns.cb.set {
  if ($3- == $null) writeini -nz $qt($ns.cb.ini) $1 $2
  else writeini -n $qt($ns.cb.ini) $1 $2 $3-
}
; next free id: cb1, cb2, ...
alias ns.cb.newid {
  var %n = 1
  while ($ns.cb.exists($+(cb,%n))) inc %n
  return $+(cb,%n)
}
; resolve the icon setting to a real file: a bundled name ("wand"), or a path
alias ns.cb.iconfile {
  var %i = $ns.cb.get($1,icon,wand)
  if ($pos(%i,$chr(92))) || ($pos(%i,$chr(58))) || ($pos(%i,$chr(47))) return %i
  return $ns.icon(%i $+ .png)
}
alias ns.cb.isimg return $iif($right($1,4) isin .png .bmp .jpg .gif jpeg,$true,$false)
; run every line of a button's command list (lines separated by | in the ini)
alias ns.cb.run {
  var %id = $1, %c = $ns.cb.get(%id,cmd), %i = 1
  if (!$ns.cb.exists(%id)) return
  while ($gettok(%c,%i,124) != $null) {
    ; a zero-delay timer parses the line fresh, so $me / $chan / $active etc. work
    .timer -do 1 0 $v1
    inc %i
  }
}
; one popup file per button, regenerated whenever the button is saved
alias ns.cb.menufile return $ns.data($+(cbmenu_,$1,.txt))
alias ns.cb.writemenu {
  var %id = $1, %f = $ns.cb.menufile(%id), %m = $ns.cb.get(%id,menu), %i = 1
  if ($exists(%f)) .remove $qt(%f)
  while ($gettok(%m,%i,124) != $null) {
    write $qt(%f) $v1
    inc %i
  }
  if (%m != $null) write $qt(%f) -
  write $qt(%f) Edit this button...: $+ ns.cb.edit %id
  write $qt(%f) Remove from toolbar: $+ ns.cb.del %id
}
alias ns.cb.del {
  if (!$ns.cb.exists($1)) return
  if (!$input(Remove the toolbar button $qt($ns.cb.get($1,tip)) $+ ?,yq,Remove button)) return
  remini $qt($ns.cb.ini) $1
  if ($exists($ns.cb.menufile($1))) .remove $qt($ns.cb.menufile($1))
  ns.set toolbar order $remtok($ns.tb.order,$1,1,32)
  .signal -n ns.cbchanged
  .timer.nstbrb -o 1 0 ns.tb.build
}
alias ns.cb.edit {
  set -u60 %ns.cb.cur $1
  ns.dlg ns_cb ns_cb
}

; /neon button                 new button (dialog)
; /neon button list|del <id>|add <icon> <command...>
alias neon.button {
  var %c = $lower($1)
  if (%c == $null) {
    set -u60 %ns.cb.cur $null
    ns.dlg ns_cb ns_cb
    return
  }
  if (%c == list) {
    var %i = 1
    while ($gettok($ns.cb.ids,%i,32)) {
      ns.say $v1 - $ns.cb.get($v1,tip) $+ : $ns.cb.get($v1,cmd)
      inc %i
    }
    if (!$ns.cb.ids) ns.say no custom buttons yet - try /neon button
    return
  }
  if (%c == del) {
    if ($ns.cb.exists($2)) ns.cb.del $2
    else ns.err no such button: $2
    return
  }
  if (%c == add) {
    if ($3 == $null) { ns.err usage: /neon button add <icon> <command...> | return }
    var %id = $ns.cb.newid
    ns.cb.set %id tip $3-
    ns.cb.set %id icon $2
    ns.cb.set %id cmd $3-
    ns.set toolbar order $ns.tb.order %id
    ns.cb.writemenu %id
    .signal -n ns.cbchanged
    ns.tb.build
    ns.say added button %id
    return
  }
  ns.err usage: /neon button (new), list, del <id> or add <icon> <command...>
}

; ---------------------------------------------------------------- labels / icons / tips
alias ns.tb.allx return $ns.tb.all $ns.cb.ids
alias ns.tb.tip {
  var %n = $1
  if ($ns.cb.exists(%n)) return $ns.cb.get(%n,tip)
  if (%n == connect) return $iif($status == connected,Disconnect from $server,Connect to IRC)
  if (%n == servers) return Servers & networks
  if (%n == channels) return Channel list
  if (%n == favorites) return Channel favorites
  if (%n == chanctl) return Channel control (modes, topic, bans, users)
  if (%n == query) return New private message
  if (%n == away) return $iif($away,Back from away,Set away)
  if (%n == dnd) return Do not disturb $+ $iif($donotdisturb,: ON,: off)
  if (%n == sound) return Sounds $+ $iif($ns.flag(sound,enabled,1),: on,: muted)
  if (%n == notify) return Notify / buddy list
  if (%n == mentions) return Mentions inbox $+ $iif($isalias(ns.mi.unread) && $ns.mi.unread,$chr(32) $+ $chr(40) $+ $ns.mi.unread unread $+ $chr(41))
  if (%n == mprev) return Previous track
  if (%n == mnext) return Next track
  if (%n == mplay) return $iif($isalias(ns.md.track) && $ns.md.track != $null && $ns.md.status != none,$iif($ns.md.status == playing,Pause,Play) $+ $chr(58) $ns.md.track,Play / pause media)
  if (%n == dash) return Dashboard
  if (%n == theme) return Themes
  if (%n == fx) return Text effects
  if (%n == symbols) return Symbol map
  if (%n == protect) return Protection
  if (%n == access) return Userlist & access
  if (%n == dcc) return File transfers
  if (%n == logs) return Log files
  if (%n == options) return NeonScript control panel
  if (%n == help) return Help & about
  return %n
}
alias ns.tb.icon {
  var %n = $1
  if (%n == connect) return $iif($status == connected,disconnect,connect) $+ .png
  if (%n == dnd) return $iif($donotdisturb,dnd_on,dnd_off) $+ .png
  if (%n == sound) return $iif($ns.flag(sound,enabled,1),sound_on,sound_off) $+ .png
  if (%n == mentions) return $iif($isalias(ns.mi.unread) && $ns.mi.unread,mentions_new,mentions) $+ .png
  if (%n == mplay) return $iif($isalias(ns.md.status) && $ns.md.status == playing,mpause,mplay) $+ .png
  return %n $+ .png
}
; friendly names used by the editor
alias ns.tb.label {
  if ($1 == -) return $+($chr(8212),$chr(8212),$chr(32),separator,$chr(32),$chr(8212),$chr(8212))
  if ($ns.cb.exists($1)) return $+($ns.cb.get($1,tip),$chr(32),$chr(40),custom,$chr(41))
  if ($1 == connect) return Connect / disconnect
  if ($1 == away) return Away / back
  if ($1 == dnd) return Do not disturb
  if ($1 == sound) return Sounds on / off
  if ($1 == mprev) return Media: previous track
  if ($1 == mplay) return Media: play / pause
  if ($1 == mnext) return Media: next track
  return $ns.tb.tip($1)
}

; ---------------------------------------------------------------- build / sync
alias ns.tb.build {
  if (!$ns.flag(toolbar,enabled,1)) return
  toolbar -c
  var %i = 1, %t, %k = 0
  while ($gettok($ns.tb.order,%i,32)) {
    %t = $v1
    if (%t == -) {
      inc %k
      toolbar -as $+(nssep,%k)
    }
    elseif ($ns.cb.exists(%t)) tbaddcustom %t
    elseif ($findtok($ns.tb.all,%t,1,32)) tbadd %t
    inc %i
  }
  ns.tb.resync
}
alias -l tbadd {
  toolbar $+(-avz,$ns.tb.size) $+(ns_,$1) $qt($ns.tb.tip($1)) $qt($ns.icon($ns.tb.icon($1))) "/ns.tb.click $!1" $+(@nstb_,$1)
}
alias -l tbaddcustom {
  var %id = $1, %f = $ns.cb.iconfile(%id), %n = $ns.cb.get(%id,iconidx,0)
  if (!$exists(%f)) %f = $ns.asset(wand.png)
  ns.cb.writemenu %id
  if ($ns.cb.isimg(%f)) toolbar $+(-avz,$ns.tb.size) $+(ns_,%id) $qt($ns.cb.get(%id,tip)) $qt(%f) "/ns.tb.click $!1" $qt($ns.cb.menufile(%id))
  else toolbar $+(-az,$ns.tb.size,n,%n) $+(ns_,%id) $qt($ns.cb.get(%id,tip)) $qt(%f) "/ns.tb.click $!1" $qt($ns.cb.menufile(%id))
}

; refresh icons / tooltips / check state to match the current session
alias ns.tb.sync {
  if (!$ns.flag(toolbar,enabled,1)) return
  var %sig = $status $donotdisturb $ns.flag(sound,enabled,1) $away $ns.theme.current $ns.tb.size $ns.get(toolbar,iconset,glossy) $iif($isalias(ns.mi.unread),$ns.mi.unread,0) $iif($isalias(ns.md.sig),$ns.md.sig)
  if (%sig == %ns.tb.last) return
  set %ns.tb.last %sig
  tbupd connect
  tbupd dnd
  tbupd sound
  tbupd mentions
  tbupd mplay
  if ($toolbar(ns_away).name) {
    toolbar $+(-k,$iif($away,1,0)) ns_away
    toolbar -t ns_away $qt($ns.tb.tip(away))
  }
}
alias ns.tb.resync {
  unset %ns.tb.last
  ns.tb.sync
}
alias -l tbupd {
  if (!$toolbar($+(ns_,$1)).name) return
  toolbar -pv $+(ns_,$1) $qt($ns.icon($ns.tb.icon($1)))
  toolbar -t $+(ns_,$1) $qt($ns.tb.tip($1))
}

on *:CONNECT:{ ns.tb.sync }
on *:DISCONNECT:{ ns.tb.sync }
on *:ACTIVE:*:{ ns.tb.sync }
on *:SIGNAL:ns.sync:{ ns.tb.resync }
on *:SIGNAL:ns.theme:{ ns.tb.resync }

alias ns.tb.init {
  ns.tb.build
  .timer.nstbsync 0 20 ns.tb.sync
}
on *:SIGNAL:ns.boot:{ ns.tb.init }
on *:SIGNAL:ns.uninstall:{ toolbar -r }
on *:LOAD:{ .timer.nstbinit -o 1 1 ns.tb.init }

; ---------------------------------------------------------------- button actions
alias ns.tb.click {
  var %n = $right($1,-3)
  if ($ns.cb.exists(%n)) { ns.cb.run %n | return }
  if (%n == connect) { ns.tb.connect | return }
  if (%n == servers) { neon servers | return }
  if (%n == channels) { list | return }
  if (%n == favorites) { favorites | return }
  if (%n == chanctl) { channel | return }
  if (%n == query) { query $$?="Open a private message with:" | return }
  if (%n == away) {
    if ($away) neon back
    else neon away
    return
  }
  if (%n == dnd) { neon dnd | return }
  if (%n == sound) { neon mute | return }
  if (%n == notify) { notify -s | return }
  if (%n == mentions) { neon mentions | return }
  if (%n == mprev) { ns.md.send prev | return }
  if (%n == mplay) { ns.md.send toggle | return }
  if (%n == mnext) { ns.md.send next | return }
  if (%n == dash) { neon dash | return }
  if (%n == theme) { neon themes | return }
  if (%n == fx) { neon fx | return }
  if (%n == symbols) { neon chars | return }
  if (%n == protect) { neon options protect | return }
  if (%n == access) { neon users | return }
  if (%n == dcc) { dcc send $$?="Send a file to:" | return }
  if (%n == logs) { run explorer $qt($logdir) | return }
  if (%n == options) { neon options | return }
  if (%n == help) { neonhelp | return }
}
alias ns.tb.connect {
  if ($status == connected) || ($status == connecting) { disconnect | return }
  if ($isalias(ns.srv.quick)) ns.srv.quick
  else server
}

; /neon toolbar [edit|reset|on|off|rebuild]
alias neon.toolbar {
  var %c = $lower($1)
  if (%c == $null) || (%c == edit) { ns.dlg ns_tbedit ns_tbedit | return }
  if (%c == reset) { ns.del toolbar order | ns.del toolbar size | ns.tb.build | ns.say toolbar reset. | return }
  if (%c == on) { ns.set toolbar enabled 1 | ns.tb.build | return }
  if (%c == off) { ns.set toolbar enabled 0 | toolbar -r | ns.say default mIRC toolbar restored. | return }
  if (%c == rebuild) { ns.tb.build | return }
  ns.err usage: /neon toolbar edit, reset, on, off or rebuild
}

; ---------------------------------------------------------------- right-click menus (built-in buttons)
menu @nstb_connect {
  $iif($status == connected,$style(2)) Connect:ns.tb.connect
  $iif($status != connected,$style(2)) Disconnect:disconnect
  Connect in a new window:server -m
  -
  Networks
  .$submenu($ns.srv.menu($1))
  Servers & networks...:neon servers
}
menu @nstb_servers {
  Servers & networks...:neon servers
  mIRC server list:server -d
}
menu @nstb_channels {
  Channel list:list
  Favorites:favorites
  Join a channel...:join $$?="Channel to join:"
}
menu @nstb_favorites {
  Channel favorites:favorites
  Join a channel...:join $$?="Channel to join:"
}
menu @nstb_chanctl {
  Channel control...:channel
  Kick && ban...:neon kb
  Clone scanner:neon clones
  Topic history:neon cc
}
menu @nstb_query {
  New private message...:query $$?="Nickname:"
  Whois...:whois $$?="Nickname:"
}
menu @nstb_away {
  $iif($away,$style(2)) Set away...:neon away
  $iif(!$away,$style(2)) Back:neon back
  -
  $iif($ns.flag(away,auto,0),$style(1)) Auto-away when idle:ns.toggle away auto 0 | ns.say auto-away $iif($ns.flag(away,auto,0),on,off)
  Away messages...:neon messages away
  Away log:neon awaylog
}
menu @nstb_dnd {
  $iif($donotdisturb,$style(1)) Do not disturb:neon dnd
}
menu @nstb_sound {
  $iif($ns.flag(sound,enabled,1),$style(1)) Sounds enabled:neon mute
  Sound manager...:neon sounds
}
menu @nstb_notify {
  Notify list:notify -s
}
menu @nstb_dash {
  Show / hide dashboard:neon dash
  Splash screen:neon splash
}
menu @nstb_fx {
  Text effects...:neon fx
}
menu @nstb_symbols {
  Symbol map...:neon chars
}
menu @nstb_protect {
  Protection settings...:neon options protect
  Userlist...:neon users
  Clone scanner:neon clones
}
menu @nstb_access {
  Userlist...:neon users
  Kick && ban...:neon kb
}
menu @nstb_dcc {
  Send a file...:dcc send $$?="Send a file to:"
  Chat with...:dcc chat $$?="Chat with:"
  Open file server:fserve $$?="Offer file server to:" 5 $mircdir
}
menu @nstb_logs {
  Open logs folder:run explorer $qt($logdir)
  View current window's log:{
    if ($window($active).logfile) logview $qt($v1)
    else ns.err no log file for this window
  }
  Enable logging here:log on $active
}
menu @nstb_options {
  NeonScript control panel...:neon
  Customize toolbar...:neon toolbar edit
  Add a custom button...:neon button
  Reset toolbar:neon toolbar reset
  -
  mIRC options:options
  Reload NeonScript:neon reload
}
menu @nstb_help {
  Command reference:neonhelp
  About NeonScript:neon about
  -
  Self-test:neon selftest
  Debug console:neon debug
  Backup && restore...:neon backup
  Repair:neon repair
  -
  mIRC help:help
}

; ---------------------------------------------------------------- toolbar editor dialog
dialog ns_tbedit {
  title "Customize Toolbar"
  size -1 -1 236 192
  option dbu
  text "Tick the buttons you want, reorder them with Move up / Move down, or add your own buttons.", 1, 6 6 224 16
  list 2, 6 24 140 144, check size vsbar
  button "Move up", 3, 152 24 78 13
  button "Move down", 4, 152 40 78 13
  button "New custom button...", 12, 152 60 78 13
  button "Edit custom button...", 13, 152 76 78 13
  button "Delete custom button", 14, 152 92 78 13
  button "Reset to default", 5, 152 110 78 13
  box "Icon size", 6, 152 128 78 40
  radio "Small", 7, 158 138 66 9
  radio "Large", 8, 158 148 66 9
  radio "Actual (32 px)", 9, 158 158 66 9
  button "OK", 10, 126 174 50 13, ok default
  button "Cancel", 11, 180 174 50 13, cancel
}
on *:DIALOG:ns_tbedit:init:*:{
  ; saved (visible) order first, then every hidden button appended unchecked
  tbefill $ns.tb.order
  did -c ns_tbedit $calc(6 + $ns.tb.size)
}
; (re)populate the list.  $1- = the tokens that should be ticked, in order
alias -l tbefill {
  var %vis = $1-, %all = $1-, %i = 1, %t, %clean
  while ($gettok($ns.tb.allx,%i,32)) {
    %t = $v1
    if (!$findtok(%vis,%t,1,32)) %all = %all %t
    inc %i
  }
  ; drop custom buttons that no longer exist
  %i = 1
  while ($gettok(%all,%i,32)) {
    %t = $v1
    if (%t == -) || ($findtok($ns.tb.all,%t,1,32)) || ($ns.cb.exists(%t)) %clean = %clean %t
    inc %i
  }
  set -u3600 %ns.tbe.keys %clean
  did -r ns_tbedit 2
  %i = 1
  while ($gettok(%clean,%i,32)) {
    %t = $v1
    did -a ns_tbedit 2 $ns.tb.label(%t)
    if ($findtok(%vis,%t,1,32)) || (%t == -) did -s ns_tbedit 2 %i
    inc %i
  }
  did -c ns_tbedit 2 1
}
; ticked tokens, in list order
alias -l tbeticked {
  var %i = 1, %n = $did(ns_tbedit,2).lines, %o
  while (%i <= %n) {
    if ($did(ns_tbedit,2,%i).cstate) %o = %o $gettok(%ns.tbe.keys,%i,32)
    inc %i
  }
  return %o
}
; keep the list in sync when a custom button is created / edited / deleted
on *:SIGNAL:ns.cbchanged:{
  if ($dialog(ns_tbedit)) tbefill $tbeticked
}
on *:DIALOG:ns_tbedit:sclick:3,4:{
  var %n = $did(ns_tbedit,2).sel, %m = $iif($did == 3,$calc(%n - 1),$calc(%n + 1))
  if (!%n) || (%m < 1) || (%m > $did(ns_tbedit,2).lines) return
  var %ta = $did(ns_tbedit,2,%n), %tb = $did(ns_tbedit,2,%m)
  var %ca = $did(ns_tbedit,2,%n).cstate, %cb = $did(ns_tbedit,2,%m).cstate
  var %ka = $gettok(%ns.tbe.keys,%n,32), %kb = $gettok(%ns.tbe.keys,%m,32)
  did -o ns_tbedit 2 %n %tb
  did -o ns_tbedit 2 %m %ta
  did $iif(%cb,-s,-l) ns_tbedit 2 %n
  did $iif(%ca,-s,-l) ns_tbedit 2 %m
  set -u3600 %ns.tbe.keys $puttok($puttok(%ns.tbe.keys,%kb,%n,32),%ka,%m,32)
  did -c ns_tbedit 2 %m
}
on *:DIALOG:ns_tbedit:sclick:12:{
  set -u60 %ns.cb.cur $null
  ns.dlg ns_cb ns_cb
}
on *:DIALOG:ns_tbedit:sclick:13:{
  var %k = $gettok(%ns.tbe.keys,$did(ns_tbedit,2).sel,32)
  if ($ns.cb.exists(%k)) ns.cb.edit %k
  else ns.err pick one of your custom buttons first.
}
on *:DIALOG:ns_tbedit:sclick:14:{
  var %k = $gettok(%ns.tbe.keys,$did(ns_tbedit,2).sel,32)
  if ($ns.cb.exists(%k)) ns.later ns.cb.del %k
  else ns.err pick one of your custom buttons first.
}
on *:DIALOG:ns_tbedit:sclick:5:{
  ns.del toolbar order
  ns.del toolbar size
  dialog -x ns_tbedit
  ns.tb.build
}
on *:DIALOG:ns_tbedit:sclick:10:{
  var %out = $tbeticked
  ns.set toolbar order $iif(%out,%out,$ns.tb.default)
  ns.set toolbar size $iif($did(ns_tbedit,7).state,1,$iif($did(ns_tbedit,8).state,2,3))
  .timer -o 1 0 ns.tb.build
}

; ---------------------------------------------------------------- custom button dialog
dialog ns_cb {
  title "Toolbar button"
  size -1 -1 246 196
  option dbu
  text "Tooltip (shown when you hover the button):", 1, 6 6 234 9
  edit "", 2, 6 16 234 11
  text "Icon - pick a bundled one, or browse for a PNG / ICO / BMP / EXE:", 3, 6 32 234 9
  combo 4, 6 42 80 90, drop
  edit "", 5, 90 42 108 11, autohs
  button "Browse...", 6, 202 41 38 13
  icon 7, 6 60 20 20, $mircexe, 0, noborder
  text "Left-click runs (one command per line, the / is optional):", 8, 32 62 208 9
  edit "", 9, 6 82 234 36, multi return vsbar autovs
  text "Right-click menu (one  Label:command  per line - optional):", 10, 6 122 234 9
  edit "", 11, 6 132 234 36, multi return vsbar autovs
  button "OK", 12, 134 176 50 13, ok default
  button "Cancel", 13, 190 176 50 13, cancel
}
alias -l bundled return connect disconnect servers channels favorites query away dnd_off dnd_on sound_on sound_off notify dash theme fx symbols protect access dcc logs options help search hotkeys wand plug flag
alias -l cbpreview {
  var %v = $did(ns_cb,5).text, %f
  if (%v == $null) %v = $gettok($bundled,$did(ns_cb,4).sel,32)
  if ($pos(%v,$chr(92))) || ($pos(%v,$chr(58))) %f = %v
  else %f = $ns.asset(%v $+ .png)
  if ($exists(%f)) && ($ns.cb.isimg(%f)) did -g ns_cb 7 %f
}
on *:DIALOG:ns_cb:init:*:{
  var %id = %ns.cb.cur, %i = 1, %cmds, %menu, %k, %ic, %n
  while ($gettok($bundled,%i,32)) {
    did -a ns_cb 4 $v1
    inc %i
  }
  if (%id) && ($ns.cb.exists(%id)) {
    dialog -t ns_cb Edit toolbar button
    did -ra ns_cb 2 $ns.cb.get(%id,tip)
    %ic = $ns.cb.get(%id,icon,wand)
    %n = $findtok($bundled,%ic,1,32)
    if (%n) {
      did -c ns_cb 4 %n
      did -r ns_cb 5
    }
    else {
      did -c ns_cb 4 1
      did -ra ns_cb 5 %ic
    }
    %cmds = $ns.cb.get(%id,cmd)
    %k = 1
    ns.ml.new
    while ($gettok(%cmds,%k,124) != $null) {
      ns.ml.add $v1
      inc %k
    }
    ns.ml.set ns_cb 9
    %menu = $ns.cb.get(%id,menu)
    %k = 1
    ns.ml.new
    while ($gettok(%menu,%k,124) != $null) {
      ns.ml.add $v1
      inc %k
    }
    ns.ml.set ns_cb 11
  }
  else {
    dialog -t ns_cb New toolbar button
    did -c ns_cb 4 $findtok($bundled,wand,1,32)
  }
  cbpreview
}
on *:DIALOG:ns_cb:sclick:4:{
  did -r ns_cb 5
  cbpreview
}
on *:DIALOG:ns_cb:edit:5:{ cbpreview }
on *:DIALOG:ns_cb:sclick:6:{
  var %f = $sfile($mircdir,Choose an icon,Use)
  if (%f) {
    did -ra ns_cb 5 %f
    cbpreview
  }
}
on *:DIALOG:ns_cb:sclick:12:{
  var %tip = $did(ns_cb,2).text
  if (%tip == $null) {
    did -ra ns_cb 1 Please give the button a tooltip first:
    did -f ns_cb 2
    halt
  }
  var %id = %ns.cb.cur, %new = 0, %ic, %k = 1, %c, %m
  if (!%id) || (!$ns.cb.exists(%id)) {
    %id = $ns.cb.newid
    %new = 1
  }
  ns.cb.set %id tip %tip
  %ic = $did(ns_cb,5).text
  if (%ic == $null) %ic = $gettok($bundled,$did(ns_cb,4).sel,32)
  ns.cb.set %id icon %ic
  while (%k <= $did(ns_cb,9).lines) {
    if ($did(ns_cb,9,%k) != $null) %c = %c $+ $iif(%c,$chr(124)) $+ $did(ns_cb,9,%k)
    inc %k
  }
  %k = 1
  while (%k <= $did(ns_cb,11).lines) {
    if ($did(ns_cb,11,%k) != $null) %m = %m $+ $iif(%m,$chr(124)) $+ $did(ns_cb,11,%k)
    inc %k
  }
  ns.cb.set %id cmd %c
  ns.cb.set %id menu %m
  ns.cb.writemenu %id
  if (%new) ns.set toolbar order $ns.tb.order %id
  .signal -n ns.cbchanged
  .timer.nstbrb -o 1 0 ns.tb.build
}
