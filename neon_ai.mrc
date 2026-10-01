; ============================================================================
;  NeonScript 2026  ::  AI helpers   /ai ...
;  Strictly opt-in and strictly on request.  Nothing is sent anywhere until YOU run a command, and (unless you
;  switch the question off) a confirmation shows exactly what is about to leave your PC and where it goes.
;
;      /ai catchup [n] [#chan]       summarise what you missed in a window (default: the last 150 lines)
;      /ai mentions                  summarise your unread mentions inbox
;      /ai translate <lang> [nick]   translate someone's last line (or the last line in the window)
;      /ai mod [n]                   look for spam, flooding, harassment - suggestions only, nothing is done
;      /ai do <what you want>        plain-English moderation: shows the commands, asks, queues them
;      /ai ask <question>            a plain question (no chat is sent)
;      /ai test | on | off | status | key <key>
;
;  Providers:  ollama (a model on this PC or your LAN - nothing leaves your network), openai (any OpenAI-compatible
;  service: set address, model and key) or anthropic.  The key lives in aikey.ini, protected with Windows DPAPI
;  when the helper is installed, and is never part of a backup.
;  Safety: "do" only accepts a short list of command shapes, refuses anything with $ % | ; ` { } \ and runs them
;  through the normal queue with your own channel rank.  Chat nicknames are replaced by User1, User2 ... before
;  sending (switchable) and put back in the answer.
; ============================================================================

; ---------------------------------------------------------------- settings
alias ns.ai.on return $ns.flag(ai,on,0)
alias ns.ai.provider {
  var %p = $lower($ns.get(ai,provider,ollama))
  if (%p == ollama) || (%p == openai) || (%p == anthropic) return %p
  return ollama
}
alias ns.ai.model {
  var %m = $ns.get(ai,model)
  if (%m != $null) return %m
  var %p = $ns.ai.provider
  if (%p == ollama) return llama3.2
  if (%p == anthropic) return claude-haiku-4-5-20251001
  return gpt-4o-mini
}
; seconds to wait for an answer (a local model on a CPU can be slow)
alias ns.ai.wait return $ns.get(ai,timeout,$iif($ns.ai.provider == ollama,300,120))
alias ns.ai.base {
  var %u = $remove($ns.get(ai,url),$chr(32)), %p = $ns.ai.provider
  if (%u == $null) {
    if (%p == ollama) %u = http://127.0.0.1:11434
    elseif (%p == anthropic) %u = https://api.anthropic.com
    else %u = https://api.openai.com/v1
  }
  if ($right(%u,1) == /) %u = $left(%u,-1)
  return %u
}
alias ns.ai.endpoint {
  var %b = $ns.ai.base, %p = $ns.ai.provider
  if (%p == ollama) return $+(%b,/api/chat)
  if (%p == anthropic) return $+(%b,/v1/messages)
  return $+(%b,/chat/completions)
}
; host part of the endpoint, for messages ("api.openai.com", "127.0.0.1:11434")
alias ns.ai.host {
  var %e = $ns.ai.endpoint, %p = $pos(%e,://)
  if (%p) %e = $mid(%e,$calc(%p + 3))
  return $gettok(%e,1,47)
}
; is the endpoint on this PC / the home network?  (then nothing leaves it)
alias ns.ai.islocal {
  var %h = $gettok($ns.ai.host,1,58)
  if (%h == localhost) || (%h == 127.0.0.1) return 1
  if ($regex(ns.il,%h,/^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)/)) return 1
  return 0
}
; ---- the API key: aikey.ini [ai] key  (a file of its own, so backups never contain it)
alias ns.ai.keyfile return $+($scriptdir,aikey.ini)
alias ns.ai.key {
  var %v = $readini($ns.ai.keyfile,n,ai,key)
  if ($left(%v,6) == dpapi:) return $ns.sec.dec(%v)
  return %v
}
; what the Control Panel shows in the key box when a key is stored
alias ns.ai.mask return ************
alias ns.ai.haskey return $iif($readini($ns.ai.keyfile,n,ai,key) != $null,1,0)
alias ns.ai.setkey {
  if ($1- == $null) {
    remini $qt($ns.ai.keyfile) ai key
    return
  }
  writeini -n $qt($ns.ai.keyfile) ai key $ns.sec.enc($1-)
}

; ---------------------------------------------------------------- JSON helpers
; text -> the inside of a JSON string.  chr(10) line breaks become \n.  (Backslash first, then the quote.)
alias ns.json.enc {
  var %b = $chr(92), %t = $replace($1-,%b,$+(%b,%b))
  %t = $replace(%t,$chr(34),$+(%b,$chr(34)))
  %t = $replace(%t,$chr(13),,$chr(10),$+(%b,n),$chr(9),$+(%b,t))
  return $regsubex(%t,/[\x00-\x1F]/g,)
}
; JSON string escapes -> text, keeping line breaks as chr(10)
alias ns.json.unesc2 {
  var %b = $chr(92), %t = $regsubex($1-,/\\u([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])/g,$chr($base(\1,16,10)))
  %t = $replacex(%t,$+(%b,n),$chr(10),$+(%b,r),,$+(%b,t),$chr(32),$+(%b,$chr(34)),$chr(34),$+(%b,/),/,$+(%b,%b),%b)
  return %t
}
; wrap text (chr(10) line breaks) to lines of at most N characters; chr(1) separated for ns.card
alias ns.ai.wrap {
  var %w = $1, %t = $2-, %i = 1, %n = $numtok(%t,10), %line, %out, %j, %word, %cur
  while (%i <= %n) {
    %line = $gettok(%t,%i,10)
    inc %i
    %cur = $null
    %j = 1
    while ($gettok(%line,%j,32) != $null) {
      %word = $gettok(%line,%j,32)
      inc %j
      if (%cur != $null) && ($calc($len(%cur) + $len(%word)) >= %w) {
        %out = $+(%out,$iif(%out != $null,$chr(1)),%cur)
        %cur = %word
      }
      elseif (%cur == $null) %cur = %word
      else %cur = %cur %word
    }
    if (%cur != $null) %out = $+(%out,$iif(%out != $null,$chr(1)),%cur)
  }
  return %out
}

; ---------------------------------------------------------------- what is going to be sent
; The request lives in hash table ns.aireq: sys = the instructions, u1..uN = the lines of text, n, chars.
; (mIRC variables hold ~4000 characters, so a long chat is kept line by line and joined in a binary variable.)
alias ns.ai.req.clear {
  if ($hget(ns.aireq)) hfree ns.aireq
  hmake ns.aireq 20
  hadd ns.aireq n 0
  hadd ns.aireq chars 0
}
alias ns.ai.req.sys hadd -m ns.aireq sys $1-
alias ns.ai.req.add {
  if ($1- == $null) return
  hinc -m ns.aireq n
  hinc ns.aireq chars $len($1-)
  hadd ns.aireq $+(u,$hget(ns.aireq,n)) $1-
}
; nickname anonymising: map in hash ns.aimap  (n.<lowernick> = k, k.<k> = nick; User0 is always me)
alias ns.ai.map.clear {
  if ($hget(ns.aimap)) hfree ns.aimap
  hmake ns.aimap 20
  hadd ns.aimap n 0
  hadd ns.aimap $+(n.,$lower($me)) 0
  hadd ns.aimap k.0 $me
}
alias ns.ai.anon {
  if (!$ns.flag(ai,anon,1)) return $1
  var %k = $hget(ns.aimap,$+(n.,$lower($1)))
  if (%k == $null) {
    hinc ns.aimap n
    %k = $hget(ns.aimap,n)
    hadd ns.aimap $+(n.,$lower($1)) %k
    hadd ns.aimap $+(k.,%k) $1
  }
  return $+(User,%k)
}
alias ns.ai.unmap {
  var %v = $hget(ns.aimap,$+(k.,$1))
  if (%v != $null) return %v
  return $+(User,$1)
}
; put the real nicknames back into an answer
alias ns.ai.deanon {
  if (!$hget(ns.aimap)) || (!$ns.flag(ai,anon,1)) return $1-
  return $regsubex($1-,/\bUser([0-9]+)\b/g,$ns.ai.unmap(\1))
}
; replace known nicknames inside free text (word by word, so "Bob," and "(Bob)" are caught)
alias ns.ai.scrub {
  if (!$ns.flag(ai,anon,1)) return $1-
  var %t = $1-, %i = 1, %n = $numtok(%t,32), %w, %core, %k, %out
  while (%i <= %n) {
    %w = $gettok(%t,%i,32)
    inc %i
    %core = $regsubex(%w,/^[^A-Za-z0-9_\x5B\x5D\x5C\x60\x5E\x7B\x7D\x7C-]+/,)
    %core = $regsubex(%core,/[^A-Za-z0-9_\x5B\x5D\x5C\x60\x5E\x7B\x7D\x7C-]+$/,)
    if (%core != $null) {
      %k = $hget(ns.aimap,$+(n.,$lower(%core)))
      if (%k != $null) %w = $replace(%w,%core,$+(User,%k))
    }
    %out = %out %w
  }
  return $ns.trim(%out)
}
; load the last <count> chat lines of a window into the request (newest kept, nicks anonymised); returns how many
alias ns.ai.collect {
  var %w = $1, %want = $2, %cap = $ns.get(ai,maxchars,12000), %n = $line(%w,0), %got = 0, %chars = 0, %i, %low, %l, %nick, %body, %act, %k
  %i = %n
  %low = $max(1,$calc(%n - 800))
  ns.ai.req.clear
  ns.ai.map.clear
  ; pass 1: newest to oldest, remember speaker / action / body
  while (%i >= %low) && (%got < %want) && (%chars < %cap) {
    %l = $strip($line(%w,%i))
    dec %i
    %act = 0
    if ($regex(ns.al,%l,/^(?:\[[0-9:]+\] )?<[~&@%+]*([^>]+)> (.*)$/)) {
      %nick = $regml(ns.al,1)
      %body = $regml(ns.al,2)
    }
    elseif ($regex(ns.al,%l,/^(?:\[[0-9:]+\] )?\* (\S+) (.*)$/)) {
      %nick = $regml(ns.al,1)
      %body = $regml(ns.al,2)
      %act = 1
    }
    else continue
    %body = $left($remove(%body,$chr(9),$chr(10)),300)
    inc %got
    inc %chars $calc($len(%body) + 12)
    hadd ns.aireq $+(rs,%got) $ns.ai.anon(%nick)
    hadd ns.aireq $+(rb,%got) %body
    hadd ns.aireq $+(ra,%got) %act
  }
  ; pass 2: oldest first, now that every speaker is known, scrub nicknames out of the text too
  %k = %got
  while (%k >= 1) {
    %body = $ns.ai.scrub($hget(ns.aireq,$+(rb,%k)))
    if ($hget(ns.aireq,$+(ra,%k))) ns.ai.req.add $+(*,$chr(32),$hget(ns.aireq,$+(rs,%k)),$chr(32),%body)
    else ns.ai.req.add $+($hget(ns.aireq,$+(rs,%k)),$chr(58),$chr(32),%body)
    dec %k
  }
  hdel -w ns.aireq r?*
  return %got
}
; the confirmation:  ns.ai.confirm <what is being sent>   ->  1 when the user agrees (or confirmation is switched off)
alias ns.ai.confirm {
  if (!$ns.flag(ai,confirm,1)) return 1
  return $input($ns.ai.confirm.text($1-),yq,Send to the AI service?)
}
alias ns.ai.confirm.text {
  var %n = $hget(ns.aireq,n), %k = 1, %sample, %m, %anon = $iif($ns.flag(ai,anon,1),Nicknames are replaced by User1... in the chat lines.,Nicknames are sent as they are.)
  while (%k <= %n) && ($len(%sample) < 280) {
    %sample = $+(%sample,$chr(32),$chr(124),$chr(32),$hget(ns.aireq,$+(u,%k)))
    inc %k
  }
  %m = $+(Send,$chr(32),$1-,$chr(32),to,$chr(32),$ns.ai.host,$chr(32),$chr(40),$ns.ai.provider,$chr(44),$chr(32),model,$chr(32),$ns.ai.model,$chr(41),$chr(63),$crlf,$crlf)
  %m = $+(%m,$iif($ns.ai.islocal,This address is on your own PC or network.,This leaves your PC.),$chr(32),%anon,$crlf,$crlf)
  %m = $+(%m,%n,$chr(32),line,$iif(%n != 1,s),$chr(44),$chr(32),$hget(ns.aireq,chars),$chr(32),characters. It starts:,$crlf,$left(%sample,300))
  return %m
}

; ---------------------------------------------------------------- the request
alias ns.ai.busy {
  if ($hget(ns.ai,busy)) && ($calc($ctime - $hget(ns.ai,busy)) < $ns.ai.wait) {
    ns.err still waiting for the previous AI request.
    return 1
  }
  return 0
}
; checks that run before anything is collected or asked
alias ns.ai.ready {
  if (!$ns.ai.on) {
    ns.err AI helpers are switched off - /ai on, or Control Panel > AI helpers.
    return 0
  }
  if ($ns.ai.provider != ollama) && (!$ns.ai.haskey) {
    ns.err no API key set for $ns.ai.provider - Control Panel > AI helpers, or /ai key <key>.
    return 0
  }
  if ($ns.ai.busy) return 0
  return 1
}
; ns.ai.ask <callback alias>  ->  request id (0 when it could not start).  The answer text is passed to the callback.
alias ns.ai.ask {
  var %cb = $1, %p = $ns.ai.provider, %url = $ns.ai.endpoint, %key = $ns.ai.key, %q = $chr(34), %o = $chr(123), %c = $chr(125), %b = $chr(92)
  var %mod = $ns.json.enc($ns.ai.model), %sys = $ns.json.enc($hget(ns.aireq,sys)), %n = $hget(ns.aireq,n), %k = 1, %id, %h, %file, %pre
  if (%p == anthropic) %pre = $+(%o,%q,model,%q,:,%q,%mod,%q,$chr(44),%q,max_tokens,%q,:700,$chr(44),%q,system,%q,:,%q,%sys,%q,$chr(44),%q,messages,%q,:[,%o,%q,role,%q,:,%q,user,%q,$chr(44),%q,content,%q,:,%q)
  elseif (%p == ollama) %pre = $+(%o,%q,model,%q,:,%q,%mod,%q,$chr(44),%q,stream,%q,:false,$chr(44),%q,options,%q,:,%o,%q,num_ctx,%q,:,$ns.get(ai,ctx,8192),%c,$chr(44),%q,messages,%q,:[,%o,%q,role,%q,:,%q,system,%q,$chr(44),%q,content,%q,:,%q,%sys,%q,%c,$chr(44),%o,%q,role,%q,:,%q,user,%q,$chr(44),%q,content,%q,:,%q)
  else %pre = $+(%o,%q,model,%q,:,%q,%mod,%q,$chr(44),%q,messages,%q,:[,%o,%q,role,%q,:,%q,system,%q,$chr(44),%q,content,%q,:,%q,%sys,%q,%c,$chr(44),%o,%q,role,%q,:,%q,user,%q,$chr(44),%q,content,%q,:,%q)
  bset -t &nsaib 1 %pre
  while (%k <= %n) {
    bset -t &nsaib $calc($bvar(&nsaib,0) + 1) $ns.json.enc($hget(ns.aireq,$+(u,%k)))
    inc %k
    if (%k <= %n) bset -t &nsaib $calc($bvar(&nsaib,0) + 1) $+(%b,n)
  }
  bset -t &nsaib $calc($bvar(&nsaib,0) + 1) $+(%q,%c,],%c)
  %h = Content-Type: application/json
  if (%p == openai) %h = $+(%h,$crlf,Authorization: Bearer,$chr(32),%key)
  if (%p == anthropic) %h = $+(%h,$crlf,x-api-key:,$chr(32),%key,$crlf,anthropic-version: 2023-06-01)
  bset -t &nsaih 1 $+(%h,$crlf)
  %key = $null
  %h = $null
  .mkdir $qt($ns.data(tmp))
  %file = $ns.data($+(tmp\ai_,$ticks,.json))
  %id = $urlget(%url,pfe,%file,ns.ai.done,&nsaih,&nsaib)
  if (!%id) {
    ns.err could not start the request to $ns.ai.host $+ .
    return 0
  }
  if (!$hget(ns.ai)) hmake ns.ai 10
  hadd -m ns.ai busy $ctime
  hadd -m ns.ai $+(%id,.cb) %cb
  hadd -m ns.ai $+(%id,.file) %file
  .timer.nsaitimeout -o 1 $ns.ai.wait ns.ai.timeout %id
  return %id
}
alias ns.ai.timeout {
  if ($hget(ns.ai)) hdel ns.ai busy
  if ($hget(ns.ai,$+($1,.cb)) == $null) return
  ns.err the AI service did not answer within $duration($ns.ai.wait) $+ .
  hdel -w ns.ai $+($1,.*)
  ns.ai.cleanup
}
; everything about a finished (or failed) request that should not linger in memory
alias ns.ai.cleanup {
  if ($hget(ns.aireq)) hfree ns.aireq
  if ($hget(ns.aimap)) hfree ns.aimap
  if ($hget(ns.ai)) hdel ns.ai busy
}
alias ns.ai.done {
  var %id = $1
  var %cb = $hget(ns.ai,$+(%id,.cb)), %file = $hget(ns.ai,$+(%id,.file)), %st = $ns.web.status(%id), %p = $ns.ai.provider, %sz, %t, %ans, %m
  if (%cb == $null) return
  .timer.nsaitimeout off
  hdel -w ns.ai $+(%id,.*)
  if ($hget(ns.ai)) hdel ns.ai busy
  %sz = $file(%file).size
  if (!%sz) {
    if ($exists(%file)) .remove $qt(%file)
    ns.ai.cleanup
    if (%st == $null) ns.err could not reach $ns.ai.host $+ $chr(32) $+ - is the service running?
    else ns.err the AI service answered with nothing (status %st $+ ).
    return
  }
  if (%sz > 4000) %sz = 4000
  bread $qt(%file) 0 %sz &nsair
  %t = $bvar(&nsair,1,%sz).text
  .remove $qt(%file)
  if (%st != 200) {
    ns.ai.cleanup
    if ($regex(ns.ae,%t,/"message"\s*:\s*"((?:[^"\\]|\\.)*)/)) %m = $ns.json.unesc2($regml(ns.ae,1))
    elseif ($regex(ns.ae,%t,/"error"\s*:\s*"((?:[^"\\]|\\.)*)/)) %m = $ns.json.unesc2($regml(ns.ae,1))
    else %m = $left(%t,120)
    ns.err the AI service answered $iif(%st,%st,with an error) $+ : $left($remove(%m,$chr(10),$cr,$lf),200)
    return
  }
  if (%p == anthropic) {
    if ($regex(ns.ax,%t,/"text"\s*:\s*"((?:[^"\\]|\\.)*)/)) %ans = $ns.json.unesc2($regml(ns.ax,1))
  }
  elseif ($regex(ns.ax,%t,/"content"\s*:\s*"((?:[^"\\]|\\.)*)/)) %ans = $ns.json.unesc2($regml(ns.ax,1))
  if (%ans == $null) {
    ns.ai.cleanup
    ns.err the AI service answered, but I could not find the answer in it.
    return
  }
  %cb $left(%ans,3000)
}
; the answer as a framed card in the window the command was run in (title in %ns.ai.title)
alias ns.ai.card {
  var %text = $ns.ai.deanon($1-), %w = %ns.ai.win
  if (%w != $null) && ($window(%w)) set -u2 %ns.card.win %w
  ns.card $+(%ns.ai.title,$chr(1),$ns.ai.wrap(76,%text))
  ns.ai.cleanup
}

; ---------------------------------------------------------------- the commands
alias ai neon.ai $1-
alias neon.ai {
  var %c = $lower($1)
  if (%c == $null) || (%c == status) {
    ns.say AI helpers are $iif($ns.ai.on,on,off) - provider $ns.ai.provider $+ , model $ns.ai.model $+ , $ns.ai.host $+ . /ai catchup, mentions, translate, mod, do, ask, test, on, off.
    return
  }
  if (%c == on) { ns.set ai on 1 | ns.say AI helpers on - they only run when you type a command. | return }
  if (%c == off) { ns.set ai on 0 | ns.say AI helpers off. | return }
  if (%c == key) { ns.ai.setkey $2- | ns.say API key $iif($2- != $null,saved,removed) $+ . | return }
  if (%c == settings) { neon options ai | return }
  if (%c == test) { ns.ai.cmd.test | return }
  if (%c == catchup) { ns.ai.cmd.catchup $2- | return }
  if (%c == mentions) { ns.ai.cmd.mentions | return }
  if (%c == translate) { ns.ai.cmd.translate $2- | return }
  if (%c == mod) { ns.ai.cmd.mod $2- | return }
  if (%c == do) { ns.ai.cmd.do $2- | return }
  if (%c == ask) { ns.ai.cmd.ask $2- | return }
  ns.err usage: /ai catchup [n] [#chan] / mentions / translate <language> [nick] / mod [n] / do <request> / ask <question> / test / on / off / key <key>
}
alias ns.ai.cmd.test {
  if (!$ns.ai.ready) return
  ns.ai.req.clear
  ns.ai.req.sys Reply with exactly one word: ok
  ns.ai.req.add Please reply with the word ok.
  if ($ns.ai.ask(ns.ai.show.test)) ns.say asking $ns.ai.host ( $+ $ns.ai.provider $+ , model $ns.ai.model $+ ) to say ok...
}
alias ns.ai.show.test {
  ns.ai.cleanup
  ns.say the AI service answered: $left($remove($1-,$chr(10)),120)
}
alias ns.ai.cmd.ask {
  if ($1- == $null) { ns.err usage: /ai ask <question> | return }
  if (!$ns.ai.ready) return
  ns.ai.req.clear
  ns.ai.map.clear
  ns.ai.req.sys You are a helpful assistant inside an IRC client. Answer briefly and plainly.
  ns.ai.req.add $1-
  if (!$ns.ai.confirm(your question)) { ns.ai.cleanup | return }
  set -u600 %ns.ai.win $active
  set -u600 %ns.ai.title AI answer
  if (!$ns.ai.ask(ns.ai.card)) ns.ai.cleanup
}
; ---- catch me up
alias ns.ai.cmd.catchup {
  var %n = 150, %w = $active, %got
  if ($1 isnum) {
    %n = $min(500,$1)
    if ($2 != $null) %w = $2
  }
  elseif ($1 != $null) %w = $1
  if (!$ns.ai.ready) return
  if (!$window(%w)) { ns.err no window called %w $+ . | return }
  %got = $ns.ai.collect(%w,%n)
  if (%got < 3) { ns.err not enough chat in %w to summarise. | ns.ai.cleanup | return }
  ns.ai.req.sys You summarise IRC chat logs for someone who was away. Be concise and concrete: the main topics, any decisions or answers, questions that were asked and are still open, links worth opening. The reader is $iif($ns.flag(ai,anon,1),User0,$me) - mention anything addressed to them. Plain text, at most 12 short lines, no markdown headings.
  if (!$ns.ai.confirm(the last %got chat lines of %w)) { ns.ai.cleanup | return }
  set -u600 %ns.ai.win %w
  set -u600 %ns.ai.title Catch up - %w
  if ($ns.ai.ask(ns.ai.card)) ns.say summarising %w ...
  else ns.ai.cleanup
}
; ---- unread mentions
alias ns.ai.cmd.mentions {
  var %n = $hget(ns.mi,n), %k = $max(1,$calc(%n - 199)), %v, %cnt = 0
  if (!$ns.ai.ready) return
  ns.ai.req.clear
  ns.ai.map.clear
  while (%k <= %n) {
    %v = $hget(ns.mi,%k)
    inc %k
    if (%v == $null) || ($gettok(%v,6,9) != 0) continue
    ns.ai.req.add $+($gettok(%v,4,9),$chr(58),$chr(32),$ns.ai.anon($gettok(%v,5,9)),$chr(58),$chr(32),$ns.ai.scrub($left($gettok(%v,7-,9),240)))
    inc %cnt
  }
  if (!%cnt) { ns.say no unread mentions to summarise. | ns.ai.cleanup | return }
  ns.ai.req.sys You summarise a person's unread IRC mentions (each line is: channel or sender, who wrote it, the text). The reader is $iif($ns.flag(ai,anon,1),User0,$me) $+ . Group them by channel or person; say what each needs from them and what is urgent. At most 10 short lines.
  if (!$ns.ai.confirm(your %cnt unread mentions)) { ns.ai.cleanup | return }
  set -u600 %ns.ai.win $active
  set -u600 %ns.ai.title Unread mentions
  if ($ns.ai.ask(ns.ai.card)) ns.say summarising %cnt mentions ...
  else ns.ai.cleanup
}
; ---- translate
alias ns.ai.cmd.translate {
  var %lang = $1, %nick = $2, %w = $active, %n = $line(%w,0), %i = %n, %l, %txt
  if (%lang == $null) { ns.err usage: /ai translate <language> [nick] | return }
  if (!$ns.ai.ready) return
  while (%i > 0) && (%txt == $null) && (%i > $calc(%n - 300)) {
    %l = $strip($line(%w,%i))
    dec %i
    if ($regex(ns.tr2,%l,/^(?:\[[0-9:]+\] )?<[~&@%+]*([^>]+)> (.*)$/)) {
      if (%nick == $null) || ($regml(ns.tr2,1) == %nick) %txt = $regml(ns.tr2,2)
    }
  }
  if (%txt == $null) { ns.err nothing to translate in %w $+ . | return }
  ns.ai.req.clear
  ns.ai.map.clear
  ns.ai.req.sys Translate the user's text into %lang $+ . Reply with the translation only.
  ns.ai.req.add %txt
  if (!$ns.ai.confirm(one chat line to translate)) { ns.ai.cleanup | return }
  set -u600 %ns.ai.win %w
  set -u600 %ns.ai.title Translation
  if ($ns.ai.ask(ns.ai.card)) ns.say translating ...
  else ns.ai.cleanup
}
; ---- moderation check (suggestions only)
alias ns.ai.cmd.mod {
  var %n = $iif($1 isnum,$min(300,$1),120), %w = $active, %got
  if (!$ns.ischan(%w)) { ns.err open a channel window first. | return }
  if (!$ns.ai.ready) return
  %got = $ns.ai.collect(%w,%n)
  if (%got < 3) { ns.err not enough chat in %w to look at. | ns.ai.cleanup | return }
  ns.ai.req.sys You help a volunteer IRC channel moderator. Read the chat and list only real concerns: spam or advertising, flooding or repeated lines, harassment, ban evasion. One line per concern: the speaker name exactly as written, the evidence in a few words, and a suggested step chosen from: warn / quiet / kick / ban / watch. Say Nothing concerning. if there is none. Never invent names. You only advise; you do not act.
  if (!$ns.ai.confirm(the last %got chat lines of %w)) { ns.ai.cleanup | return }
  set -u600 %ns.ai.win %w
  set -u600 %ns.ai.title Moderation check - %w (suggestions only)
  if ($ns.ai.ask(ns.ai.card)) ns.say checking %w ...
  else ns.ai.cleanup
}

; ---- plain-English commands
alias ns.ai.cmd.do {
  var %w = $active, %req = $1-, %n = $nick(%w,0), %i = 1, %list, %rk
  if (%req == $null) { ns.err usage: /ai do <what you want done in this channel> | return }
  if (!$ns.ischan(%w)) { ns.err open a channel window first. | return }
  if (!$ns.ai.ready) return
  while (%i <= %n) && (%i <= 80) {
    %list = %list $nick(%w,%i)
    inc %i
  }
  %rk = $ns.rk.name($ns.rk.of(%w,$me))
  ns.ai.req.clear
  ns.ai.map.clear
  ns.ai.req.sys You turn a channel operator's request into IRC commands. Use ONLY these forms: /kick <nick> [reason]  /ban <nick>  /neon quiet <nick> [10m] [reason]  /neon unquiet <nick>  /neon mass <voice|devoice|kick|ban|kickban|quiet> <pattern> [-r reason] [-t 10m] [-n]  /neon ignore <nick> [10m]  /topic <text>  /mode <modes and arguments>. At most 5 commands. Use only nicks from the list. Reply with JSON only, like {"commands":["/kick nick reason"],"say":"one short sentence"}
  ns.ai.req.add Channel: %w
  ns.ai.req.add My nick: $me
  ns.ai.req.add My rank: $iif(%rk,%rk,none)
  ns.ai.req.add Nicks here: $ns.trim(%list)
  ns.ai.req.add Request: %req
  if (!$ns.ai.confirm(your request and this channel's nick list)) { ns.ai.cleanup | return }
  set -u600 %ns.ai.win %w
  set -u600 %ns.ai.cid $cid
  if ($ns.ai.ask(ns.ai.show.do)) ns.say working out the commands ...
  else ns.ai.cleanup
}
; models may wrap the JSON in code fences or prose: pull out the commands array
alias ns.ai.show.do {
  var %t = $1-, %n, %i = 1, %c, %ok = 0, %list, %say, %cmds, %f
  ns.ai.cleanup
  if (!$regex(ns.ac,%t,/"commands"\s*:\s*\[(.*?)\]/s)) {
    set -u600 %ns.ai.title Command suggestion
    ns.ai.card I could not turn that into commands. $+ $chr(10) $+ $left(%t,300)
    return
  }
  %cmds = $regml(ns.ac,1)
  if ($regex(ns.as,%t,/"say"\s*:\s*"((?:[^"\\]|\\.)*)"/)) %say = $ns.json.unesc2($regml(ns.as,1))
  %n = $regex(ns.ai1,%cmds,/"((?:[^"\\]|\\.)*)"/g)
  if ($hget(ns.aido)) hfree ns.aido
  hmake ns.aido 10
  while (%i <= %n) && (%i <= 5) {
    %c = $ns.trim($ns.json.unesc2($regml(ns.ai1,%i)))
    inc %i
    %f = $null
    if ($ns.ai.safecmd(%c)) %f = $ns.ai.final(%ns.ai.win,%c)
    if (%f == $null) {
      %list = $+(%list,$iif(%list != $null,$chr(10)),refused:,$chr(32),$left(%c,100))
      continue
    }
    inc %ok
    %list = $+(%list,$iif(%list != $null,$chr(10)),%c)
    hadd ns.aido %ok %f
  }
  if (%n > 5) %list = $+(%list,$chr(10),(only the first 5 are used))
  hadd ns.aido n %ok
  hadd ns.aido win %ns.ai.win
  hadd ns.aido cid %ns.ai.cid
  set -u600 %ns.ai.title Suggested commands
  ns.ai.card $iif(%say != $null,%say $+ $chr(10)) $+ $iif(%list != $null,%list,nothing usable)
  if (%ok) ns.later ns.ai.rundo
}
; only these shapes, and no characters that could smuggle anything else in
alias ns.ai.safecmd {
  var %c = $1-, %v
  if (%c == $null) || ($len(%c) > 200) return 0
  if ($regex(ns.sf,%c,/[\x24\x25\x7C\x3B\x60\x7B\x7D\x5C]/)) return 0
  if (!$regex(ns.sf2,%c,/^[A-Za-z0-9 #@*!._:\/~+<>()?\x2C'\x22=-]+$/)) return 0
  if ($istok(%c,-y,32)) return 0
  %v = $lower($gettok(%c,1,32))
  if (%v == /kick) || (%v == /ban) || (%v == /topic) || (%v == /mode) return 1
  if (%v == /neon) && ($istok(quiet unquiet mass ignore,$lower($gettok(%c,2,32)),32)) return 1
  return 0
}
; does this word look like a channel name?  ($ischan only knows channels you have joined)
alias ns.ai.chname return $iif($regex(ns.cn,$1,/^[\x23\x26\x21]/),1,0)
; the command as it will really be run: channel commands get the channel spelled out (a command naming another channel is dropped)
alias ns.ai.final {
  var %w = $1, %c = $2-, %v = $lower($gettok($2-,1,32)), %a = $gettok($2-,2,32)
  if (%v == /neon) return $mid(%c,2)
  if ($ns.ai.chname(%a)) && (%a != %w) return $null
  if ($ns.ai.chname(%a)) %c = $gettok(%c,3-,32)
  else %c = $gettok(%c,2-,32)
  if (%c == $null) return $null
  return $+($mid(%v,2),$chr(32),%w,$chr(32),%c)
}
; run one queued command with the right window in front (the neon commands use the active window)
alias ns.ai.exec {
  window -a $1
  $2-
}
alias ns.ai.rundo {
  var %n = $hget(ns.aido,n), %w = $hget(ns.aido,win), %cid = $hget(ns.aido,cid), %i = 1, %c
  if (!%n) return
  if (!$input(Run these %n command(s) in %w $+ $chr(63),yq,Run the suggested commands)) return
  while (%i <= %n) {
    %c = $hget(ns.aido,%i)
    inc %i
    scid %cid ns.mq.add %w ai ns.ai.exec %w %c
  }
  hfree ns.aido
  ns.say sent %n command(s) to the queue - they go out a little apart.
}
