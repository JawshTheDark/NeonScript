[mts]
MTSVersion 1.10
Name Irssi Night
Author NeonScript
Description An irssi-inspired dark theme, shipped as a working example of the MTS format.
Colors 1,13,12,8,14,14,11,9,4,8,12,15,13,7,14,11,6,5,10,13,12,1,15,1,15,14
RGBColors 255,255,255 0,0,0 40,60,200 40,170,60 230,60,60 150,40,40 160,60,170 230,150,40 240,220,80 90,230,90 40,170,170 90,230,230 90,110,255 240,100,240 100,100,100 190,190,190
BaseColors 15,12,8,14
FontDefault Consolas, 11
Prefix -!-
; --- chat
TextChan <c4><lt><o><c3><cmode><o><c2><nick><o><c4><gt><o> <text>
ActionChan <c4> * <o><c2><nick><o> <text>
NoticeChan <c4>-<o><c2><nick><o><c4>:<chan>-<o> <text>
TextQuery <c4>[<o><c2><nick><o><c4>]<o> <text>
ActionQuery <c4> * <o><c2><nick><o> <text>
; --- events
Join <c4><pre><o> <c2><nick><o> <c4>[<o><address><c4>]<o> has joined <chan>
JoinSelf <c4><pre><o> Now talking in <b><chan><o>
Part <c4><pre><o> <c2><nick><o> <c4>[<o><address><c4>]<o> has left <chan> <parentext>
Quit <c4><pre><o> <c2><nick><o> <c4>[<o><address><c4>]<o> has quit <parentext>
Kick <c4><pre><o> <c2><knick><o> was kicked from <chan> by <c2><nick><o> <parentext>
KickSelf <c4><pre><o> You were kicked from <chan> by <c2><nick><o> <parentext>
Nick <c4><pre><o> <c2><nick><o> is now known as <c3><newnick><o>
NickSelf <c4><pre><o> You are now known as <c3><newnick><o>
Mode <c4><pre><o> mode/<chan> <c4>[<o><modes><c4>]<o> by <c2><nick><o>
Topic <c4><pre><o> <c2><nick><o> changed the topic of <chan> to: <text>
Invite <c4><pre><o> <c2><nick><o> invites you to <b><chan><o>
; --- whois
RAW.311 <c4><pre><o> <c2><nick><o> <c4>[<o><address><c4>]<o>
RAW.312 <c4><pre><o> server  : <wserver> <c4>[<o><serverinfo><c4>]<o>
RAW.317 <c4><pre><o> idle    : <idletime> <c4>(signon: <signontime>)<o>
RAW.319 <c4><pre><o> channels: <users>
RAW.301 <c4><pre><o> away    : <away>
RAW.318 <c4><pre><o> End of WHOIS
