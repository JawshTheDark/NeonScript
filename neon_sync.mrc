; ============================================================================
;  NeonScript 2026  ::  settings sync through a folder you choose        /neon sync ...
;  Point it at a folder that OneDrive, Dropbox, Syncthing or a git checkout already keeps in step between your PCs and
;  NeonScript keeps its settings in step through it.  Nothing leaves your PC any other way.
;
;    * Settings files are merged key by key against the state of the last sync (a three-way merge), so a change made on
;      one PC is not lost when another PC changed something else.  Both sides changed the same key: the newer file wins and
;      the loser is kept in backup\sync-conflicts.  The first sync on a new PC adopts what is already in the folder.
;    * Passwords, tokens and the AI key are NEVER written to the folder (they are tied to this PC anyway), and machine
;      specific sections (paths, helper switches, update checks) are not synced.
;    * Before NeonScript changes local files because of the folder, it takes a normal backup.
;    * What lands in the folder: your settings, profiles without secrets, userlist, rules, aliases, themes you made, message
;      lists, topic history and quotes.  Not logs, the mentions inbox, stats or the staff log.
; ============================================================================

alias ns.sync.ini return $+($scriptdir,sync.ini)
alias ns.sync.on return $iif($ns.sync.dir != $null && $readini($ns.sync.ini,n,sync,on) == 1,1,0)
; the folder the user chose (without NeonScript\), and the folder we really use inside it
alias ns.sync.root return $readini($ns.sync.ini,n,sync,folder)
alias ns.sync.dir {
  var %r = $ns.sync.root
  if (%r == $null) || (!$isdir(%r)) return $null
  return $+($remove(%r,$chr(34)),$iif($right(%r,1) != \,\),NeonScript\)
}
alias ns.sync.base return $ns.data(syncbase\)
alias ns.sync.machine {
  var %m = $readini($ns.sync.ini,n,sync,machine)
  if (%m == $null) {
    %m = $+(PC-,$base($rand(1048576,16777215),10,16))
    writeini -n $qt($ns.sync.ini) sync machine %m
  }
  return %m
}
; neon.ini sections that are shared between PCs (everything else - general, menus, ui, security, update, advanced - stays local)
alias ns.sync.sections return theme events conn toolbar sound media chat web hud protect away bot privacy staff stats v3 toast speak paste ai mass flood topic rules usr tedit evt
; settings files merged key by key  (usercode.ini - your own mSL aliases - only when sync.ini [sync] code=1, because it is code)
alias ns.sync.inis return neon.ini profiles.ini custom.ini access.ini chan.ini rules.ini themes_user.ini topic_tpl.ini $iif($readini($ns.sync.ini,n,sync,code) == 1,usercode.ini)
; plain text files: the whole file wins
alias ns.sync.texts {
  var %o = data\topics.txt data\quotes.txt, %n, %i
  %n = $findfile($ns.data(),msg_*.txt,0,1)
  %i = 1
  while (%i <= %n) {
    %o = %o data\ $+ $nopath($findfile($ns.data(),msg_*.txt,%i,1))
    inc %i
  }
  %n = $findfile($ns.data(),cbmenu_*.txt,0,1)
  %i = 1
  while (%i <= %n) {
    %o = %o data\ $+ $nopath($findfile($ns.data(),cbmenu_*.txt,%i,1))
    inc %i
  }
  return %o
}
; "data\msg_quit.txt" -> "data__msg_quit.txt"
alias ns.sync.flat return $replace($1,\,__)
; may this key travel?   $ns.sync.ok(kind,section,item)
alias ns.sync.ok {
  if ($1 == neon) return $iif($istok($ns.sync.sections,$2,32),1,0)
  if ($1 == profiles) return $iif($istok($ns.sec.items,$3,32),0,1)
  return 1
}
; sentinels for "no such key" and "key with an empty value" (printable on purpose: they travel through command lines)
alias ns.sync.miss return ~ns-missing~
alias ns.sync.empty return ~ns-empty~
; value of a key, or the "missing" sentinel
alias ns.sync.rd {
  if (!$exists($1)) return $ns.sync.miss
  if (!$ini($1,$2,$3)) return $ns.sync.miss
  var %v = $readini($1,n,$2,$3)
  return $iif(%v == $null,$ns.sync.empty,%v)
}
alias ns.sync.wr {
  ; ns.sync.wr <file> <section> <item> <value | missing sentinel | empty sentinel>
  if ($4- === $ns.sync.miss) {
    if ($exists($1)) remini $qt($1) $2 $3
    return
  }
  if ($4- === $ns.sync.empty) writeini -nz $qt($1) $2 $3
  else writeini -n $qt($1) $2 $3 $4-
}
; every allowed (section,item) pair of a file goes into hash ns.syu
alias ns.sync.collect {
  var %f = $1, %kind = $2, %s = 1, %sec, %i, %it, %n
  if (!$exists(%f)) return
  while ($ini(%f,%s) != $null) {
    %sec = $ini(%f,%s)
    inc %s
    %i = 1
    while ($ini(%f,%sec,%i) != $null) {
      %it = $ini(%f,%sec,%i)
      inc %i
      if ($ns.sync.ok(%kind,%sec,%it)) hadd ns.syu $md5($+(%sec,$chr(9),%it)) $+(%sec,$chr(9),%it)
    }
  }
}
; three-way merge of one settings file.  returns   <pulled> <pushed> <conflicts>
alias ns.sync.mergeini {
  var %fl = $1, %fr = $2, %fb = $3, %kind = $4
  var %first = $iif($exists(%fb),0,1), %lm = $file(%fl).mtime, %rm = $file(%fr).mtime
  var %pull = 0, %push = 0, %conf = 0, %n, %i, %kv, %sec, %it, %vl, %vr, %vb, %keep
  if ($hget(ns.syu)) hfree ns.syu
  hmake ns.syu 200
  ns.sync.collect %fl %kind
  ns.sync.collect %fr %kind
  ns.sync.collect %fb %kind
  %n = $hget(ns.syu,0).item
  %i = 1
  while (%i <= %n) {
    %kv = $hget(ns.syu,%i).data
    inc %i
    %sec = $gettok(%kv,1,9)
    %it = $gettok(%kv,2,9)
    %vl = $ns.sync.rd(%fl,%sec,%it)
    %vr = $ns.sync.rd(%fr,%sec,%it)
    %vb = $ns.sync.rd(%fb,%sec,%it)
    if (%vl === %vr) continue
    if (%first) {
      ; a first sync: keys only here are sent, keys only in the folder are taken, different values - the folder wins
      if (%vr === $ns.sync.miss) { ns.sync.wr %fr %sec %it %vl | inc %push }
      else { ns.sync.wr %fl %sec %it %vr | inc %pull }
      continue
    }
    if (%vr === %vb) {
      ns.sync.wr %fr %sec %it %vl
      inc %push
    }
    elseif (%vl === %vb) {
      ns.sync.wr %fl %sec %it %vr
      inc %pull
    }
    elseif (%vl === $ns.sync.miss) || (%vr === $ns.sync.miss) {
      ; deleted on one side and changed on the other: keep the key (nothing is lost)
      if (%vl === $ns.sync.miss) { ns.sync.wr %fl %sec %it %vr | inc %pull }
      else { ns.sync.wr %fr %sec %it %vl | inc %push }
    }
    else {
      inc %conf
      %keep = $iif(%rm > %lm,r,l)
      if (%keep == r) { ns.sync.wr %fl %sec %it %vr | inc %pull }
      else { ns.sync.wr %fr %sec %it %vl | inc %push }
      ns.sync.note conflict %sec $+ / $+ %it kept $iif(%keep == r,the folder's value,this PC's value)
    }
  }
  hfree ns.syu
  return %pull %push %conf
}
; the allowed part of a settings file becomes the new "last synced" state
alias ns.sync.snapshot {
  var %L = $1, %B = $2, %kind = $3, %s = 1, %sec, %i, %it
  if ($exists(%B)) .remove $qt(%B)
  if (!$exists(%L)) return
  while ($ini(%L,%s) != $null) {
    %sec = $ini(%L,%s)
    inc %s
    %i = 1
    while ($ini(%L,%sec,%i) != $null) {
      %it = $ini(%L,%sec,%i)
      inc %i
      if ($ns.sync.ok(%kind,%sec,%it)) ns.sync.wr %B %sec %it $ns.sync.rd(%L,%sec,%it)
    }
  }
  flushini %B
}
alias ns.sync.note {
  hinc -m ns.syst notes
  hadd ns.syst $+(note,$hget(ns.syst,notes)) $1-
  ns.log sync $1-
}
alias ns.sync.kindof return $iif($1 == neon.ini,neon,$iif($1 == profiles.ini,profiles,plain))

