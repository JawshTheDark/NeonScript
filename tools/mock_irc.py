#!/usr/bin/env python3
"""
Tiny single-purpose IRC server used to test NeonScript end to end on localhost.

    python mock_irc.py [port] [logfile] [more]

Lurker emulation: when a client logs in (SASL authcid or PASS) as a plain "<user>" with no
"/network", the server answers like Lurker does for a client without soju.im/bouncer-networks:
a NOTICE from lurker.bouncer listing the networks.  With the third argument "more" the list is
cut short ("+3 more") and BOUNCER LISTNETWORKS (after CAP REQ soju.im/bouncer-networks) returns all six.

It completes registration, answers WHOIS, and plays a scripted scenario
(join / chat / part / quit / nick / mode / topic / kick / invite) when it sees
"PRIVMSG #chan :scenario".  Everything the client sends is appended to the log
file so tests can assert on it.  Binds to 127.0.0.1 only.
"""
import base64
import os
import socket
import sys
import threading
import time

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 6667
LOG = sys.argv[2] if len(sys.argv) > 2 else "mock.log"
SRV = "mock.neon"
ARGS = sys.argv[3:]
MORE = "more" in ARGS          # Lurker overflow case
QUIET = "quiet" in ARGS        # ircd with a real quiet list mode: CHANMODES=bq,...  (+q <mask>)
EXTBAN = "extban" in ARGS      # ircd with extended bans: EXTBAN=~,q  (+b ~q:<mask>)
NETS = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta"]


def log(line):
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(line.rstrip("\r\n") + "\n")


