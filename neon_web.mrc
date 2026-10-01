; ============================================================================
;  NeonScript 2026  ::  link and image previews
;
;    /preview <url>              a card with the page title, description, site, type, size and picture
;    Shift + double-click a link the same thing  (Control Panel > Chat & reading)
;
;  Nothing is fetched unless YOU ask for it: previews never load by themselves, so a link in chat
;  cannot make your client contact a server behind your back.  Details:
;    * only http:// and https:// addresses; local / private-network addresses are refused
;      (switch on web allowlocal in neon.ini to allow them)
;    * at most the first 64 KB of a page are read; an image is fetched whole but never above 8 MB
;    * redirects are followed by hand, at most 4, and every hop is checked the same way
;    * nothing is executed or saved outside the data\tmp folder, and it is cleaned up afterwards
;    * picture formats are decoded by mIRC itself (PNG, JPEG, GIF, BMP - the first frame of a GIF)
; ============================================================================

alias ns.lp.tmp return $ns.data(tmp\)
alias ns.lp.maxpage return 65536
alias ns.lp.maximg return 8388608

; ---------------------------------------------------------------- validation
; $ns.lp.check(url) -> "" when fine, otherwise a short reason
alias ns.lp.check {
  var %u = $1-, %host
  if ($len(%u) > 2000) return the address is too long
  if (!$regex(lpu,%u,/^https?:\/\/([^\/:?#@\s]+)(?::(\d{1,5}))?(?:[\/?#]\S*)?$/i)) return not a web address (it must start with http:// or https://)
  %host = $lower($regml(lpu,1))
  if ($ns.flag(web,allowlocal,0)) return $null
  if (%host == localhost) || ($regex(lph,%host,/\.(local|localhost|internal|lan|home|corp)$/)) return that is a local address
  if ($regex(lph,%host,/^(127|10|0)\.\d+\.\d+\.\d+$/)) return that is a local address
  if ($regex(lph,%host,/^192\.168\.\d+\.\d+$/)) || ($regex(lph,%host,/^169\.254\.\d+\.\d+$/)) return that is a local address
  if ($regex(lph,%host,/^172\.(1[6-9]|2\d|3[01])\.\d+\.\d+$/)) return that is a local address
  if ($regex(lph,%host,/^\d+$/)) return that is a numeric address
  return $null
}
; resolve a possibly relative address against the page it came from
alias ns.lp.abs {
  var %u = $1, %base = $2
  if ($regex(lpa,%u,/^https?:\/\//i)) return %u
  if (!$regex(lpb,%base,/^(https?):\/\/([^\/?#]+)([^?#]*)/i)) return $null
  var %scheme = $regml(lpb,1), %host = $regml(lpb,2), %path = $regml(lpb,3)
  if ($left(%u,2) == //) return $+(%scheme,:,%u)
  if ($left(%u,1) == /) return $+(%scheme,://,%host,%u)
  var %n = $numtok(%path,47), %dir = /
  if (%n > 1) %dir = $+(/,$gettok(%path,1- $+ $calc(%n - 1),47),/)
  return $+(%scheme,://,%host,%dir,%u)
}

; ---------------------------------------------------------------- entry points
alias preview {
  if ($1 == $null) {
    ns.err usage: /preview <url>
    return
  }
  ns.lp.start $1
}
alias neon.preview preview $1-
on *:HOTLINK:*://*:*:{
  if (!$ns.flag(web,shiftdbl,1)) return
  if ($mouse.key & 4) {
    ns.lp.start $1
    halt
  }
}

; ---------------------------------------------------------------- the card
dialog ns_lp {
  title "Link preview"
  size -1 -1 300 202
  option dbu
  icon 1, 0 0 300 30, $mircexe, 0, noborder
  icon 2, 6 36 84 62, $mircexe, 0, noborder
  text "", 3, 96 36 198 26
  text "", 4, 96 62 198 38
  text "", 5, 6 104 288 9
  text "", 6, 6 115 288 22
  text "", 7, 6 142 288 9
  button "Open in browser", 8, 6 156 66 13
  button "Copy link", 9, 76 156 44 13
  button "Show picture", 10, 124 156 54 13
  button "Close", 11, 248 156 46 13, ok cancel
  text "Previews fetch the page from its own server - your address is visible to it, like opening the link.", 12, 6 176 288 18
}
on *:DIALOG:ns_lp:init:*:{
  did -g ns_lp 1 $ns.asset(header_link.png)
  did -b ns_lp 10
}
on *:DIALOG:ns_lp:sclick:8:{ run $qt(%ns.lp.url) }
on *:DIALOG:ns_lp:sclick:9:{
  clipboard %ns.lp.url
  did -ra ns_lp 7 Link copied.
}
on *:DIALOG:ns_lp:sclick:10:{ ns.lp.showimg %ns.lp.imgfile }
on *:DIALOG:ns_lp:close:*:{ ns.lp.cleanup }

alias ns.lp.status if ($dialog(ns_lp)) did -ra ns_lp 7 $1-

; ---------------------------------------------------------------- fetching
; ns.lp.start <url>
alias ns.lp.start {
  var %u = $1, %why = $ns.lp.check(%u)
  if (%why) {
    ns.err cannot preview: %why $+ .
    return
  }
  ns.lp.cleanup
  ns.lp.reset %u
  .mkdir $qt($ns.data(tmp))
  set -u600 %ns.lp.url %u
  set -u600 %ns.lp.final %u
  unset %ns.lp.imgfile
  ns.dlg ns_lp ns_lp
  did -ra ns_lp 3 Loading...
  did -ra ns_lp 4 $chr(160)
  did -ra ns_lp 5 $chr(160)
  did -ra ns_lp 6 %u
  did -ra ns_lp 7 Contacting the server...
  did -b ns_lp 10
  ns.lp.get page %u 0
}
; ns.lp.get <page|thumb|image> <url> <hop>
alias ns.lp.get {
  var %purpose = $1, %u = $2, %hop = $3, %file, %id, %hdr = &lph
  if ($ns.lp.check(%u)) {
    ns.lp.status refused: $ns.lp.check(%u)
    return
  }
  %file = $+($ns.data(tmp\),lp_,%purpose,.bin)
  if ($exists(%file)) .remove $qt(%file)
  bunset %hdr
  bset -t %hdr 1 User-Agent: NeonScript/ $+ $ns.ver $+ $crlf
  if (%purpose == page) bset -t %hdr $calc($bvar(%hdr,0) + 1) Range: bytes=0- $+ $calc($ns.lp.maxpage - 1) $+ $crlf
  elseif (%purpose == thumb) bset -t %hdr $calc($bvar(%hdr,0) + 1) Range: bytes=0-1048575 $+ $crlf
  bset -t %hdr $calc($bvar(%hdr,0) + 1) Accept: */* $+ $crlf
  %id = $urlget(%u,gfk,%file,ns.lp.done,%hdr)
  if (!%id) {
    ns.lp.status could not start the request.
    return
  }
  hadd -mu300 ns.lpq %id $+(%purpose,$chr(9),%u,$chr(9),%hop)
  .timer.nslpguard 0 1 ns.lp.guard
}
; stop transfers that ignore the Range header and keep sending
alias ns.lp.guard {
  var %n = $hget(ns.lpq,0).item, %i = 1, %id, %max
  if (!%n) { .timer.nslpguard off | return }
  while (%i <= %n) {
    %id = $hget(ns.lpq,%i).item
    inc %i
    if ($gettok($hget(ns.lpq,%id),1,9) == image) %max = $ns.lp.maximg
    else %max = 4194304
    if ($urlget(%id).rcvd > %max) {
      noop $urlget(%id,c)
      hdel ns.lpq %id
      ns.lp.status stopped: the file is larger than the preview limit.
    }
  }
}
alias ns.lp.hdr {
  ; $1 = reply text, $2 = header name -> its value (header lines end in CR LF: the CR is removed)
  if ($regex(lph,$1,$+(/^,$2,:[ \t]*([^\r\n]*?)[ \t]*\r?$/im))) return $remove($regml(lph,1),$chr(13),$chr(10))
  return $null
}
alias ns.lp.done {
  var %id = $1, %meta = $hget(ns.lpq,%id), %purpose = $gettok(%meta,1,9), %u = $gettok(%meta,2,9), %hop = $gettok(%meta,3,9)
  var %reply = $urlget(%id).reply, %file = $urlget(%id).target, %code, %loc, %type, %total, %cl
  if (%meta == $null) return
  hdel ns.lpq %id
  if (%reply == $null) {
    ns.lp.status no answer from the server.
    return
  }
  %code = $gettok($gettok(%reply,1,13),2,32)
  if (%code isin 301 302 303 307 308) {
    %loc = $ns.lp.hdr(%reply,Location)
    if (%loc == $null) { ns.lp.status the server redirected without saying where. | return }
    if (%hop >= 4) { ns.lp.status too many redirects. | return }
    %loc = $ns.lp.abs(%loc,%u)
    if (%loc == $null) { ns.lp.status the redirect address was not usable. | return }
    if (%purpose == page) set -u600 %ns.lp.final %loc
    ns.lp.status following a redirect...
    ns.lp.get %purpose %loc $calc(%hop + 1)
    return
  }
  if (%code !isnum 200-206) {
    if (%purpose == page) {
      ns.lp.card type $ns.lp.hdr(%reply,Content-Type)
      ns.lp.fill
      ns.lp.status the server answered $iif(%code,%code,with an error) $+ .
    }
    return
  }
  %type = $lower($gettok($ns.lp.hdr(%reply,Content-Type),1,59))
  %total = $ns.lp.hdr(%reply,Content-Range)
  if ($regex(lpr,%total,/\/(\d+)$/)) %total = $regml(lpr,1)
  else %total = $ns.lp.hdr(%reply,Content-Length)
  if (%total !isnum) %total = $file(%file).size
  if (%purpose == thumb) { ns.lp.thumb %file %type | return }
  if (%purpose == image) { ns.lp.image %file %type %total | return }
  ; --- the page itself
  if ($left(%type,6) == image/) {
    ns.lp.card title $nopath(%u)
    ns.lp.card type %type
    ns.lp.card size %total
    ns.lp.fill
    if (%total isnum) && (%total <= $ns.lp.maximg) {
      if (%code == 200) || ($file(%file).size >= %total) ns.lp.image %file %type %total
      else ns.lp.get image %u 0
    }
    else ns.lp.status the picture is larger than the 8 MB preview limit.
    return
  }
  if (%type == text/html) || (%type == application/xhtml+xml) || (%type == $null) {
    ns.lp.parse %file %u %type %total
    return
  }
  ns.lp.card type %type
  ns.lp.card size %total
  ns.lp.fill
  ns.lp.status no preview for this kind of file.
}

; ---------------------------------------------------------------- reading the page
; the text between two markers, scanning the file in 4 KB pieces so one-line minified pages work too
alias ns.lp.parse {
  var %file = $1, %u = $2, %type = $3, %total = $4, %pos = 0, %size = $file(%file).size, %chunk, %buf, %title, %otitle, %desc, %odesc, %site, %img, %done = 0
  var %bv = &lpb
  while (%pos < %size) && (%pos < $ns.lp.maxpage) && (!%done) {
    bread $qt(%file) %pos 4096 %bv
    %buf = $right(%buf,400) $+ $bvar(%bv,1,4096).text
    inc %pos 4096
    if (%title == $null) && ($regex(lpt,%buf,/<title[^>]*>([^<]{1,400})<\/title>/i)) %title = $regml(lpt,1)
    if (%otitle == $null) %otitle = $ns.lp.meta(%buf,og:title)
    if (%odesc == $null) %odesc = $ns.lp.meta(%buf,og:description)
    if (%desc == $null) %desc = $ns.lp.meta(%buf,description)
    if (%site == $null) %site = $ns.lp.meta(%buf,og:site_name)
    if (%img == $null) %img = $ns.lp.meta(%buf,og:image)
    if ($regex(lph,%buf,/<\/head>/i)) %done = 1
  }
  ns.lp.card title $iif(%otitle,%otitle,%title)
  ns.lp.card desc $iif(%odesc,%odesc,%desc)
  ns.lp.card site %site
  ns.lp.card img %img
  ns.lp.card type %type
  ns.lp.card size %total
  ns.lp.fill
}
; <meta property|name="KEY" content="..."> in either attribute order
alias ns.lp.meta {
  var %t = $1, %k = $2, %re
  %re = $+(/<meta[^>]*?(?:property|name)\s*=\s*["']?,%k,["']?[^>]*?content\s*=\s*(?:"([^"]*)"|'([^']*)')/i)
  if ($regex(lpm,%t,%re)) return $iif($regml(lpm,1) != $null,$regml(lpm,1),$regml(lpm,2))
  %re = $+(/<meta[^>]*?content\s*=\s*(?:"([^"]*)"|'([^']*)')[^>]*?(?:property|name)\s*=\s*["']?,%k,["']?/i)
  if ($regex(lpm,%t,%re)) return $iif($regml(lpm,1) != $null,$regml(lpm,1),$regml(lpm,2))
  return $null
}
; &amp; &lt; &#39; ... -> text, UTF-8 -> characters, whitespace tidied
alias ns.lp.clean {
  var %t = $1-
  if (%t == $null) return $null
  %t = $utfdecode(%t)
  %t = $regsubex(%t,/&#(\d{1,6});/g,$chr(\1))
  %t = $replace(%t,&amp;,&,&lt;,<,&gt;,>,&quot;,$chr(34),&apos;,$chr(39),&nbsp;,$chr(1),&#x27;,$chr(39),&hellip;,...,&mdash;,-,&ndash;,-)
  %t = $regsubex(%t,/\s+/g,$chr(1))
  return $ns.trim($replace(%t,$chr(1),$chr(32)))
}
; ns.lp.card <title|desc|site|img|type|size|url> <value...> collects what is known about a page
alias ns.lp.card hadd -mu600 ns.lpd $1 $2-
; paint the card from ns.lpd
alias ns.lp.fill {
  var %u = $hget(ns.lpd,url), %title = $ns.lp.clean($hget(ns.lpd,title)), %desc = $ns.lp.clean($hget(ns.lpd,desc)), %site = $ns.lp.clean($hget(ns.lpd,site)), %img = $hget(ns.lpd,img), %type = $hget(ns.lpd,type), %size = $hget(ns.lpd,size), %host
  if (!$dialog(ns_lp)) return
  if ($regex(lph,%u,/^https?:\/\/([^\/?#]+)/i)) %host = $regml(lph,1)
  did -ra ns_lp 3 $ns.esc($iif(%title,$left(%title,120),$iif(%host,%host,%u)))
  did -ra ns_lp 4 $ns.esc($iif(%desc,$left(%desc,260),(no description)))
  did -ra ns_lp 5 $ns.esc($iif(%site,%site,%host)) $chr(183) $iif(%type,%type,unknown type) $iif(%size isnum,$chr(183) $bytes(%size,b))
  did -ra ns_lp 6 $ns.esc($left(%ns.lp.final,200))
  ns.lp.status Done.
  if (%img != $null) {
    %img = $ns.lp.abs($ns.lp.clean(%img),%ns.lp.final)
    if (%img != $null) && (!$ns.lp.check(%img)) ns.lp.get thumb %img 0
  }
}
alias ns.lp.reset {
  if ($hget(ns.lpd)) hfree ns.lpd
  ns.lp.card url $1
}
; the og:image arrived: show it small on the card (PNG / JPEG / GIF / BMP only)
alias ns.lp.ext {
  var %t = $1
  if (%t == image/png) return png
  if (%t isin image/jpeg image/jpg) return jpg
  if (%t == image/gif) return gif
  if (%t == image/bmp) return bmp
  return $null
}
; rename the download to <name>.<ext> so it can be displayed; returns the new path
alias ns.lp.named {
  var %f = $1, %e = $ns.lp.ext($2), %n
  if (%e == $null) return %f
  %n = $+(%f,.,%e)
  if ($exists(%n)) .remove $qt(%n)
  .rename -o $qt(%f) $qt(%n)
  return %n
}
alias ns.lp.thumb {
  var %file = $ns.lp.named($1,$2), %type = $2
  if (!$dialog(ns_lp)) return
  if (!$ns.lp.isimg(%type,%file)) return
  if ($file(%file).size < 100) return
  set -u600 %ns.lp.imgfile %file
  did -g ns_lp 2 %file
  did -e ns_lp 10
}
alias ns.lp.isimg {
  var %t = $1, %f = $2
  if (%t isin image/png image/jpeg image/jpg image/gif image/bmp) return 1
  return $iif($right(%f,4) isin .png .jpg .gif .bmp,1,0)
}
; a picture that is the page itself
alias ns.lp.image {
  var %file = $ns.lp.named($1,$2), %type = $2
  if (!$ns.lp.isimg(%type,%file)) {
    ns.lp.status mIRC cannot show this kind of picture ( $+ %type $+ ).
    return
  }
  set -u600 %ns.lp.imgfile %file
  if ($dialog(ns_lp)) {
    did -g ns_lp 2 %file
    did -e ns_lp 10
  }
  ns.lp.showimg %file
}

; ---------------------------------------------------------------- picture window
alias ns.lp.showimg {
  var %f = $1, %w = $pic(%f).width, %h = $pic(%f).height, %mw = 900, %mh = 640, %dw, %dh
  if (!$exists(%f)) || (%w !isnum) || (%h !isnum) || (%w < 1) {
    ns.err the picture could not be read.
    return
  }
  %dw = %w
  %dh = %h
  if (%dw > %mw) {
    %dh = $calc(%dh * %mw / %dw)
    %dw = %mw
  }
  if (%dh > %mh) {
    %dw = $calc(%dw * %mh / %dh)
    %dh = %mh
  }
  %dw = $int(%dw)
  %dh = $int(%dh)
  if ($window(@NeonImage)) window -c @NeonImage
  window -pCdo +ft @NeonImage -1 -1 %dw %dh
  titlebar @NeonImage Picture preview $chr(183) %w x %h
  drawpic -s @NeonImage 0 0 %dw %dh $qt(%f)
}
menu @NeonImage {
  Close:window -c @NeonImage
}

; ---------------------------------------------------------------- cleanup
alias ns.lp.cleanup {
  var %n = $findfile($ns.lp.tmp,lp_*,0,1), %f
  .timer.nslpguard off
  if ($hget(ns.lpq)) hfree ns.lpq
  while (%n > 0) {
    %f = $findfile($ns.lp.tmp,lp_*,1,1)
    if (%f == $null) break
    .remove $qt(%f)
    dec %n
  }
}
on *:EXIT:{ ns.lp.cleanup }