; ---------------------------------------------------------------- one text file
; returns  pulled | pushed | conflict-remote | conflict-local | same
alias ns.sync.text {
  var %rel = $1, %L = $+($scriptdir,$1), %key = $ns.sync.flat($1), %res
  var %R = $+($ns.sync.dir,files\,%key)
  var %lh = $iif($exists(%L),$md5(%L,2),-), %rh = $iif($exists(%R),$md5(%R,2),-), %bh = $readini($ns.sync.ini,n,base,%key)
  var %first = $iif(%bh == $null,1,0)
  if (%bh == $null) %bh = -
  if (%lh === %rh) {
    if (%lh != -) writeini -n $qt($ns.sync.ini) base %key %lh
    return same
  }
  if (%first) && (%rh == -) {
    .copy -o $qt(%L) $qt(%R)
    writeini -n $qt($ns.sync.ini) base %key %lh
    return pushed
  }
  if (%first) && (%lh == -) {
    .copy -o $qt(%R) $qt(%L)
    writeini -n $qt($ns.sync.ini) base %key %rh
    return pulled
  }
  if (%rh === %bh) && (!%first) {
    if (%lh != -) {
      .copy -o $qt(%L) $qt(%R)
      writeini -n $qt($ns.sync.ini) base %key %lh
    }
    return pushed
  }
  if (%lh === %bh) && (!%first) {
    if (%rh != -) {
      .copy -o $qt(%R) $qt(%L)
      writeini -n $qt($ns.sync.ini) base %key %rh
    }
    return pulled
  }
  ; both changed (or a first sync with two different files): the newer file wins, the other is kept
  var %lm = $iif($exists(%L),$file(%L).mtime,0), %rm = $iif($exists(%R),$file(%R).mtime,0)
  var %stamp = $asctime($ctime,yyyymmdd-HHnnss)
  .mkdir $qt($+($scriptdir,backup\))
  .mkdir $qt($+($scriptdir,backup\sync-conflicts\))
  if (%first || %rm > %lm) && (%rh != -) {
    if ($exists(%L)) .copy -o $qt(%L) $qt($+($scriptdir,backup\sync-conflicts\,%key,.,%stamp,.local))
    .copy -o $qt(%R) $qt(%L)
    writeini -n $qt($ns.sync.ini) base %key %rh
    %res = conflict-remote
  }
  else {
    if ($exists(%R)) .copy -o $qt(%R) $qt($+($scriptdir,backup\sync-conflicts\,%key,.,%stamp,.folder))
    .copy -o $qt(%L) $qt(%R)
    writeini -n $qt($ns.sync.ini) base %key %lh
    %res = conflict-local
  }
  if (!%first) ns.sync.note conflict %rel $+ : kept $iif(%res == conflict-remote,the folder's copy,this PC's copy) $+ ; the other copy is in backup\sync-conflicts
  return %res
}