class Client:
    def __init__(self, conn):
        self.conn = conn
        self.nick = "*"
        self.user = None
        self.registered = False
        self.lock = threading.Lock()
        self.caps = set()
        self.cap_open = False
        self.want_welcome = False
        self.login = None

    def send(self, line):
        with self.lock:
            try:
                self.conn.sendall((line + "\r\n").encode("utf-8"))
                log("> " + line)
            except OSError:
                pass

    def welcome(self):
        n = self.nick
        self.registered = True
        self.send(f":{SRV} 001 {n} :Welcome to the Mock IRC Network {n}!{self.user}@127.0.0.1")
        self.send(f":{SRV} 002 {n} :Your host is {SRV}, running mock-1.0")
        self.send(f":{SRV} 003 {n} :This server was created today")
        self.send(f":{SRV} 004 {n} {SRV} mock-1.0 iow ovmntk")
        cm = "bq,k,l,imnpst" if QUIET else "b,k,l,imnpst"
        extra = " EXTBAN=~,qjn" if EXTBAN else ""
        self.send(f":{SRV} 005 {n} CHANTYPES=# PREFIX=(qaohv)~&@%+ NETWORK=MockNet CHANMODES={cm} "
                  f"MODES=4 TOPICLEN=120 NICKLEN=30 CASEMAPPING=rfc1459{extra} :are supported by this server")
        self.send(f":{SRV} 375 {n} :- {SRV} Message of the Day -")
        self.send(f":{SRV} 372 {n} :- Welcome to the NeonScript test network.")
        self.send(f":{SRV} 376 {n} :End of /MOTD command.")
        login = (self.login or "").split(":")[0]
        if login and "/" not in login and "@" not in login:
            user = login
            if MORE:
                lst = ", ".join(NETS[:3]) + ", +3 more"
            else:
                lst = ", ".join(NETS[:3])
            self.send(f":lurker.bouncer NOTICE {n} :Not attached to a network \u2014 log in as {user}/<network> "
                      f"to attach. Available: {lst}")

    def scenario(self, chan):
        me = self.nick
        steps = [
            (f":Nova!nova@host.example JOIN {chan}", 0.25),
            (f":Nova!nova@host.example PRIVMSG {chan} :hey everyone, nice to be here", 0.25),
            (f":Kira!kira@10.0.0.2 PRIVMSG {chan} :hello Nova, welcome!", 0.25),
            (f":Owner!own@owner.example PRIVMSG {chan} :behave, folks", 0.25),
            (f":Kira!kira@10.0.0.2 NICK :Kira2", 0.25),
            (f":Owner!own@owner.example MODE {chan} +q Nova", 0.25),
            (f":Owner!own@owner.example MODE {chan} +a Kira2", 0.25),
            (f":ChanServ!cs@services.mock MODE {chan} +o Nova", 0.25),
            (f":Admin!adm@admin.example MODE {chan} +h Zed", 0.25),
            (f":Admin!adm@admin.example MODE {chan} -v Zed", 0.25),
            (f":Kira2!kira@10.0.0.2 MODE {chan} +ov Half Nova", 0.25),
            (f":Nova!nova@host.example MODE {chan} +b *!*@bad.host.example", 0.25),
            (f":Nova!nova@host.example MODE {chan} +k s3cret", 0.25),
            (f":Nova!nova@host.example MODE {chan} +l 50", 0.25),
            (f":Nova!nova@host.example MODE {chan} +nt", 0.25),
            (f":Nova!nova@host.example TOPIC {chan} :Welcome to NeonScript, the 2026 remaster!", 0.25),
            (f":Half!half@half.example PART {chan} :gotta run, bye", 0.25),
            (f":Owner!own@owner.example KICK {chan} Kira2 :behave yourself", 0.25),
            (f":Nova!nova@host.example INVITE {me} #secret", 0.25),
            (f":Ghost!ghost@gone.example JOIN {chan}", 0.25),
            (f":Ghost!ghost@gone.example QUIT :Ping timeout: 240 seconds", 0.25),
            (f":Nova!nova@host.example PRIVMSG {chan} :{me}: thanks for testing", 0.25),
            (f":Nova!nova@host.example PRIVMSG {chan} :\x01ACTION raises a glass\x01", 0.25),
            (f":Admin!adm@admin.example NOTICE {chan} :maintenance at midnight", 0.25),
            (f":Nova!nova@host.example PRIVMSG {chan} :!roll 2d6", 0.3),
            (f":Kira!kira@10.0.0.2 PRIVMSG {chan} :!ops", 0.3),
            (f":Owner!own@owner.example PRIVMSG {chan} :!rank Admin", 0.3),
            (f":Admin!adm@admin.example PRIVMSG {chan} :!seen Ghost", 0.3),
            (f":Nova!nova@host.example MODE {chan} -nt", 1.2),
            (f":Nova!nova@host.example TOPIC {chan} :Nova hijacked the topic", 1.2),
        ]
        for line, delay in steps:
            self.send(line)
            time.sleep(delay)

    def replay(self, chan):
        me = self.nick
        tagged = "server-time" in self.caps
        def t(ts):
            return f"@time={ts} " if tagged else ""
        steps = [
            (t("2026-09-30T08:00:00.000Z") + f":Nova!nova@host.example PRIVMSG {chan} :(replayed) good morning everyone", 0.3),
            (t("2026-09-30T08:01:00.000Z") + f":Kira!kira@10.0.0.2 PRIVMSG {chan} :(replayed) {me}: you around?", 0.3),
            (t("2026-09-30T08:02:00.000Z") + f":Nova!nova@host.example PRIVMSG {chan} :\x01ACTION (replayed) waves\x01", 0.3),
            (t("2026-09-30T08:03:00.000Z") + f":Replayer!rp@replay.example JOIN {chan}", 0.5),
            (f":Replayer!rp@replay.example JOIN {chan}", 0.5),
        ]
        for line, delay in steps:
            self.send(line)
            time.sleep(delay)

    def tags(self, chan):
        """IRCv3 message-tags: a message with a msgid, a reply to it, a reaction, then away-notify."""
        tagged = "message-tags" in self.caps
        def t(tags):
            return f"@{tags} " if tagged else ""
        steps = [
            (t("msgid=m1") + f":Nova!nova@host.example PRIVMSG {chan} :the build is green again", 1.1),
            (t("msgid=m2;+draft/reply=m1") + f":Kira!kira@10.0.0.2 PRIVMSG {chan} :nice, which commit fixed it?", 1.1),
            (t("+draft/react=\U0001F44D;+draft/reply=m1") + f":Owner!own@owner.example TAGMSG {chan}", 1.1),
            (":Admin!adm@admin.example AWAY :gone fishing", 0.6),
        ]
        for line, delay in steps:
            self.send(line)
            time.sleep(delay)

    def pm(self):
        me = self.nick
        self.send(":Admin!adm@admin.example AWAY")
        time.sleep(0.4)
        self.send(f":Nova!nova@host.example PRIVMSG {me} :hey {me}, got a minute?")
        time.sleep(0.4)
        self.send(f":Kira!kira@10.0.0.2 PRIVMSG #neon :{me}: your build is ready")

    def ctcp(self):
        """CTCP requests from a channel member (Nova) and from a stranger."""
        me = self.nick
        steps = [
            (f":Nova!nova@host.example PRIVMSG {me} :\x01VERSION\x01", 1.1),
            (f":Nova!nova@host.example PRIVMSG {me} :\x01TIME\x01", 1.1),
            (f":Nova!nova@host.example PRIVMSG {me} :\x01FINGER\x01", 1.1),
            (f":Stranger!str@far.example PRIVMSG {me} :\x01VERSION\x01", 1.1),
            (f":Stranger!str@far.example PRIVMSG {me} :\x01USERINFO\x01", 1.1),
            (f":Nova!nova@host.example PRIVMSG {me} :\x01PING 12345\x01", 1.1),
        ]
        for line, delay in steps:
            self.send(line)
            time.sleep(delay)

    def talk(self, chan):
        """Channel chatter from several nicks (stats counters, ignore tests)."""
        rows = [("Nova", "nova@host.example", "hello world this is a test"), ("Nova", "nova@host.example", "second line from nova"),
                ("Kira", "kira@10.0.0.2", "kira here"), ("Spammer", "sp@spam.example", "buy cheap stuff now"),
                ("Nova", "nova@host.example", "third nova line"), ("Spammer", "sp@spam.example", "visit my site"),
                ("Owner", "own@owner.example", "behave")]
        for nk, host, text in rows:
            self.send(f":{nk}!{host} PRIVMSG {chan} :{text}")
            time.sleep(0.2)
        self.send(f":Spammer!sp@spam.example NOTICE {self.nick} :private spam notice")
        self.send(f":Spammer!sp@spam.example PRIVMSG {self.nick} :private spam message")
        self.send(f":Spammer!sp@spam.example INVITE {self.nick} #spamchan")

    def whois(self, target):
        n = self.nick
        self.send(f":{SRV} 311 {n} {target} nova host.example * :Nova Example")
        self.send(f":{SRV} 312 {n} {target} {SRV} :The Mock Network")
        self.send(f":{SRV} 317 {n} {target} 125 {int(time.time()) - 86400} :seconds idle, signon time")
        self.send(f":{SRV} 319 {n} {target} :~#neon &#ops @#dev %#help +#chat #lounge")
        self.send(f":{SRV} 330 {n} {target} novaaccount :is logged in as")
        self.send(f":{SRV} 671 {n} {target} :is using a secure connection")
        self.send(f":{SRV} 318 {n} {target} :End of /WHOIS list.")

    def handle(self, line):
        log("< " + line)
        parts = line.split(" ")
        cmd = parts[0].upper()
        if cmd == "CAP":
            sub = parts[1].upper() if len(parts) > 1 else ""
            if sub == "LS":
                self.cap_open = True
                self.send(f":{SRV} CAP * LS :sasl=PLAIN server-time znc.in/server-time-iso soju.im/bouncer-networks message-tags away-notify")
            elif sub == "REQ":
                req = " ".join(parts[2:]).lstrip(":")
                self.caps.update(req.split())
                self.send(f":{SRV} CAP * ACK :{req}")
            elif sub == "END":
                self.cap_open = False
                if self.want_welcome and not self.registered:
                    self.welcome()
        elif cmd == "AUTHENTICATE":
            arg = parts[1] if len(parts) > 1 else ""
            if arg.upper() == "PLAIN":
                self.send("AUTHENTICATE +")
            elif arg != "+":
                try:
                    raw = base64.b64decode(arg + "=" * (-len(arg) % 4)).split(b"\0")
                    log(f"# SASL authzid={raw[0].decode()!r} authcid={raw[1].decode()!r} pass={raw[2].decode()!r}")
                    self.login = raw[1].decode()
                except Exception as e:
                    log(f"# SASL decode error {e}")
                self.send(f":{SRV} 900 {self.nick} {self.nick}!x@127.0.0.1 acct :You are now logged in")
                self.send(f":{SRV} 903 {self.nick} :SASL authentication successful")
        elif cmd == "PASS":
            log("# PASS " + " ".join(parts[1:]))
            if self.login is None:
                self.login = " ".join(parts[1:]).lstrip(":")
        elif cmd == "NICK":
            self.nick = parts[1].lstrip(":")
            if self.user and not self.registered:
                if self.cap_open:
                    self.want_welcome = True
                else:
                    self.welcome()
        elif cmd == "USER":
            self.user = parts[1]
            if self.nick != "*" and not self.registered:
                if self.cap_open:
                    self.want_welcome = True
                else:
                    self.welcome()
        elif cmd == "PING":
            self.send(f":{SRV} PONG {SRV} {' '.join(parts[1:])}")
        elif cmd == "JOIN":
            chan = parts[1].lstrip(":").split(",")[0]
            n = self.nick
            self.send(f":{n}!{self.user}@127.0.0.1 JOIN {chan}")
            self.send(f":{SRV} 332 {n} {chan} :Mock topic for {chan}")
            self.send(f":{SRV} 353 {n} = {chan} :@{n} ~Owner &Admin @Kira %Half +Zed Nova Clone1 Clone2")
            self.send(f":{SRV} 366 {n} {chan} :End of /NAMES list.")
        elif cmd == "MODE" and len(parts) >= 2 and parts[1].startswith("#") and len(parts) == 2:
            n = self.nick
            self.send(f":{SRV} 324 {n} {parts[1]} +nt")
            self.send(f":{SRV} 329 {n} {parts[1]} 1700000000")
        elif cmd == "MODE" and len(parts) == 3 and parts[2] in ("+b", "b"):
            n = self.nick
            self.send(f":{SRV} 367 {n} {parts[1]} *!*@bad.host.example Nova 1790000000")
            self.send(f":{SRV} 367 {n} {parts[1]} *!*@spam.example Owner 1790000100")
            self.send(f":{SRV} 368 {n} {parts[1]} :End of channel ban list")
        elif cmd == "MODE" and len(parts) >= 3 and parts[1].startswith("#") and parts[2][:1] in "+-" \
                and (len(parts) >= 4 or not parts[2].lstrip("+-") in ("b", "e", "I", "q")):
            # channel mode change from the client: echo it back like a real server, except +S which
            # we refuse (482) so the client's error handling can be tested
            n = self.nick
            if "S" in parts[2]:
                self.send(f":{SRV} 482 {n} {parts[1]} :You're not channel operator")
            else:
                self.send(f":{n}!{self.user}@127.0.0.1 MODE {parts[1]} {' '.join(parts[2:])}")
        elif cmd == "KICK" and len(parts) >= 3:
            n = self.nick
            reason = " ".join(parts[3:]).lstrip(":") or n
            for victim in parts[2].split(","):
                self.send(f":{n}!{self.user}@127.0.0.1 KICK {parts[1]} {victim} :{reason}")
        elif cmd == "TOPIC" and len(parts) >= 3:
            self.send(f":{self.nick}!{self.user}@127.0.0.1 TOPIC {parts[1]} :{' '.join(parts[2:]).lstrip(':')}")
        elif cmd == "WHO" and len(parts) >= 2:
            n = self.nick
            ch = parts[1]
            rows = [("Owner", "own", "owner.example"), ("Admin", "adm", "admin.example"), ("Kira", "kira", "10.0.0.2"),
                    ("Half", "half", "half.example"), ("Zed", "zed", "zed.example"), ("Nova", "nova", "host.example"),
                    ("Clone1", "cl", "clone.example"), ("Clone2", "cl", "clone.example"), (n, "me", "127.0.0.1")]
            for nk, us, ho in rows:
                flag = "G" if nk == "Zed" else "H"
                self.send(f":{SRV} 352 {n} {ch} {us} {ho} {SRV} {nk} {flag} :0 {nk}")
            self.send(f":{SRV} 315 {n} {ch} :End of /WHO list.")
        elif cmd == "WHOIS":
            self.whois(parts[-1])
        elif cmd == "PRIVMSG" and len(parts) > 2:
            text = " ".join(parts[2:]).lstrip(":")
            if text.strip().lower() == "replay":
                threading.Thread(target=self.replay, args=(parts[1],), daemon=True).start()
            if text.strip().lower() in ("scenario", "scenario2"):
                threading.Thread(target=self.scenario, args=(parts[1],), daemon=True).start()
            if text.strip().lower() == "tags":
                threading.Thread(target=self.tags, args=(parts[1],), daemon=True).start()
            if text.strip().lower() == "pm":
                threading.Thread(target=self.pm, daemon=True).start()
            if text.strip().lower() == "ctcp":
                threading.Thread(target=self.ctcp, daemon=True).start()
            if text.strip().lower() == "talk":
                threading.Thread(target=self.talk, args=(parts[1],), daemon=True).start()
        elif cmd == "AWAY":
            if len(parts) > 1:
                self.send(f":{SRV} 306 {self.nick} :You have been marked as being away")
            else:
                self.send(f":{SRV} 305 {self.nick} :You are no longer marked as being away")
        elif cmd == "BOUNCER" and len(parts) > 1 and parts[1].upper() == "LISTNETWORKS":
            if "soju.im/bouncer-networks" in self.caps:
                for i, name in enumerate(NETS, 1):
                    self.send(f":lurker.bouncer BOUNCER NETWORK {i} name={name};state=connected")
            else:
                self.send(f":lurker.bouncer FAIL BOUNCER NEED_CAP :soju.im/bouncer-networks not negotiated")
        elif cmd == "QUIT":
            self.send(f"ERROR :Closing Link: 127.0.0.1 (Client Quit)")
            return False
        return True


def serve(conn):
    c = Client(conn)
    buf = b""
    try:
        while True:
            data = conn.recv(4096)
            if not data:
                break
            buf += data
            while b"\n" in buf:
                raw, buf = buf.split(b"\n", 1)
                line = raw.decode("utf-8", "replace").rstrip("\r")
                if line and not c.handle(line):
                    return
    except OSError:
        pass
    finally:
        conn.close()
        log("# client closed")


def main():
    open(LOG, "w").close()
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", PORT))
    srv.listen(4)
    log(f"# mock IRC listening on 127.0.0.1:{PORT}")
    while True:
        conn, _ = srv.accept()
        log("# client connected")
        threading.Thread(target=serve, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