; ---------------------------------------------------------------- run
; ns.sync.run [auto|now]   -> text summary (also said in the status window for "now")
alias ns.sync.run {
  var %dir = $ns.sync.dir, %mode = $1
  if (%dir == $null) {
    if (%mode == now) ns.err no sync folder chosen - /neon sync folder <path>
    return
  }
  if ($hget(ns.syst)) hfree ns.syst
  hmake ns.syst 10
  ns.flushall
  .mkdir $qt(%dir)
  .mkdir $qt($+(%dir,files\))
  .mkdir $qt($ns.sync.base)
  ; a normal backup first, when the folder holds something this PC has not seen yet
  var %seen = $readini($ns.sync.ini,n,state,remote), %now = $ns.sync.fingerprint
  if (%now != %seen) && (%now != -) && ($isalias(ns.bak.auto)) var %z = $ns.bak.auto(sync)
  var %i = 1, %f, %r, %pull = 0, %push = 0, %conf = 0, %files = 0
  while ($gettok($ns.sync.inis,%i,32) != $null) {
    %f = $gettok($ns.sync.inis,%i,32)
    inc %i
    var %loc = $+($scriptdir,%f), %rem = $+(%dir,files\,$ns.sync.flat(%f)), %base = $+($ns.sync.base,$ns.sync.flat(%f)), %kind = $ns.sync.kindof(%f)
    if (!$exists(%loc)) && (!$exists(%rem)) continue
    inc %files
    %r = $ns.sync.mergeini(%loc,%rem,%base,%kind)
    inc %pull $gettok(%r,1,32)
    inc %push $gettok(%r,2,32)
    inc %conf $gettok(%r,3,32)
    if ($gettok(%r,1,32) > 0) flushini %loc
    flushini %rem
    ns.sync.snapshot %loc %base %kind
  }
  %i = 1
  while ($gettok($ns.sync.texts,%i,32) != $null) {
    %f = $gettok($ns.sync.texts,%i,32)
    inc %i
    %r = $ns.sync.text(%f)
    inc %files
    if (%r == pulled) || (%r == conflict-remote) inc %pull
    elseif (%r == pushed) || (%r == conflict-local) inc %push
    if ($left(%r,8) == conflict) inc %conf
  }
  ; text files that exist only in the folder (a list another PC created) - only the known names, never a path
  var %n = $findfile($+(%dir,files\),data__*.txt,0,1), %k = 1, %nm, %rel
  while (%k <= %n) {
    %nm = $nopath($findfile($+(%dir,files\),data__*.txt,%k,1))
    inc %k
    if ($count(%nm,__) != 1) continue
    if (%nm != data__topics.txt) && (%nm != data__quotes.txt) && (data__msg_*.txt !iswm %nm) && (data__cbmenu_*.txt !iswm %nm) continue
    %rel = $replace(%nm,__,\)
    if (!$exists($+($scriptdir,%rel))) {
      .copy -o $qt($+(%dir,files\,%nm)) $qt($+($scriptdir,%rel))
      inc %pull
    }
  }
  writeini -n $qt($ns.sync.ini) state remote $ns.sync.fingerprint
  writeini -n $qt($ns.sync.ini) state lastrun $ctime
  writeini -n $qt($ns.sync.ini) state result $+(%pull,$chr(32),pulled,$chr(44),$chr(32),%push,$chr(32),pushed,$chr(44),$chr(32),%conf,$chr(32),conflicts,$chr(32),$chr(40),%files,$chr(32),files,$chr(41))
  ns.sync.manifest
  flushini $ns.sync.ini
  if (%pull > 0) && ($isalias(ns.opt.after)) ns.opt.after
  if (%mode == now) || (%pull > 0) || (%conf > 0) ns.say sync: %pull setting(s) updated from the folder, %push sent, %conf conflict(s). $iif(%pull > 0,Run /neon reload to apply everything.)
  var %notes = $hget(ns.syst,notes), %j = 1
  while (%j <= %notes) {
    ns.say sync note: $hget(ns.syst,$+(note,%j))
    inc %j
  }
  hfree ns.syst
}
; a short fingerprint of what the folder holds, so we notice when another PC changed it
alias ns.sync.fingerprint {
  var %dir = $ns.sync.dir, %n = $findfile($+(%dir,files\),*.*,0,1), %i = 1, %s
  if (%dir == $null) return -
  while (%i <= %n) {
    %s = %s $+ $file($findfile($+(%dir,files\),*.*,%i,1)).mtime $+ $file($findfile($+(%dir,files\),*.*,%i,1)).size
    inc %i
  }
  return $md5(%s)
}
alias ns.sync.manifest {
  var %f = $+($ns.sync.dir,manifest.ini)
  if ($exists(%f)) .remove $qt(%f)
  writeini -n $qt(%f) NeonScript version $ns.ver
  writeini -n $qt(%f) NeonScript last-writer $ns.sync.machine
  writeini -n $qt(%f) NeonScript written $asctime($ctime,yyyy-mm-dd HH:nn)
  writeini -n $qt(%f) NeonScript note Settings only - no passwords, tokens or API keys are stored here.
}

; ---------------------------------------------------------------- hooks
on *:SIGNAL:ns.boot:{ if ($ns.sync.on) .timer.nssyncboot -o 1 12 ns.sync.run auto }
on *:SIGNAL:ns.opts:{ if ($ns.sync.on) .timer.nssyncpush -o 1 90 ns.sync.run auto }
on *:EXIT:{ if ($ns.sync.on) ns.sync.run auto }

; ---------------------------------------------------------------- /neon sync
alias neon.sync {
  var %c = $lower($1), %d
  if (%c == folder) {
    %d = $iif($2- != $null,$2-,$sdir($iif($ns.sync.root,$ns.sync.root,$mircdir),Choose the folder your PCs share (OneDrive, Dropbox, Syncthing ...)))
    if (%d == $null) return
    if (!$isdir(%d)) { ns.err that folder does not exist. | return }
    writeini -n $qt($ns.sync.ini) sync folder %d
    ns.say sync folder: $ns.sync.dir
    return
  }
  if (%c == on) {
    if ($ns.sync.dir == $null) { ns.err choose a folder first: /neon sync folder <path> | return }
    if (!$input(Keep your settings in step through $ns.sync.dir $+ $chr(63) $+ $crlf $+ $crlf $+ NeonScript writes your settings there (nicknames$chr(44) servers$chr(44) channels$chr(44) userlist$chr(44) rules$chr(44) themes$chr(44) message lists). Passwords$chr(44) tokens and the AI key are never written. Perform lines and custom buttons run commands$chr(44) so use a folder only you can change.,yq,Turn on settings sync)) return
    writeini -n $qt($ns.sync.ini) sync on 1
    ns.sync.run now
    return
  }
  if (%c == off) { writeini -n $qt($ns.sync.ini) sync on 0 | ns.say sync is off (the folder is left as it is). | return }
  if (%c == now) { ns.sync.run now | return }
  if (%c == status) || (%c == $null) {
    ns.say sync: $iif($ns.sync.on,$+($ns.ec(join),ON,$ns.o),$+($ns.ec(kick),off,$ns.o)) $+ , folder $iif($ns.sync.dir,$ns.sync.dir,(none chosen)) $+ , this PC is $ns.sync.machine
    var %lr = $readini($ns.sync.ini,n,state,lastrun)
    if (%lr) ns.say last run $asctime(%lr,ddd HH:nn) $+ : $readini($ns.sync.ini,n,state,result)
    return
  }
  ns.err usage: /neon sync [status | folder <path> | on | off | now]
}

; ---------------------------------------------------------------- Control Panel page helpers
alias ns.sync.toggle {
  if ($ns.sync.on) neon sync off
  else neon sync on
  .timer.nssyncui -o 1 2 ns.sync.refresh
}
alias ns.sync.refresh {
  if (!$dialog(ns_opt)) return
  did -ra ns_opt 1503 $iif($ns.sync.dir,$ns.sync.dir,$null)
  did -ra ns_opt 1505 $iif($ns.sync.on,Turn off,Turn on)
  var %lr = $readini($ns.sync.ini,n,state,lastrun), %t
  %t = Sync is $iif($ns.sync.on,ON,off) $+ . This PC is called $ns.sync.machine $+ .
  if (%lr) %t = %t Last run $asctime(%lr,ddd HH:nn) $+ : $readini($ns.sync.ini,n,state,result) $+ .
  did -ra ns_opt 1508 %t
}
