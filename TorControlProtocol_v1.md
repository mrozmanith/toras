For the authoritative Tor control protocol specification document, please visit: https://gitweb.torproject.org/torspec.git?a=blob_plain;hb=HEAD;f=control-spec.txt

# TC: A Tor control protocol (Version 1) #

0. Scope

> This document describes an implementation-specific protocol that is used
> for other programs (such as frontend user-interfaces) to communicate with a
> locally running Tor process.  It is not part of the Tor onion routing
> protocol.

> This protocol replaces version 0 of TC, which is now deprecated.  For
> reference, TC is described in "control-spec-v0.txt".  Implementors are
> recommended to avoid using TC directly, but instead to use a library that
> can easily be updated to use the newer protocol.  (Version 0 is used by Tor
> versions 0.1.0.x; the protocol in this document only works with Tor
> versions in the 0.1.1.x series and later.)

> The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL
> NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED",  "MAY", and
> "OPTIONAL" in this document are to be interpreted as described in
> RFC 2119.

1. Protocol outline

> TC is a bidirectional message-based protocol.  It assumes an underlying
> stream for communication between a controlling process (the "client"
> or "controller") and a Tor process (or "server").  The stream may be
> implemented via TCP, TLS-over-TCP, a Unix-domain socket, or so on,
> but it must provide reliable in-order delivery.  For security, the
> stream should not be accessible by untrusted parties.

> In TC, the client and server send typed messages to each other over the
> underlying stream.  The client sends "commands" and the server sends
> "replies".

> By default, all messages from the server are in response to messages from
> the client.  Some client requests, however, will cause the server to send
> messages to the client indefinitely far into the future.  Such
> "asynchronous" replies are marked as such.

> Servers respond to messages in the order messages are received.

1.1. Forward-compatibility

> This is an evolving protocol; new client and server behavior will be
> allowed in future versions.  To allow new backward-compatible client
> on behalf of the client, we may add new commands and allow existing
> commands to take new arguments in future versions.  To allow new
> backward-compatible server behavior, we note various places below
> where servers speaking a future versions of this protocol may insert
> new data, and note that clients should/must "tolerate" unexpected
> elements in these places.  There are two ways that we do this:

  * Adding a new field to a message:

> For example, we might say "This message has three space-separated
> fields; clients MUST tolerate more fields."  This means that a
> client MUST NOT crash or otherwise fail to parse the message or
> other subsequent messages when there are more than three fields, and
> that it SHOULD function at least as well when more fields are
> provided as it does when it only gets the fields it accepts.  The
> most obvious way to do this is by ignoring additional fields; the
> next-most-obvious way is to report additional fields verbatim to the
> user, perhaps as part of an expert UI.

  * Adding a new possible value to a list of alternatives:

> For example, we might say "This field will be OPEN, CLOSED, or
> CONNECTED.  Clients MUST tolerate unexpected values."  This means
> that a client MUST NOT crash or otherwise fail to parse the message
> or other subsequent when there are unexpected values, and that the
> client SHOULD try to handle the rest of the message as well as it
> can.  The most obvious way to do this is by pretending that each
> list of alternatives has an additional "unrecognized value" element,
> and mapping any unrecognized values to that element; the
> next-most-obvious way is to create a separate "unrecognized value"
> element for each unrecognized value.

> Clients SHOULD NOT "tolerate" unrecognized alternatives by
> pretending that the message containing them is absent.  For example,
> a stream closed for an unrecognized reason is nevertheless closed,
> and should be reported as such.

> (If some list of alternatives is given, and there isn't an explicit
> statement that clients must tolerate unexpected values, clients still
> must tolerate unexpected values. The only exception would be if there
> were an explicit statement that no future values will ever be added.)

2. Message format

2.1. Description format

> The message formats listed below use ABNF as described in RFC 2234.
> The protocol itself is loosely based on SMTP (see RFC 2821).

> We use the following nonterminals from RFC 2822: atom, qcontent

> We define the following general-use nonterminals:

> QuotedString = DQUOTE **qcontent DQUOTE**

> There are explicitly no limits on line length.  All 8-bit characters
> are permitted unless explicitly disallowed.  In QuotedStrings,
> backslashes and quotes must be escaped; other characters need not be
> escaped.

> Wherever CRLF is specified to be accepted from the controller, Tor MAY also
> accept LF.  Tor, however, MUST NOT generate LF instead of CRLF.
> Controllers SHOULD always send CRLF.

2.2. Commands from controller to Tor

> Command = Keyword OptArguments CRLF / "+" Keyword OptArguments CRLF CmdData
> Keyword = 1\*ALPHA
> OptArguments = [SP \*(SP / VCHAR) ](.md)

> A command is either a single line containing a Keyword and arguments, or a
> multiline command whose initial keyword begins with +, and whose data
> section ends with a single "." on a line of its own.  (We use a special
> character to distinguish multiline commands so that Tor can correctly parse
> multi-line commands that it does not recognize.) Specific commands and
> their arguments are described below in section 3.

2.3. Replies from Tor to the controller

> Reply = SyncReply / AsyncReply
> SyncReply = **(MidReplyLine / DataReplyLine) EndReplyLine
> AsyncReply =**(MidReplyLine / DataReplyLine) EndReplyLine

> MidReplyLine = StatusCode "-" ReplyLine
> DataReplyLine = StatusCode "+" ReplyLine CmdData
> EndReplyLine = StatusCode SP ReplyLine
> ReplyLine = [ReplyText](ReplyText.md) CRLF
> ReplyText = XXXX
> StatusCode = 3DIGIT

> Specific replies are mentioned below in section 3, and described more fully
> in section 4.

> [Compatibility note:  versions of Tor before 0.2.0.3-alpha sometimes
> generate AsyncReplies of the form "**(MidReplyLine / DataReplyLine)".
> This is incorrect, but controllers that need to work with these
> versions of Tor should be prepared to get multi-line AsyncReplies with
> the final line (usually "650 OK") omitted.]**

2.4. General-use tokens

> ; CRLF means, "the ASCII Carriage Return character (decimal value 13)
> ; followed by the ASCII Linefeed character (decimal value 10)."
> CRLF = CR LF

> ; How a controller tells Tor about a particular OR.  There are four
> ; possible formats:
> ;    $Fingerprint -- The router whose identity key hashes to the fingerprint.
> ;        This is the preferred way to refer to an OR.
> ;    $Fingerprint~Nickname -- The router whose identity key hashes to the
> ;        given fingerprint, but only if the router has the given nickname.
> ;    $Fingerprint=Nickname -- The router whose identity key hashes to the
> ;        given fingerprint, but only if the router is Named and has the given
> ;        nickname.
> ;    Nickname -- The Named router with the given nickname, or, if no such
> ;        router exists, any router whose nickname matches the one given.
> ;        This is not a safe way to refer to routers, since Named status
> ;        could under some circumstances change over time.
> ;
> ; The tokens that implement the above follow:

> ServerSpec = LongName / Nickname
> LongName   = Fingerprint [( "=" / "~" ) Nickname ](.md)

> Fingerprint = "$" 40\*HEXDIG
> NicknameChar = "a"-"z" / "A"-"Z" / "0" - "9"
> Nickname = 1\*19 NicknameChar

> ; What follows is an outdated way to refer to ORs.
> ; Feature VERBOSE\_NAMES replaces ServerID with LongName in events and
> ; GETINFO results. VERBOSE\_NAMES can be enabled starting in Tor version
> ; 0.1.2.2-alpha and it is always-on in 0.2.2.1-alpha and later.
> ServerID = Nickname / Fingerprint


> ; Unique identifiers for streams or circuits.  Currently, Tor only
> ; uses digits, but this may change
> StreamID = 1\*16 IDChar
> CircuitID = 1\*16 IDChar
> ConnID = 1\*16 IDChar
> QueueID = 1\*16 IDChar
> IDChar = ALPHA / DIGIT

> Address = ip4-address / ip6-address / hostname   (XXXX Define these)

> ; A "CmdData" section is a sequence of octets concluded by the terminating
> ; sequence CRLF "." CRLF.  The terminating sequence may not appear in the
> ; body of the data.  Leading periods on lines in the data are escaped with
> ; an additional leading period as in RFC 2821 section 4.5.2.
> CmdData = **DataLine "." CRLF
> DataLine = CRLF / "." 1\*LineItem CRLF / NonDotItem**LineItem CRLF
> LineItem = NonCR / 1\*CR NonCRLF
> NonDotItem = NonDotCR / 1\*CR NonCRLF

> ; ISOTime, ISOTime2, and ISOTime2Frac are time formats as specified in
> ; ISO8601.
> ;  example ISOTime:      "2012-01-11 12:15:33"
> ;  example ISOTime2:     "2012-01-11T12:15:33"
> ;  example ISOTime2Frac: "2012-01-11T12:15:33.51"
> IsoDatePart = 4\*DIGIT "-" 2\*DIGIT "-" 2\*DIGIT
> IsoTimePart = 2\*DIGIT ":" 2\*DIGIT ":" 2\*DIGIT
> ISOTime  = IsoDatePart " " IsoTimePart
> ISOTime2 = IsoDatePart "T" IsoTimePart
> ISOTime2Frac = IsoTime2 ["." 1\*DIGIT ](.md)

3. Commands

> All commands are case-insensitive, but most keywords are case-sensitive.

3.1. SETCONF

> Change the value of one or more configuration variables.  The syntax is:

> "SETCONF" 1**(SP keyword ["=" value]) CRLF
> value = String / QuotedString**

> Tor behaves as though it had just read each of the key-value pairs
> from its configuration file.  Keywords with no corresponding values have
> their configuration values reset to 0 or NULL (use RESETCONF if you want
> to set it back to its default).  SETCONF is all-or-nothing: if there
> is an error in any of the configuration settings, Tor sets none of them.

> Tor responds with a "250 configuration values set" reply on success.
> If some of the listed keywords can't be found, Tor replies with a
> "552 Unrecognized option" message. Otherwise, Tor responds with a
> "513 syntax error in configuration values" reply on syntax error, or a
> "553 impossible configuration setting" reply on a semantic error.

> Some configuration options (e.g. "Bridge") take multiple values. Also,
> some configuration keys (e.g. for hidden services and for entry
> guard lists) form a context-sensitive group where order matters (see
> GETCONF below). In these cases, setting _any_ of the options in a
> SETCONF command is taken to reset all of the others. For example,
> if two ORListenAddress values are configured, and a SETCONF command
> arrives containing a single ORListenAddress value, the new command's
> value replaces the two old values.

> Sometimes it is not possible to change configuration options solely by
> issuing a series of SETCONF commands, because the value of one of the
> configuration options depends on the value of another which has not yet
> been set. Such situations can be overcome by setting multiple configuration
> options with a single SETCONF command (e.g. SETCONF ORPort=443
> ORListenAddress=9001).

3.2. RESETCONF

> Remove all settings for a given configuration option entirely, assign
> its default value (if any), and then assign the String provided.
> Typically the String is left empty, to simply set an option back to
> its default. The syntax is:

> "RESETCONF" 1**(SP keyword ["=" String]) CRLF**

> Otherwise it behaves like SETCONF above.

3.3. GETCONF

> Request the value of a configuration variable.  The syntax is:

> "GETCONF" 1**(SP keyword) CRLF**

> If all of the listed keywords exist in the Tor configuration, Tor replies
> with a series of reply lines of the form:
> > 250 keyword=value

> If any option is set to a 'default' value semantically different from an
> empty string, Tor may reply with a reply line of the form:
> > 250 keyword


> Value may be a raw value or a quoted string.  Tor will try to use unquoted
> values except when the value could be misinterpreted through not being
> quoted. (Right now, Tor supports no such misinterpretable values for
> configuration options.)

> If some of the listed keywords can't be found, Tor replies with a
> "552 unknown configuration keyword" message.

> If an option appears multiple times in the configuration, all of its
> key-value pairs are returned in order.

> Some options are context-sensitive, and depend on other options with
> different keywords.  These cannot be fetched directly.  Currently there
> is only one such option: clients should use the "HiddenServiceOptions"
> virtual keyword to get all HiddenServiceDir, HiddenServicePort,
> HiddenServiceVersion, and HiddenserviceAuthorizeClient option settings.

3.4. SETEVENTS

> Request the server to inform the client about interesting events.  The
> syntax is:

> "SETEVENTS" ["EXTENDED"](SP.md) **(SP EventCode) CRLF**

> EventCode = 1_(ALPHA / "**")  (see section 4.1.x for event types)**

> Any events **not** listed in the SETEVENTS line are turned off; thus, sending
> SETEVENTS with an empty body turns off all event reporting._

> The server responds with a "250 OK" reply on success, and a "552
> Unrecognized event" reply if one of the event codes isn't recognized.  (On
> error, the list of active event codes isn't changed.)

> If the flag string "EXTENDED" is provided, Tor may provide extra
> information with events for this connection; see 4.1 for more information.
> NOTE: All events on a given connection will be provided in extended format,
> or none.
> NOTE: "EXTENDED" was first supported in Tor 0.1.1.9-alpha; it is
> always-on in Tor 0.2.2.1-alpha and later.

> Each event is described in more detail in Section 4.1.

3.5. AUTHENTICATE

> Sent from the client to the server.  The syntax is:
> > "AUTHENTICATE" [SP 1\*HEXDIG / QuotedString ](.md) CRLF


> The server responds with "250 OK" on success or "515 Bad authentication" if
> the authentication cookie is incorrect.  Tor closes the connection on an
> authentication failure.

> The authentication token can be specified as either a quoted ASCII string,
> or as an unquoted hexadecimal encoding of that same string (to avoid escaping
> issues).

> For information on how the implementation securely stores authentication
> information on disk, see section 5.1.

> Before the client has authenticated, no command other than
> PROTOCOLINFO, AUTHCHALLENGE, AUTHENTICATE, or QUIT is valid.  If the
> controller sends any other command, or sends a malformed command, or
> sends an unsuccessful AUTHENTICATE command, or sends PROTOCOLINFO or
> AUTHCHALLENGE more than once, Tor sends an error reply and closes
> the connection.

> To prevent some cross-protocol attacks, the AUTHENTICATE command is still
> required even if all authentication methods in Tor are disabled.  In this
> case, the controller should just send "AUTHENTICATE" CRLF.

> (Versions of Tor before 0.1.2.16 and 0.2.0.4-alpha did not close the
> connection after an authentication failure.)

3.6. SAVECONF

> Sent from the client to the server.  The syntax is:
> > "SAVECONF" CRLF


> Instructs the server to write out its config options into its torrc. Server
> returns "250 OK" if successful, or "551 Unable to write configuration
> to disk" if it can't write the file or some other error occurs.

> See also the "getinfo config-text" command, if the controller wants
> to write the torrc file itself.

3.7. SIGNAL

> Sent from the client to the server. The syntax is:

> "SIGNAL" SP Signal CRLF

> Signal = "RELOAD" / "SHUTDOWN" / "DUMP" / "DEBUG" / "HALT" /
> > "HUP" / "INT" / "USR1" / "USR2" / "TERM" / "NEWNYM" /
> > "CLEARDNSCACHE"


> The meaning of the signals are:

> RELOAD    -- Reload: reload config items. (like HUP)
> SHUTDOWN  -- Controlled shutdown: if server is an OP, exit immediately.
> > If it's an OR, close listeners and exit after
> > ShutdownWaitLength seconds. (like INT)

> DUMP      -- Dump stats: log information about open connections and
> > circuits. (like USR1)

> DEBUG     -- Debug: switch all open logs to loglevel debug. (like USR2)
> HALT      -- Immediate shutdown: clean up and exit now. (like TERM)
> CLEARDNSCACHE -- Forget the client-side cached IPs for all hostnames.
> NEWNYM    -- Switch to clean circuits, so new application requests
> > don't share any circuits with old ones.  Also clears
> > the client-side DNS cache.  (Tor MAY rate-limit its
> > response to this signal.)


> The server responds with "250 OK" if the signal is recognized (or simply
> closes the socket if it was asked to close immediately), or "552
> Unrecognized signal" if the signal is unrecognized.

3.8. MAPADDRESS

> Sent from the client to the server.  The syntax is:

> "MAPADDRESS" 1**(Address "=" Address SP) CRLF**

> The first address in each pair is an "original" address; the second is a
> "replacement" address.  The client sends this message to the server in
> order to tell it that future SOCKS requests for connections to the original
> address should be replaced with connections to the specified replacement
> address.  If the addresses are well-formed, and the server is able to
> fulfill the request, the server replies with a 250 message:
> > 250-OldAddress1=NewAddress1
> > 250 OldAddress2=NewAddress2


> containing the source and destination addresses.  If request is
> malformed, the server replies with "512 syntax error in command
> argument".  If the server can't fulfill the request, it replies with
> "451 resource exhausted".

> The client may decline to provide a body for the original address, and
> instead send a special null address ("0.0.0.0" for IPv4, "::0" for IPv6, or
> "." for hostname), signifying that the server should choose the original
> address itself, and return that address in the reply.  The server
> should ensure that it returns an element of address space that is unlikely
> to be in actual use.  If there is already an address mapped to the
> destination address, the server may reuse that mapping.

> If the original address is already mapped to a different address, the old
> mapping is removed.  If the original address and the destination address
> are the same, the server removes any mapping in place for the original
> address.

> Example:
> > C: MAPADDRESS 0.0.0.0=torproject.org 1.2.3.4=tor.freehaven.net
> > S: 250-127.192.10.10=torproject.org
> > S: 250 1.2.3.4=tor.freehaven.net


> {Note: This feature is designed to be used to help Tor-ify applications
> that need to use SOCKS4 or hostname-less SOCKS5.  There are three
> approaches to doing this:
    1. Somehow make them use SOCKS4a or SOCKS5-with-hostnames instead.
> > 2. Use tor-resolve (or another interface to Tor's resolve-over-SOCKS
> > > feature) to resolve the hostname remotely.  This doesn't work
> > > with special addresses like x.onion or x.y.exit.

> > 3. Use MAPADDRESS to map an IP address to the desired hostname, and then
> > > arrange to fool the application into thinking that the hostname
> > > has resolved to that IP.

> This functionality is designed to help implement the 3rd approach.}

> Mappings set by the controller last until the Tor process exits:
> they never expire. If the controller wants the mapping to last only
> a certain time, then it must explicitly un-map the address when that
> time has elapsed.

3.9. GETINFO

> Sent from the client to the server.  The syntax is as for GETCONF:
> > "GETINFO" 1**(SP keyword) CRLF

> one or more NL-terminated strings.  The server replies with an INFOVALUE
> message, or a 551 or 552 error.**

> Unlike GETCONF, this message is used for data that are not stored in the Tor
> configuration file, and that may be longer than a single line.  On success,
> one ReplyLine is sent for each requested value, followed by a final 250 OK
> ReplyLine.  If a value fits on a single line, the format is:
> > 250-keyword=value

> If a value must be split over multiple lines, the format is:
> > 250+keyword=
> > value
> > .

> Recognized keys and their values include:

> "version" -- The version of the server's software, including the name
> > of the software. (example: "Tor 0.0.9.4")


> "config-file" -- The location of Tor's configuration file ("torrc").

> "config-defaults-file" -- The location of Tor's configuration
> > defaults file ("torrc.defaults").  This file gets parsed before
> > torrc, and is typically used to replace Tor's default
> > configuration values. [implemented in 0.2.3.9-alpha.](First.md)


> "config-text" -- The contents that Tor would write if you send it
> > a SAVECONF command, so the controller can write the file to
> > disk itself. [implemented in 0.2.2.7-alpha.](First.md)


> ["exit-policy/prepend" -- The default exit policy lines that Tor will
    * repend**to the ExitPolicy config option.
> > -- Never implemented. Useful?]**


> "exit-policy/default" -- The default exit policy lines that Tor will
    * ppend**to the ExitPolicy config option.**

> "desc/id/<OR identity>" or "desc/name/<OR nickname>" -- the latest
> > server descriptor for a given OR.  (Note that modern Tor clients
> > do not download server descriptors by default, but download
> > microdescriptors instead.  If microdescriptors are enabled, you'll
> > need to use md/**instead.)**


> "md/id/<OR identity>" or "md/name/<OR nickname>" -- the latest
> > microdescriptor for a given OR. [First implemented in
> > 0.2.3.8-alpha.]


> "dormant" -- A nonnegative integer: zero if Tor is currently active and
> > building circuits, and nonzero if Tor has gone idle due to lack of use
> > or some similar reason.  [implemented in 0.2.3.16-alpha](First.md)


> "desc-annotations/id/<OR identity>" -- outputs the annotations string
> > (source, timestamp of arrival, purpose, etc) for the corresponding
> > descriptor. [implemented in 0.2.0.13-alpha.](First.md)


> "extra-info/digest/

&lt;digest&gt;

"  -- the extrainfo document whose digest (in
> > hex) is 

&lt;digest&gt;

.  Only available if we're downloading extra-info
> > documents.


> "ns/id/<OR identity>" or "ns/name/<OR nickname>" -- the latest router
> > status info (v3 directory style) for a given OR.  Router status
> > info is as given in
> > dir-spec.txt, and reflects the current beliefs of this Tor about the
> > router in question. Like directory clients, controllers MUST
> > tolerate unrecognized flags and lines.  The published date and
> > descriptor digest are those believed to be best by this Tor,
> > not necessarily those for a descriptor that Tor currently has.
> > [implemented in 0.1.2.3-alpha.](First.md)
> > [0.2.0.9-alpha this switched from v2 directory style to v3](In.md)


> "ns/all" -- Router status info (v3 directory style) for all ORs we
> > have an opinion about, joined by newlines.
> > [implemented in 0.1.2.3-alpha.](First.md)
> > [0.2.0.9-alpha this switched from v2 directory style to v3](In.md)


> "ns/purpose/

&lt;purpose&gt;

" -- Router status info (v3 directory style)
> > for all ORs of this purpose. Mostly designed for /ns/purpose/bridge
> > queries.
> > [implemented in 0.2.0.13-alpha.](First.md)
> > [0.2.0.9-alpha this switched from v2 directory style to v3](In.md)


> "desc/all-recent" -- the latest server descriptor for every router that
> > Tor knows about.  (See note about desc/id/**and desc/name/** above.)


> "network-status" -- a space-separated list (v1 directory style)
> > of all known OR identities. This is in the same format as the
> > router-status line in v1 directories; see dir-spec-v1.txt section
> > 3 for details.  (If VERBOSE\_NAMES is enabled, the output will
> > not conform to dir-spec-v1.txt; instead, the result will be a
> > space-separated list of LongName, each preceded by a "!" if it is
> > believed to be not running.) This option is deprecated; use
> > "ns/all" instead.


> "address-mappings/all"
> "address-mappings/config"
> "address-mappings/cache"
> "address-mappings/control" -- a \r\n-separated list of address
> > mappings, each in the form of "from-address to-address expiry".
> > The 'config' key returns those address mappings set in the
> > configuration; the 'cache' key returns the mappings in the
> > client-side DNS cache; the 'control' key returns the mappings set
> > via the control interface; the 'all' target returns the mappings
> > set through any mechanism.
> > Expiry is formatted as with ADDRMAP events, except that "expiry" is
> > always a time in UTC or the string "NEVER"; see section 4.1.7.
> > First introduced in 0.2.0.3-alpha.


> "addr-mappings/**" -- as for address-mappings/**, but without the
> > expiry portion of the value.  Use of this value is deprecated
> > since 0.2.0.3-alpha; use address-mappings instead.


> "address" -- the best guess at our external IP address. If we
> > have no guess, return a 551 error. (Added in 0.1.2.2-alpha)


> "fingerprint" -- the contents of the fingerprint file that Tor
> > writes as a relay, or a 551 if we're not a relay currently.
> > (Added in 0.1.2.3-alpha)


> "circuit-status"
> > A series of lines as for a circuit status event. Each line is of
> > the form described in section 4.1.1, omitting the initial
> > "650 CIRC ".  Note that clients must be ready to accept additional
> > arguments as described in section 4.1.


> "stream-status"
> > A series of lines as for a stream status event.  Each is of the form:
> > > StreamID SP StreamStatus SP CircuitID SP Target CRLF


> "orconn-status"
> > A series of lines as for an OR connection status event.  In Tor
> > 0.1.2.2-alpha with feature VERBOSE\_NAMES enabled and in Tor
> > 0.2.2.1-alpha and later by default, each line is of the form:
> > > LongName SP ORStatus CRLF


> In Tor versions 0.1.2.2-alpha through 0.2.2.1-alpha with feature
> VERBOSE\_NAMES turned off and before version 0.1.2.2-alpha, each line
> is of the form:
> > ServerID SP ORStatus CRLF


> "entry-guards"
> > A series of lines listing the currently chosen entry guards, if any.
> > In Tor 0.1.2.2-alpha with feature VERBOSE\_NAMES enabled and in Tor
> > 0.2.2.1-alpha and later by default, each line is of the form:
> > > LongName SP Status [ISOTime](SP.md) CRLF


> In Tor versions 0.1.2.2-alpha through 0.2.2.1-alpha with feature
> VERBOSE\_NAMES turned off and before version 0.1.2.2-alpha, each line
> is of the form:
> > ServerID2 SP Status [ISOTime](SP.md) CRLF
> > ServerID2 = Nickname / 40\*HEXDIG


> The definition of Status is the same for both:
> > Status = "up" / "never-connected" / "down" /
> > > "unusable" / "unlisted"


> [From 0.1.1.4-alpha to 0.1.1.10-alpha, entry-guards was called
> > "helper-nodes". Tor still supports calling "helper-nodes", but it
> > > is deprecated and should not be used.]


> [Older versions of Tor (before 0.1.2.x-final) generated 'down' instead
> > of unlisted/unusable.  Current Tors never generate 'down'.]


> [XXXX ServerID2 differs from ServerID in not prefixing fingerprints
> > with a $.  This is an implementation error.  It would be nice to add
> > the $ back in if we can do so without breaking compatibility.]


> "traffic/read" -- Total bytes read (downloaded).

> "traffic/written" -- Total bytes written (uploaded).

> "accounting/enabled"
> "accounting/hibernating"
> "accounting/bytes"
> "accounting/bytes-left"
> "accounting/interval-start"
> "accounting/interval-wake"
> "accounting/interval-end"
> > Information about accounting status.  If accounting is enabled,
> > "enabled" is 1; otherwise it is 0.  The "hibernating" field is "hard"
> > if we are accepting no data; "soft" if we're accepting no new
> > connections, and "awake" if we're not hibernating at all.  The "bytes"
> > and "bytes-left" fields contain (read-bytes SP write-bytes), for the
> > start and the rest of the interval respectively.  The 'interval-start'
> > and 'interval-end' fields are the borders of the current interval; the
> > 'interval-wake' field is the time within the current interval (if any)
> > where we plan[ned](ned.md) to start being active. The times are UTC.


> "config/names"
> > A series of lines listing the available configuration options. Each is
> > of the form:
> > > OptionName SP OptionType [SP Documentation ](.md) CRLF
> > > OptionName = Keyword
> > > OptionType = "Integer" / "TimeInterval" / "TimeMsecInterval" /
> > > > "DataSize" / "Float" / "Boolean" / "Time" / "CommaList" /
> > > > "Dependant" / "Virtual" / "String" / "LineList"

> > > Documentation = Text


> "config/defaults"
> > A series of lines listing default values for each configuration
> > option. Options which don't have a valid default don't show up
> > in the list.  Introduced in Tor 0.2.4.1-alpha.
> > > OptionName SP OptionValue CRLF
> > > OptionName = Keyword
> > > OptionValue = Text


> "info/names"
> > A series of lines listing the available GETINFO options.  Each is of
> > one of these forms:
> > > OptionName SP Documentation CRLF
> > > OptionPrefix SP Documentation CRLF
> > > OptionPrefix = OptionName "/**"

> > The OptionPrefix form indicates a number of options beginning with the
> > prefix. So if "config/**" is listed, other options beginning with
> > "config/" will work, but "config/**" itself is not an option.**


> "events/names"
> > A space-separated list of all the events supported by this version of
> > Tor's SETEVENTS.


> "features/names"
> > A space-separated list of all the features supported by this version
> > of Tor's USEFEATURE.


> "signal/names"
> > A space-separated list of all the values supported by the SIGNAL
> > command.


> "ip-to-country/**"
> > Maps IP addresses to 2-letter country codes.  For example,
> > "GETINFO ip-to-country/18.0.0.1" should give "US".**


> "next-circuit/IP:port"
> > XXX todo.


> "process/pid" -- Process id belonging to the main tor process.
> "process/uid" -- User id running the tor process, -1 if unknown (this is
> > unimplemented on Windows, returning -1).

> "process/user" -- Username under which the tor process is running,
> > providing an empty string if none exists (this is unimplemented on
> > Windows, returning an empty string).

> "process/descriptor-limit" -- Upper bound on the file descriptor limit, -1
> > if unknown.


> "dir/status-vote/current/consensus" [in Tor 0.2.1.6-alpha](added.md)
> "dir/status/authority"
> "dir/status/fp/

&lt;F&gt;

"
> "dir/status/fp/

&lt;F1&gt;

+

&lt;F2&gt;

+

&lt;F3&gt;

"
> "dir/status/all"
> "dir/server/fp/

&lt;F&gt;

"
> "dir/server/fp/

&lt;F1&gt;

+

&lt;F2&gt;

+

&lt;F3&gt;

"
> "dir/server/d/

&lt;D&gt;

"
> "dir/server/d/

&lt;D1&gt;

+

&lt;D2&gt;

+

&lt;D3&gt;

"
> "dir/server/authority"
> "dir/server/all"
> > A series of lines listing directory contents, provided according to the
> > specification for the URLs listed in Section 4.4 of dir-spec.txt.  Note
> > that Tor MUST NOT provide private information, such as descriptors for
> > routers not marked as general-purpose.  When asked for 'authority'
> > information for which this Tor is not authoritative, Tor replies with
> > an empty string.


> Note that, as of Tor 0.2.3.3-alpha, Tor clients don't download server
> descriptors anymore, but microdescriptors.  So, a "551 Servers
> unavailable" reply to all "GETINFO dir/server/**" requests is actually
> correct.  If you have an old program which absolutely requires server
> descriptors to work, try setting UseMicrodescriptors 0 or
> FetchUselessDescriptors 1 in your client's torrc.**

> "status/circuit-established"
> "status/enough-dir-info"
> "status/good-server-descriptor"
> "status/accepted-server-descriptor"
> "status/..."
> > These provide the current internal Tor values for various Tor
> > states. See Section 4.1.10 for explanations. (Only a few of the
> > status events are available as getinfo's currently. Let us know if
> > you want more exposed.)

> "status/reachability-succeeded/or"
> > 0 or 1, depending on whether we've found our ORPort reachable.

> "status/reachability-succeeded/dir"
> > 0 or 1, depending on whether we've found our DirPort reachable.

> "status/reachability-succeeded"
> > "OR=" ("0"/"1") SP "DIR=" ("0"/"1")
> > Combines status/reachability-succeeded/**; controllers MUST ignore
> > unrecognized elements in this entry.

> "status/bootstrap-phase"
> > Returns the most recent bootstrap phase status event
> > sent. Specifically, it returns a string starting with either
> > "NOTICE BOOTSTRAP ..." or "WARN BOOTSTRAP ...". Controllers should
> > use this getinfo when they connect or attach to Tor to learn its
> > current bootstrap state.

> "status/version/recommended"
> > List of currently recommended versions.

> "status/version/current"
> > Status of the current version. One of: new, old, unrecommended,
> > recommended, new in series, obsolete, unknown.

> "status/version/num-concurring"
> "status/version/num-versioning"
> > These options are deprecated; they no longer give useful information.

> "status/clients-seen"
> > A summary of which countries we've seen clients from recently,
> > formatted the same as the CLIENTS\_SEEN status event described in
> > Section 4.1.14. This GETINFO option is currently available only
> > for bridge relays.**


> "net/listeners/or"
> "net/listeners/dir"
> "net/listeners/socks"
> "net/listeners/trans"
> "net/listeners/natd"
> "net/listeners/dns"
> "net/listeners/control"
> > A space-separated list of the addresses at which Tor is listening for
> > connections of each specified type.  [in Tor 0.2.2.26-beta.](New.md)


> "dir-usage"
> > A newline-separated list of how many bytes we've served to answer
> > each type of directory request. The format of each line is:
> > > Keyword 1\*SP Integer 1\*SP Integer

> > where the first integer is the number of bytes written, and the second
> > is the number of requests answered.


> Examples:
> > C: GETINFO version desc/name/moria1
> > S: 250+desc/name/moria=
> > S: [for moria](Descriptor.md)
> > S: .
> > S: 250-version=Tor 0.1.1.0-alpha-cvs
> > S: 250 OK

3.10. EXTENDCIRCUIT


> Sent from the client to the server.  The format is:
> > "EXTENDCIRCUIT" SP CircuitID
> > > [ServerSpec \*("," ServerSpec)](SP.md)
> > > ["purpose=" Purpose](SP.md) CRLF


> This request takes one of two forms: either the CircuitID is zero, in
> which case it is a request for the server to build a new circuit,
> or the CircuitID is nonzero, in which case it is a request for the
> server to extend an existing circuit with that ID according to the
> specified path.

> If the CircuitID is 0, the controller has the option of providing
> a path for Tor to use to build the circuit. If it does not provide
> a path, Tor will select one automatically from high capacity nodes
> according to path-spec.txt.

> If CircuitID is 0 and "purpose=" is specified, then the circuit's
> purpose is set. Two choices are recognized: "general" and
> "controller". If not specified, circuits are created as "general".

> If the request is successful, the server sends a reply containing a
> message body consisting of the CircuitID of the (maybe newly created)
> circuit. The syntax is "250" SP "EXTENDED" SP CircuitID CRLF.

3.11. SETCIRCUITPURPOSE

> Sent from the client to the server.  The format is:
> > "SETCIRCUITPURPOSE" SP CircuitID SP "purpose=" Purpose CRLF


> This changes the circuit's purpose. See EXTENDCIRCUIT above for details.

3.12. SETROUTERPURPOSE

> Sent from the client to the server.  The format is:
> > "SETROUTERPURPOSE" SP NicknameOrKey SP Purpose CRLF


> This changes the descriptor's purpose. See +POSTDESCRIPTOR below
> for details.

> NOTE: This command was disabled and made obsolete as of Tor
> 0.2.0.8-alpha. It doesn't exist anymore, and is listed here only for
> historical interest.

3.13. ATTACHSTREAM

> Sent from the client to the server.  The syntax is:
> > "ATTACHSTREAM" SP StreamID SP CircuitID ["HOP=" HopNum](SP.md) CRLF


> This message informs the server that the specified stream should be
> associated with the specified circuit.  Each stream may be associated with
> at most one circuit, and multiple streams may share the same circuit.
> Streams can only be attached to completed circuits (that is, circuits that
> have sent a circuit status 'BUILT' event or are listed as built in a
> GETINFO circuit-status request).

> If the circuit ID is 0, responsibility for attaching the given stream is
> returned to Tor.

> If HOP=HopNum is specified, Tor will choose the HopNumth hop in the
> circuit as the exit node, rather than the last node in the circuit.
> Hops are 1-indexed; generally, it is not permitted to attach to hop 1.

> Tor responds with "250 OK" if it can attach the stream, 552 if the
> circuit or stream didn't exist, 555 if the stream isn't in an
> appropriate state to be attached (e.g. it's already open), or 551 if
> the stream couldn't be attached for another reason.

> {Implementation note: Tor will close unattached streams by itself,
> roughly two minutes after they are born. Let the developers know if
> that turns out to be a problem.}

> {Implementation note: By default, Tor automatically attaches streams to
> circuits itself, unless the configuration variable
> "LeaveStreamsUnattached" is set to "1".  Attempting to attach streams
> via TC when "LeaveStreamsUnattached" is false may cause a race between
> Tor and the controller, as both attempt to attach streams to circuits.}

> {Implementation note: You can try to attachstream to a stream that
> has already sent a connect or resolve request but hasn't succeeded
> yet, in which case Tor will detach the stream from its current circuit
> before proceeding with the new attach request.}

3.14. POSTDESCRIPTOR

> Sent from the client to the server. The syntax is:
> > "+POSTDESCRIPTOR" ["purpose=" Purpose](SP.md) ["cache=" Cache](SP.md)
> > > CRLF Descriptor CRLF "." CRLF


> This message informs the server about a new descriptor. If Purpose is
> specified, it must be either "general", "controller", or "bridge",
> else we return a 552 error. The default is "general".

> If Cache is specified, it must be either "no" or "yes", else we
> return a 552 error. If Cache is not specified, Tor will decide for
> itself whether it wants to cache the descriptor, and controllers
> must not rely on its choice.

> The descriptor, when parsed, must contain a number of well-specified
> fields, including fields for its nickname and identity.

> If there is an error in parsing the descriptor, the server must send a
> "554 Invalid descriptor" reply. If the descriptor is well-formed but
> the server chooses not to add it, it must reply with a 251 message
> whose body explains why the server was not added. If the descriptor
> is added, Tor replies with "250 OK".

3.15. REDIRECTSTREAM

> Sent from the client to the server. The syntax is:
> > "REDIRECTSTREAM" SP StreamID SP Address [Port](SP.md) CRLF


> Tells the server to change the exit address on the specified stream.  If
> Port is specified, changes the destination port as well.  No remapping
> is performed on the new provided address.

> To be sure that the modified address will be used, this event must be sent
> after a new stream event is received, and before attaching this stream to
> a circuit.

> Tor replies with "250 OK" on success.

3.16. CLOSESTREAM

> Sent from the client to the server.  The syntax is:

> "CLOSESTREAM" SP StreamID SP Reason **(SP Flag) CRLF**

> Tells the server to close the specified stream.  The reason should be one
> of the Tor RELAY\_END reasons given in tor-spec.txt, as a decimal.  Flags is
> not used currently; Tor servers SHOULD ignore unrecognized flags.  Tor may
> hold the stream open for a while to flush any data that is pending.

> Tor replies with "250 OK" on success, or a 512 if there aren't enough
> arguments, or a 552 if it doesn't recognize the StreamID or reason.

3.17. CLOSECIRCUIT

> The syntax is:
> > "CLOSECIRCUIT" SP CircuitID **(SP Flag) CRLF
> > Flag = "IfUnused"**


> Tells the server to close the specified circuit.   If "IfUnused" is
> provided, do not close the circuit unless it is unused.

> Other flags may be defined in the future; Tor SHOULD ignore unrecognized
> flags.

> Tor replies with "250 OK" on success, or a 512 if there aren't enough
> arguments, or a 552 if it doesn't recognize the CircuitID.

3.18. QUIT

> Tells the server to hang up on this controller connection. This command
> can be used before authenticating.

3.19. USEFEATURE

> Adding additional features to the control protocol sometimes will break
> backwards compatibility. Initially such features are added into Tor and
> disabled by default. USEFEATURE can enable these additional features.

> The syntax is:

> "USEFEATURE" **(SP FeatureName) CRLF
> FeatureName = 1**(ALPHA / DIGIT / "_" / "-")_

> Feature names are case-insensitive.

> Once enabled, a feature stays enabled for the duration of the connection
> to the controller. A new connection to the controller must be opened to
> disable an enabled feature.

> Features are a forward-compatibility mechanism; each feature will eventually
> become a standard part of the control protocol. Once a feature becomes part
> of the protocol, it is always-on. Each feature documents the version it was
> introduced as a feature and the version in which it became part of the
> protocol.

> Tor will ignore a request to use any feature that is always-on. Tor will give
> a 552 error in response to an unrecognized feature.

> EXTENDED\_EVENTS

> Same as passing 'EXTENDED' to SETEVENTS; this is the preferred way to
> request the extended event syntax.

> This feature was first introduced in 0.1.2.3-alpha.  It is always-on
> and part of the protocol in Tor 0.2.2.1-alpha and later.

> VERBOSE\_NAMES

> Replaces ServerID with LongName in events and GETINFO results. LongName
> provides a Fingerprint for all routers, an indication of Named status,
> and a Nickname if one is known. LongName is strictly more informative
> than ServerID, which only provides either a Fingerprint or a Nickname.

> This feature was first introduced in 0.1.2.2-alpha. It is always-on and
> part of the protocol in Tor 0.2.2.1-alpha and later.

3.20. RESOLVE

> The syntax is
> > "RESOLVE" **Option**Address CRLF
> > Option = "mode=reverse"
> > Address = a hostname or IPv4 address


> This command launches a remote hostname lookup request for every specified
> request (or reverse lookup if "mode=reverse" is specified).  Note that the
> request is done in the background: to see the answers, your controller will
> need to listen for ADDRMAP events; see 4.1.7 below.

> [in Tor 0.2.0.3-alpha](Added.md)

3.21. PROTOCOLINFO

> The syntax is:
> > "PROTOCOLINFO" **(SP PIVERSION) CRLF**


> The server reply format is:
> > "250-PROTOCOLINFO" SP PIVERSION CRLF **InfoLine "250 OK" CRLF**


> InfoLine = AuthLine / VersionLine / OtherLine

> AuthLine = "250-AUTH" SP "METHODS=" AuthMethod **("," AuthMethod)
    * SP "COOKIEFILE=" AuthCookieFile) CRLF
> VersionLine = "250-VERSION" SP "Tor=" TorVersion OptArguments CRLF**

> AuthMethod =
> > "NULL"           / ; No authentication is required
> > "HASHEDPASSWORD" / ; A controller must supply the original password
> > "COOKIE"         / ; A controller must supply the contents of a cookie
> > "SAFECOOKIE"       ; A controller must prove knowledge of a cookie


> AuthCookieFile = QuotedString
> TorVersion = QuotedString

> OtherLine = "250-" Keyword OptArguments CRLF

> PIVERSION: 1\*DIGIT

> Tor MAY give its InfoLines in any order; controllers MUST ignore InfoLines
> with keywords they do not recognize.  Controllers MUST ignore extraneous
> data on any InfoLine.

> PIVERSION is there in case we drastically change the syntax one day. For
> now it should always be "1".  Controllers MAY provide a list of the
> protocolinfo versions they support; Tor MAY select a version that the
> controller does not support.

> AuthMethod is used to specify one or more control authentication
> methods that Tor currently accepts.

> AuthCookieFile specifies the absolute path and filename of the
> authentication cookie that Tor is expecting and is provided iff the
> METHODS field contains the method "COOKIE" and/or "SAFECOOKIE".
> Controllers MUST handle escape sequences inside this string.

> All authentication cookies are 32 bytes long.  Controllers MUST NOT
> use the contents of a non-32-byte-long file as an authentication
> cookie.

> If the METHODS field contains the method "SAFECOOKIE", every
> AuthCookieFile must contain the same authentication cookie.

> The COOKIE authentication method exposes the user running a
> controller to an unintended information disclosure attack whenever
> the controller has greater filesystem read access than the process
> that it has connected to.  (Note that a controller may connect to a
> process other than Tor.)  It is almost never safe to use, even if
> the controller's user has explicitly specified which filename to
> read an authentication cookie from.  For this reason, the COOKIE
> authentication method has been deprecated and will be removed from
> a future version of Tor.

> The VERSION line contains the Tor version.

> [Unlike other commands besides AUTHENTICATE, PROTOCOLINFO may be used (but
> only once!) before AUTHENTICATE.]

> [was not supported before Tor 0.2.0.5-alpha.](PROTOCOLINFO.md)

3.22. LOADCONF

> The syntax is:
> > "+LOADCONF" CRLF ConfigText CRLF "." CRLF


> This command allows a controller to upload the text of a config file
> to Tor over the control port.  This config file is then loaded as if
> it had been read from disk.

> [was added in Tor 0.2.1.1-alpha.](LOADCONF.md)

3.23. TAKEOWNERSHIP

> The syntax is:
> > "TAKEOWNERSHIP" CRLF


> This command instructs Tor to shut down (as if it had received
> SIGINT or a "SIGNAL INT" controller command) when this control
> connection is closed.  This command affects each control connection
> that sends it independently; if multiple control connections send
> the TAKEOWNERSHIP command to a Tor instance, Tor will shut down when
> any of those connections closes.

> This command is intended to be used with the
> OwningControllerProcess configuration option.  A controller that
> starts a Tor process which the user cannot easily control or stop
> should 'own' that Tor process:

  * When starting Tor, the controller should specify its PID in an
> > OwningControllerProcess on Tor's command line.  This will
> > cause Tor to poll for the existence of a process with that PID,
> > and exit if it does not find such a process.  (This is not a
> > completely reliable way to detect whether the 'owning
> > controller' is still running, but it should work well enough in
> > most cases.)

  * Once the controller has connected to Tor's control port, it
> > should send the TAKEOWNERSHIP command along its control
> > connection.  At this point, **both** the TAKEOWNERSHIP command and
> > the OwningControllerProcess option are in effect: Tor will
> > exit when the control connection ends **and** Tor will exit if it
> > detects that there is no process with the PID specified in the
> > OwningControllerProcess option.

  * After the controller has sent the TAKEOWNERSHIP command, it
> > should send "RESETCONF OwningControllerProcess" along its
> > control connection.  This will cause Tor to stop polling for the
> > existence of a process with its owning controller's PID; Tor
> > will still exit when the control connection ends.


> [was added in Tor 0.2.2.28-beta.](TAKEOWNERSHIP.md)

3.24. AUTHCHALLENGE

> The syntax is:
> > "AUTHCHALLENGE" SP "SAFECOOKIE"
> > > SP ClientNonce
> > > CRLF


> ClientNonce = 2\*HEXDIG / QuotedString

> If the server accepts the command, the server reply format is:
> > "250 AUTHCHALLENGE"
> > > SP "SERVERHASH=" ServerHash
> > > SP "SERVERNONCE=" ServerNonce
> > > CRLF


> ServerHash = 64\*64HEXDIG
> ServerNonce = 64\*64HEXDIG

> The ClientNonce, ServerHash, and ServerNonce values are
> encoded/decoded in the same way as the argument passed to the
> AUTHENTICATE command.  ServerNonce MUST be 32 bytes long.

> ServerHash is computed as:
> > HMAC-SHA256("Tor safe cookie authentication server-to-controller hash",
> > > CookieString | ClientNonce | ServerNonce)

> (with the HMAC key as its first argument)

> After a controller sends a successful AUTHCHALLENGE command, the
> next command sent on the connection must be an AUTHENTICATE command,
> and the only authentication string which that AUTHENTICATE command
> will accept is:
> > HMAC-SHA256("Tor safe cookie authentication controller-to-server hash",
> > > CookieString | ClientNonce | ServerNonce)


> [Unlike other commands besides AUTHENTICATE, AUTHCHALLENGE may be
> used (but only once!) before AUTHENTICATE.]

> [was added in Tor FIXME.](AUTHCHALLENGE.md)

3.25. DROPGUARDS

> The syntax is:
> > "DROPGUARDS" CRLF


> Tells the server to drop all guard nodes. Do not invoke this command
> lightly; it can increase vulnerability to tracking attacks over time.

> Tor replies with "250 OK" on success.

> [was added in Tor 0.2.5.1-alpha.](DROPGUARDS.md)

4. Replies

> Reply codes follow the same 3-character format as used by SMTP, with the
> first character defining a status, the second character defining a
> subsystem, and the third designating fine-grained information.

> The TC protocol currently uses the following first characters:

> 2yz   Positive Completion Reply
> > The command was successful; a new request can be started.


> 4yz   Temporary Negative Completion reply
> > The command was unsuccessful but might be reattempted later.


> 5yz   Permanent Negative Completion Reply
> > The command was unsuccessful; the client should not try exactly
> > that sequence of commands again.


> 6yz   Asynchronous Reply
> > Sent out-of-order in response to an earlier SETEVENTS command.


> The following second characters are used:

> x0z   Syntax
> > Sent in response to ill-formed or nonsensical commands.


> x1z   Protocol
> > Refers to operations of the Tor Control protocol.


> x5z   Tor
> > Refers to actual operations of Tor system.


> The following codes are defined:

> 250 OK
> 251 Operation was unnecessary
> > [has declined to perform the operation, but no harm was done.](Tor.md)


> 451 Resource exhausted

> 500 Syntax error: protocol

> 510 Unrecognized command
> 511 Unimplemented command
> 512 Syntax error in command argument
> 513 Unrecognized command argument
> 514 Authentication required
> 515 Bad authentication

> 550 Unspecified Tor error

> 551 Internal error
> > [Something went wrong inside Tor, so that the client's
> > > request couldn't be fulfilled.]


> 552 Unrecognized entity
> > [A configuration key, a stream ID, circuit ID, event,
> > > mentioned in the command did not actually exist.]


> 553 Invalid configuration value
> > [The client tried to set a configuration option to an
> > > incorrect, ill-formed, or impossible value.]


> 554 Invalid descriptor

> 555 Unmanaged entity

> 650 Asynchronous event notification

> Unless specified to have specific contents, the human-readable messages
> in error replies should not be relied upon to match those in this document.

4.1. Asynchronous events

> These replies can be sent after a corresponding SETEVENTS command has been
> received.  They will not be interleaved with other Reply elements, but they
> can appear between a command and its corresponding reply.  For example,
> this sequence is possible:

> C: SETEVENTS CIRC
> S: 250 OK
> C: GETCONF SOCKSPORT ORPORT
> S: 650 CIRC 1000 EXTENDED moria1,moria2
> S: 250-SOCKSPORT=9050
> S: 250 ORPORT=0

> But this sequence is disallowed:
> > C: SETEVENTS CIRC
> > S: 250 OK
> > C: GETCONF SOCKSPORT ORPORT
> > S: 250-SOCKSPORT=9050
> > S: 650 CIRC 1000 EXTENDED moria1,moria2
> > S: 250 ORPORT=0


> Clients MUST tolerate more arguments in an asynchronous reply than
> expected, and MUST tolerate more lines in an asynchronous reply than
> expected.  For instance, a client that expects a CIRC message like:
> > 650 CIRC 1000 EXTENDED moria1,moria2

> must tolerate:
> > 650-CIRC 1000 EXTENDED moria1,moria2 0xBEEF
> > 650-EXTRAMAGIC=99
> > 650 ANONYMITY=high


> If clients receives extended events (selected by USEFEATUERE
> EXTENDED\_EVENTS in Tor 0.1.2.2-alpha..Tor-0.2.1.x, and always-on in
> Tor 0.2.2.x and later), then each event line as specified below may be
> followed by additional arguments and additional lines.  Additional
> lines will be of the form:
> > "650" ("-"/" ") KEYWORD ["=" ARGUMENTS] CRLF

> Additional arguments will be of the form
> > SP KEYWORD ["=" ( QuotedString / **NonSpDquote ) ]**


> Clients MUST tolerate events with arguments and keywords they do not
> recognize, and SHOULD process those events as if any unrecognized
> arguments and keywords were not present.

> Clients SHOULD NOT depend on the order of keyword=value arguments,
> and SHOULD NOT depend on there being no new keyword=value arguments
> appearing between existing keyword=value arguments, though as of this
> writing (Jun 2011) some do.  Thus, extensions to this protocol should
> add new keywords only after the existing keywords, until all
> controllers have been fixed.  At some point this "SHOULD NOT" might
> become a "MUST NOT".

4.1.1. Circuit status changed

> The syntax is:

> "650" SP "CIRC" SP CircuitID SP CircStatus [Path](SP.md)
> > ["BUILD\_FLAGS=" BuildFlags](SP.md) ["PURPOSE=" Purpose](SP.md)
> > ["HS\_STATE=" HSState](SP.md) ["REND\_QUERY=" HSAddress](SP.md)
> > ["TIME\_CREATED=" TimeCreated](SP.md)
> > ["REASON=" Reason [SP "REMOTE\_REASON=" Reason](SP.md)] CRLF


> CircStatus =
> > "LAUNCHED" / ; circuit ID assigned to new circuit
> > "BUILT"    / ; all hops finished, can now accept streams
> > "EXTENDED" / ; one more hop has been completed
> > "FAILED"   / ; circuit closed (was not built)
> > "CLOSED"     ; circuit closed (was built)


> Path = LongName **("," LongName)
> > ; In Tor versions 0.1.2.2-alpha through 0.2.2.1-alpha with feature
> > ; VERBOSE\_NAMES turned off and before version 0.1.2.2-alpha, Path
> > ; is as follows:
> > ; Path = ServerID**("," ServerID)


> BuildFlags = BuildFlag **("," BuildFlag)
> BuildFlag = "ONEHOP\_TUNNEL" / "IS\_INTERNAL" /
> > "NEED\_CAPACITY" / "NEED\_UPTIME"**


> Purpose = "GENERAL" / "HS\_CLIENT\_INTRO" / "HS\_CLIENT\_REND" /
> > "HS\_SERVICE\_INTRO" / "HS\_SERVICE\_REND" / "TESTING" /
> > "CONTROLLER" / "MEASURE\_TIMEOUT"


> HSState = "HSCI\_CONNECTING" / "HSCI\_INTRO\_SENT" / "HSCI\_DONE" /
> > "HSCR\_CONNECTING" / "HSCR\_ESTABLISHED\_IDLE" /
> > "HSCR\_ESTABLISHED\_WAITING" / "HSCR\_JOINED" /
> > "HSSI\_CONNECTING" / "HSSI\_ESTABLISHED" /
> > "HSSR\_CONNECTING" / "HSSR\_JOINED"


> HSAddress = 16\*Base32Character
> Base32Character = ALPHA / "2" / "3" / "4" / "5" / "6" / "7"

> TimeCreated = ISOTime2Frac
> Seconds = 1\*DIGIT
> Microseconds = 1\*DIGIT

> Reason = "NONE" / "TORPROTOCOL" / "INTERNAL" / "REQUESTED" /
> > "HIBERNATING" / "RESOURCELIMIT" / "CONNECTFAILED" /
> > "OR\_IDENTITY" / "OR\_CONN\_CLOSED" / "TIMEOUT" /
> > "FINISHED" / "DESTROYED" / "NOPATH" / "NOSUCHSERVICE" /
> > "MEASUREMENT\_EXPIRED"


> The path is provided only when the circuit has been extended at least one
> hop.

> The "BUILD\_FLAGS" field is provided only in versions 0.2.3.11-alpha
> and later.  Clients MUST accept build flags not listed above.
> Build flags are defined as follows:

> ONEHOP\_TUNNEL   (one-hop circuit, used for tunneled directory conns)
> IS\_INTERNAL     (internal circuit, not to be used for exiting streams)
> NEED\_CAPACITY   (this circuit must use only high-capacity nodes)
> NEED\_UPTIME     (this circuit must use only high-uptime nodes)

> The "PURPOSE" field is provided only in versions 0.2.1.6-alpha and
> later, and only if extended events are enabled (see 3.19).  Clients
> MUST accept purposes not listed above.  Purposes are defined as
> follows:

> GENERAL         (circuit for AP and/or directory request streams)
> HS\_CLIENT\_INTRO (HS client-side introduction-point circuit)
> HS\_CLIENT\_REND  (HS client-side rendezvous circuit; carries AP streams)
> HS\_SERVICE\_INTRO (HS service-side introduction-point circuit)
> HS\_SERVICE\_REND (HS service-side rendezvous circuit)
> TESTING         (reachability-testing circuit; carries no traffic)
> CONTROLLER      (circuit built by a controller)
> MEASURE\_TIMEOUT (circuit being kept around to see how long it takes)

> The "HS\_STATE" field is provided only for hidden-service circuits,
> and only in versions 0.2.3.11-alpha and later.  Clients MUST accept
> hidden-service circuit states not listed above.  Hidden-service
> circuit states are defined as follows:

> HSCI__(client-side introduction-point circuit states)
> > HSCI\_CONNECTING          (connecting to intro point)
> > HSCI\_INTRO\_SENT          (sent INTRODUCE1; waiting for reply from IP)
> > HSCI\_DONE                (received reply from IP relay; closing)_


> HSCR      (client-side rendezvous-point circuit states)
> > HSCR\_CONNECTING          (connecting to or waiting for reply from RP)
> > HSCR\_ESTABLISHED\_IDLE    (established RP; waiting for introduction)
> > HSCR\_ESTABLISHED\_WAITING (introduction sent to HS; waiting for rend)
> > HSCR\_JOINED              (connected to HS)_


> HSSI__(service-side introduction-point circuit states)
> > HSSI\_CONNECTING          (connecting to intro point)
> > HSSI\_ESTABLISHED         (established intro point)_


> HSSR      (service-side rendezvous-point circuit states)
> > HSSR\_CONNECTING          (connecting to client's rend point)
> > HSSR\_JOINED              (connected to client's RP circuit)_


> The "REND\_QUERY" field is provided only for hidden-service-related
> circuits, and only in versions 0.2.3.11-alpha and later.  Clients
> MUST accept hidden service addresses in formats other than that
> specified above.

> The "TIME\_CREATED" field is provided only in versions 0.2.3.11-alpha and
> later.  TIME\_CREATED is the time at which the circuit was created or
> cannibalized.

> The "REASON" field is provided only for FAILED and CLOSED events, and only
> if extended events are enabled (see 3.19).  Clients MUST accept reasons
> not listed above.  Reasons are as given in tor-spec.txt, except for:

> NOPATH              (Not enough nodes to make circuit)
> MEASUREMENT\_EXPIRED (As "TIMEOUT", except that we had left the circuit
> > open for measurement purposes to see how long it
> > would take to finish.)


> The "REMOTE\_REASON" field is provided only when we receive a DESTROY or
> TRUNCATE cell, and only if extended events are enabled.  It contains the
> actual reason given by the remote OR for closing the circuit. Clients MUST
> accept reasons not listed above.  Reasons are as listed in tor-spec.txt.

4.1.2. Stream status changed

> The syntax is:

> "650" SP "STREAM" SP StreamID SP StreamStatus SP CircuitID SP Target
> > ["REASON=" Reason [ SP "REMOTE\_REASON=" Reason ](SP.md)]
> > ["SOURCE=" Source](SP.md) [SP "SOURCE\_ADDR=" Address ":" Port ](.md)
> > ["PURPOSE=" Purpose](SP.md)
> > CRLF


> StreamStatus =
> > "NEW"          / ; New request to connect
> > "NEWRESOLVE"   / ; New request to resolve an address
> > "REMAP"        / ; Address re-mapped to another
> > "SENTCONNECT"  / ; Sent a connect cell along a circuit
> > "SENTRESOLVE"  / ; Sent a resolve cell along a circuit
> > "SUCCEEDED"    / ; Received a reply; stream established
> > "FAILED"       / ; Stream failed and not retriable
> > "CLOSED"       / ; Stream closed
> > "DETACHED"       ; Detached from circuit; still retriable


> Target = TargetAddress ":" Port
> Port = an integer from 0 to 65535 inclusive
> TargetAddress = Address / "(Tor\_internal)"

> The circuit ID designates which circuit this stream is attached to.  If
> the stream is unattached, the circuit ID "0" is given.  The target
> indicates the address which the stream is meant to resolve or connect to;
> it can be "(Tor\_internal)" for a virtual stream created by the Tor program
> to talk to itself.

> Reason = "MISC" / "RESOLVEFAILED" / "CONNECTREFUSED" /
> > "EXITPOLICY" / "DESTROY" / "DONE" / "TIMEOUT" /
> > "NOROUTE" / "HIBERNATING" / "INTERNAL"/ "RESOURCELIMIT" /
> > "CONNRESET" / "TORPROTOCOL" / "NOTDIRECTORY" / "END" /
> > "PRIVATE\_ADDR"


> The "REASON" field is provided only for FAILED, CLOSED, and DETACHED
> events, and only if extended events are enabled (see 3.19).  Clients MUST
> accept reasons not listed above.  Reasons are as given in tor-spec.txt,
> except for:

> END          (We received a RELAY\_END cell from the other side of this
> > stream.)

> PRIVATE\_ADDR (The client tried to connect to a private address like
    1. 7.0.0.1 or 10.0.0.1 over Tor.)
> [document more. -NM](XXXX.md)

> The "REMOTE\_REASON" field is provided only when we receive a RELAY\_END
> cell, and only if extended events are enabled.  It contains the actual
> reason given by the remote OR for closing the stream. Clients MUST accept
> reasons not listed above.  Reasons are as listed in tor-spec.txt.

> "REMAP" events include a Source if extended events are enabled:
> > Source = "CACHE" / "EXIT"

> Clients MUST accept sources not listed above.  "CACHE" is given if
> the Tor client decided to remap the address because of a cached
> answer, and "EXIT" is given if the remote node we queried gave us
> the new address as a response.

> The "SOURCE\_ADDR" field is included with NEW and NEWRESOLVE events if
> extended events are enabled.  It indicates the address and port
> that requested the connection, and can be (e.g.) used to look up the
> requesting program.

> Purpose = "DIR\_FETCH" / "DIR\_UPLOAD" / "DNS\_REQUEST" /
> > "USER" /  "DIRPORT\_TEST"


> The "PURPOSE" field is provided only for NEW and NEWRESOLVE events, and
> only if extended events are enabled (see 3.19).  Clients MUST accept
> purposes not listed above.  The purposes above are defined as:

> "DIR\_FETCH" -- This stream is generated internally to Tor for
> > fetching directory information.

> "DIR\_UPLOAD" -- An internal stream for uploading information to
> > a directory authority.

> "DIRPORT\_TEST" -- A stream we're using to test our own directory
> > port to make sure it's reachable.

> "DNS\_REQUEST" -- A user-initiated DNS request.
> "USER" -- This stream is handling user traffic, OR it's internal
> > to Tor, but it doesn't match one of the purposes above.

4.1.3. OR Connection status changed


> The syntax is:

> "650" SP "ORCONN" SP (LongName / Target) SP ORStatus [ SP "REASON="
> > Reason ] [SP "NCIRCS=" NumCircuits ](.md) [SP "ID=" ConnID ](.md) CRLF


> ORStatus = "NEW" / "LAUNCHED" / "CONNECTED" / "FAILED" / "CLOSED"

> ; In Tor versions 0.1.2.2-alpha through 0.2.2.1-alpha with feature
> ; VERBOSE\_NAMES turned off and before version 0.1.2.2-alpha, OR
> ; Connection is as follows:
> "650" SP "ORCONN" SP (ServerID / Target) SP ORStatus [ SP "REASON="
> > Reason ] [SP "NCIRCS=" NumCircuits ](.md) CRLF


> NEW is for incoming connections, and LAUNCHED is for outgoing
> connections. CONNECTED means the TLS handshake has finished (in
> either direction). FAILED means a connection is being closed that
> hasn't finished its handshake, and CLOSED is for connections that
> have handshaked.

> A LongName or ServerID is specified unless it's a NEW connection, in
> which case we don't know what server it is yet, so we use Address:Port.

> If extended events are enabled (see 3.19), optional reason and
> circuit counting information is provided for CLOSED and FAILED
> events.

> Reason = "MISC" / "DONE" / "CONNECTREFUSED" /
> > "IDENTITY" / "CONNECTRESET" / "TIMEOUT" / "NOROUTE" /
> > "IOERROR" / "RESOURCELIMIT"


> NumCircuits counts both established and pending circuits.

> The ORStatus values are as follows:
> > NEW -- We have received a new incoming OR connection, and are starting
> > > the server-side handshake.

> > LAUNCHED -- We have launched a new outgoing OR connection, and are
> > > starting the client-side handshake.

> > CONNECTED -- The OR connection has been connected and the handshake is
> > > done.

> > FAILED -- Our attempt to open the OR connection failed.
> > CLOSED -- The OR connection closed in an unremarkable way.


> The Reason values for closed/failed OR connections are:
> > DONE -- The OR connection has shut down cleanly.
> > CONNECTREFUSED -- We got an ECONNREFUSED while connecting to the target
> > > OR.

> > IDENTITY -- We connected to the OR, but found that its identity was
> > > not what we expected.

> > CONNECTRESET -- We got an ECONNRESET or similar IO error from the
> > > connection with the OR.

> > TIMEOUT -- We got an ETIMEOUT or similar IO error from the connection
> > > with the OR, or we're closing the connection for being idle for too
> > > long.

> > NOROUTE -- We got an ENOTCONN, ENETUNREACH, ENETDOWN, EHOSTUNREACH, or
> > > similar error while connecting to the OR.

> > IOERROR -- We got some other IO error on our connection to the OR.
> > RESOURCELIMIT -- We don't have enough operating system resources (file
> > > descriptors, buffers, etc) to connect to the OR.

> > MISC -- The OR connection closed for some other reason.


> [added ID parameter in 0.2.5.2-alpha](First.md)

4.1.4. Bandwidth used in the last second

> The syntax is:
> > "650" SP "BW" SP BytesRead SP BytesWritten **(SP Type "=" Num) CRLF
> > BytesRead = 1\*DIGIT
> > BytesWritten = 1\*DIGIT
> > Type = "DIR" / "OR" / "EXIT" / "APP" / ...
> > Num = 1\*DIGIT**


> BytesRead and BytesWritten are the totals. [In a future Tor version,
> we may also include a breakdown of the connection types that used
> bandwidth this second (not implemented yet).]

4.1.5. Log messages

> The syntax is:
> > "650" SP Severity SP ReplyText CRLF

> or
> > "650+" Severity CRLF Data 650 SP "OK" CRLF


> Severity = "DEBUG" / "INFO" / "NOTICE" / "WARN"/ "ERR"

4.1.6. New descriptors available

> Syntax:
> > "650" SP "NEWDESC" 1**(SP LongName) CRLF
> > > ; In Tor versions 0.1.2.2-alpha through 0.2.2.1-alpha with feature
> > > ; VERBOSE\_NAMES turned off and before version 0.1.2.2-alpha, it
> > > ; is as follows:
> > > "650" SP "NEWDESC" 1**(SP ServerID) CRLF

4.1.7. New Address mapping


> These events are generated when a new address mapping is entered in
> Tor's address map cache, or when the answer for a RESOLVE command is
> found.  Entries can be created by a successful or failed DNS lookup,
> a successful or failed connection attempt, a RESOLVE command,
> a MAPADDRESS command, the AutomapHostsOnResolve feature, or the
> TrackHostExits feature.

> Syntax:
> > "650" SP "ADDRMAP" SP Address SP NewAddress SP Expiry
> > > ["error=" ErrorCode](SP.md) ["EXPIRES=" UTCExpiry](SP.md) ["CACHED=" Cached](SP.md)
> > > CRLF


> NewAddress = Address / "

&lt;error&gt;

"
> Expiry = DQUOTE ISOTime DQUOTE / "NEVER"

> ErrorCode = "yes" / "internal" / "Unable to launch resolve request"
> UTCExpiry = DQUOTE IsoTime DQUOTE

> Cached = DQUOTE "YES" DQUOTE / DQUOTE "NO" DQUOTE

> Error and UTCExpiry are only provided if extended events are enabled.
> The values for Error are mostly useless.  Future values will be
> chosen to match 1_(ALNUM / "**"); the "Unable to launch resolve request"
> value is a bug in Tor before 0.2.4.7-alpha.**

> Expiry is expressed as the local time (rather than UTC).  This is a bug,
> left in for backward compatibility; new code should look at UTCExpiry
> instead.  (If Expiry is "NEVER", UTCExpiry is omitted.)_

> Cached indicates whether the mapping will be stored until it expires, or if
> it is just a notification in response to a RESOLVE command.

4.1.8. Descriptors uploaded to us in our role as authoritative dirserver

> Tor generates this event when it's an directory authority, and
> somebody has just uploaded a router descriptor.

> Syntax:
> > "650" "+" "AUTHDIR\_NEWDESCS" CRLF Action CRLF Message CRLF
> > > Descriptor CRLF "." CRLF "650" SP "OK" CRLF

> > Action = "ACCEPTED" / "DROPPED" / "REJECTED"
> > Message = Text


> The Descriptor field is the text of the router descriptor; the Action
> field is "ACCEPTED" if we're accepting the descriptor as the new
> best valid descriptor for its router, "REJECTED" if we aren't taking
> the descriptor and we're complaining to the uploading relay about
> it, and "DROPPED" if we decide to drop the descriptor without
> complaining.  The Message field is a human-readable string
> explaining why we chose the Action.  (It doesn't contain newlines.)

4.1.9. Our descriptor changed

> Syntax:
> > "650" SP "DESCCHANGED" CRLF


> [added in 0.1.2.2-alpha.](First.md)

4.1.10. Status events

> Status events (STATUS\_GENERAL, STATUS\_CLIENT, and STATUS\_SERVER) are sent
> based on occurrences in the Tor process pertaining to the general state of
> the program.  Generally, they correspond to log messages of severity Notice
> or higher.  They differ from log messages in that their format is a
> specified interface.

> Syntax:
> > "650" SP StatusType SP StatusSeverity SP StatusAction
> > > [StatusArguments](SP.md) CRLF


> StatusType = "STATUS\_GENERAL" / "STATUS\_CLIENT" / "STATUS\_SERVER"
> StatusSeverity = "NOTICE" / "WARN" / "ERR"
> StatusAction = 1\*ALPHA
> StatusArguments = StatusArgument **(SP StatusArgument)
> StatusArgument = StatusKeyword '=' StatusValue
> StatusKeyword = 1**(ALNUM / "**")
> StatusValue = 1_(ALNUM / '_')  / QuotedString**

> StatusAction is a string, and StatusArguments is a series of
> keyword=value pairs on the same line.  Values may be space-terminated
> strings, or quoted strings.

> These events are always produced with EXTENDED\_EVENTS and
> VERBOSE\_NAMES; see the explanations in the USEFEATURE section
> for details.

> Controllers MUST tolerate unrecognized actions, MUST tolerate
> unrecognized arguments, MUST tolerate missing arguments, and MUST
> tolerate arguments that arrive in any order.

> Each event description below is accompanied by a recommendation for
> controllers.  These recommendations are suggestions only; no controller
> is required to implement them.

> Compatibility note: versions of Tor before 0.2.0.22-rc incorrectly
> generated "STATUS\_SERVER" as "STATUS\_SEVER".  To be compatible with those
> versions, tools should accept both.

> Actions for STATUS\_GENERAL events can be as follows:

> CLOCK\_JUMPED
> "TIME=NUM"
> > Tor spent enough time without CPU cycles that it has closed all
> > its circuits and will establish them anew. This typically
> > happens when a laptop goes to sleep and then wakes up again. It
> > also happens when the system is swapping so heavily that Tor is
> > starving. The "time" argument specifies the number of seconds Tor
> > thinks it was unconscious for (or alternatively, the number of
> > seconds it went back in time).


> This status event is sent as NOTICE severity normally, but WARN
> severity if Tor is acting as a server currently.

> {Recommendation for controller: ignore it, since we don't really
> know what the user should do anyway. Hm.}

> DANGEROUS\_VERSION
> "CURRENT=version"
> "REASON=NEW/OBSOLETE/UNRECOMMENDED"
> "RECOMMENDED=\"version, version, ...\""
> > Tor has found that directory servers don't recommend its version of
> > the Tor software.  RECOMMENDED is a comma-and-space-separated string
> > of Tor versions that are recommended.  REASON is NEW if this version
> > of Tor is newer than any recommended version, OBSOLETE if
> > this version of Tor is older than any recommended version, and
> > UNRECOMMENDED if some recommended versions of Tor are newer and
> > some are older than this version. (The "OBSOLETE" reason was called
> > "OLD" from Tor 0.1.2.3-alpha up to and including 0.2.0.12-alpha.)


> {Controllers may want to suggest that the user upgrade OLD or
> UNRECOMMENDED versions.  NEW versions may be known-insecure, or may
> simply be development versions.}

> TOO\_MANY\_CONNECTIONS
> "CURRENT=NUM"
> > Tor has reached its ulimit -n or whatever the native limit is on file
> > descriptors or sockets.  CURRENT is the number of sockets Tor
> > currently has open.  The user should really do something about
> > this. The "current" argument shows the number of connections currently
> > open.


> {Controllers may recommend that the user increase the limit, or
> increase it for them.  Recommendations should be phrased in an
> OS-appropriate way and automated when possible.}

> BUG
> "REASON=STRING"
> > Tor has encountered a situation that its developers never expected,
> > and the developers would like to learn that it happened. Perhaps
> > the controller can explain this to the user and encourage her to
> > file a bug report?


> {Controllers should log bugs, but shouldn't annoy the user in case a
> bug appears frequently.}

> CLOCK\_SKEW
> > SKEW="+" / "-" SECONDS
> > MIN\_SKEW="+" / "-" SECONDS.
> > SOURCE="DIRSERV:" IP ":" Port /
> > > "NETWORKSTATUS:" IP ":" Port /
> > > "OR:" IP ":" Port /
> > > "CONSENSUS"
> > > If "SKEW" is present, it's an estimate of how far we are from the
> > > time declared in the source.  (In other words, if we're an hour in
> > > the past, the value is -3600.)  "MIN\_SKEW" is present, it's a lower
> > > bound.  If the source is a DIRSERV, we got the current time from a
> > > connection to a dirserver.  If the source is a NETWORKSTATUS, we
> > > decided we're skewed because we got a v2 networkstatus from far in
> > > the future.  If the source is OR, the skew comes from a NETINFO
> > > cell from a connection to another relay.  If the source is
> > > CONSENSUS, we decided we're skewed because we got a networkstatus
> > > consensus from the future.


> {Tor should send this message to controllers when it thinks the
> skew is so high that it will interfere with proper Tor operation.
> Controllers shouldn't blindly adjust the clock, since the more
> accurate source of skew info (DIRSERV) is currently
> unauthenticated.}

> BAD\_LIBEVENT
> "METHOD=" libevent method
> "VERSION=" libevent version
> "BADNESS=" "BROKEN" / "BUGGY" / "SLOW"
> "RECOVERED=" "NO" / "YES"
> > Tor knows about bugs in using the configured event method in this
> > version of libevent.  "BROKEN" libevents won't work at all;
> > "BUGGY" libevents might work okay; "SLOW" libevents will work
> > fine, but not quickly.  If "RECOVERED" is YES, Tor managed to
> > switch to a more reliable (but probably slower!) libevent method.


> {Controllers may want to warn the user if this event occurs, though
> generally it's the fault of whoever built the Tor binary and there's
> not much the user can do besides upgrade libevent or upgrade the
> binary.}

> DIR\_ALL\_UNREACHABLE
> > Tor believes that none of the known directory servers are
> > reachable -- this is most likely because the local network is
> > down or otherwise not working, and might help to explain for the
> > user why Tor appears to be broken.


> {Controllers may want to warn the user if this event occurs; further
> action is generally not possible.}

> CONSENSUS\_ARRIVED
> > Tor has received and validated a new consensus networkstatus.
> > (This event can be delayed a little while after the consensus
> > is received, if Tor needs to fetch certificates.)


> Actions for STATUS\_CLIENT events can be as follows:

> BOOTSTRAP
> "PROGRESS=" num
> "TAG=" Keyword
> "SUMMARY=" String
> ["WARNING=" String
> > "REASON=" Keyword
> > "COUNT=" num
> > "RECOMMENDATION=" Keyword

> ]

> Tor has made some progress at establishing a connection to the
> Tor network, fetching directory information, or making its first
> circuit; or it has encountered a problem while bootstrapping. This
> status event is especially useful for users with slow connections
> or with connectivity problems.

> "Progress" gives a number between 0 and 100 for how far through
> the bootstrapping process we are. "Summary" is a string that can
> be displayed to the user to describe the **next** task that Tor
> will tackle, i.e., the task it is working on after sending the
> status event. "Tag" is a string that controllers can use to
> recognize bootstrap phases, if they want to do something smarter
> than just blindly displaying the summary string; see Section 5
> for the current tags that Tor issues.

> The StatusSeverity describes whether this is a normal bootstrap
> phase (severity notice) or an indication of a bootstrapping
> problem (severity warn).

> For bootstrap problems, we include the same progress, tag, and
> summary values as we would for a normal bootstrap event, but we
> also include "warning", "reason", "count", and "recommendation"
> key/value combos. The "count" number tells how many bootstrap
> problems there have been so far at this phase. The "reason"
> string lists one of the reasons allowed in the ORCONN event. The
> "warning" argument string with any hints Tor has to offer about
> why it's having troubles bootstrapping.

> The "reason" values are long-term-stable controller-facing tags to
> identify particular issues in a bootstrapping step.  The warning
> strings, on the other hand, are human-readable. Controllers
> SHOULD NOT rely on the format of any warning string. Currently
> the possible values for "recommendation" are either "ignore" or
> "warn" -- if ignore, the controller can accumulate the string in
> a pile of problems to show the user if the user asks; if warn,
> the controller should alert the user that Tor is pretty sure
> there's a bootstrapping problem.

> Currently Tor uses recommendation=ignore for the first
> nine bootstrap problem reports for a given phase, and then
> uses recommendation=warn for subsequent problems at that
> phase. Hopefully this is a good balance between tolerating
> occasional errors and reporting serious problems quickly.

> ENOUGH\_DIR\_INFO
> > Tor now knows enough network-status documents and enough server
> > descriptors that it's going to start trying to build circuits now.


> {Controllers may want to use this event to decide when to indicate
> progress to their users, but should not interrupt the user's browsing
> to tell them so.}

> NOT\_ENOUGH\_DIR\_INFO
> > We discarded expired statuses and router descriptors to fall
> > below the desired threshold of directory information. We won't
> > try to build any circuits until ENOUGH\_DIR\_INFO occurs again.


> {Controllers may want to use this event to decide when to indicate
> progress to their users, but should not interrupt the user's browsing
> to tell them so.}

> CIRCUIT\_ESTABLISHED
> > Tor is able to establish circuits for client use. This event will
> > only be sent if we just built a circuit that changed our mind --
> > that is, prior to this event we didn't know whether we could
> > establish circuits.


> {Suggested use: controllers can notify their users that Tor is
> ready for use as a client once they see this status event. [Perhaps
> controllers should also have a timeout if too much time passes and
> this event hasn't arrived, to give tips on how to troubleshoot.
> On the other hand, hopefully Tor will send further status events
> if it can identify the problem.]}

> CIRCUIT\_NOT\_ESTABLISHED
> "REASON=" "EXTERNAL\_ADDRESS" / "DIR\_ALL\_UNREACHABLE" / "CLOCK\_JUMPED"
> > We are no longer confident that we can build circuits. The "reason"
> > keyword provides an explanation: which other status event type caused
> > our lack of confidence.


> {Controllers may want to use this event to decide when to indicate
> progress to their users, but should not interrupt the user's browsing
> to do so.}
> [Note: only REASON=CLOCK\_JUMPED is implemented currently.]

> DANGEROUS\_PORT
> "PORT=" port
> "RESULT=" "REJECT" / "WARN"
> > A stream was initiated to a port that's commonly used for
> > vulnerable-plaintext protocols. If the Result is "reject", we
> > refused the connection; whereas if it's "warn", we allowed it.


> {Controllers should warn their users when this occurs, unless they
> happen to know that the application using Tor is in fact doing so
> correctly (e.g., because it is part of a distributed bundle). They
> might also want some sort of interface to let the user configure
> their RejectPlaintextPorts and WarnPlaintextPorts config options.}

> DANGEROUS\_SOCKS
> "PROTOCOL=" "SOCKS4" / "SOCKS5"
> "ADDRESS=" IP:port
> > A connection was made to Tor's SOCKS port using one of the SOCKS
> > approaches that doesn't support hostnames -- only raw IP addresses.
> > If the client application got this address from gethostbyname(),
> > it may be leaking target addresses via DNS.


> {Controllers should warn their users when this occurs, unless they
> happen to know that the application using Tor is in fact doing so
> correctly (e.g., because it is part of a distributed bundle).}

> SOCKS\_UNKNOWN\_PROTOCOL
> > "DATA=string"
> > A connection was made to Tor's SOCKS port that tried to use it
> > for something other than the SOCKS protocol. Perhaps the user is
> > using Tor as an HTTP proxy?   The DATA is the first few characters
> > sent to Tor on the SOCKS port.


> {Controllers may want to warn their users when this occurs: it
> indicates a misconfigured application.}

> SOCKS\_BAD\_HOSTNAME
> > "HOSTNAME=QuotedString"
> > > Some application gave us a funny-looking hostname. Perhaps
> > > it is broken? In any case it won't work with Tor and the user
> > > should know.


> {Controllers may want to warn their users when this occurs: it
> usually indicates a misconfigured application.}

> Actions for STATUS\_SERVER can be as follows:

> EXTERNAL\_ADDRESS
> "ADDRESS=IP"
> "HOSTNAME=NAME"
> "METHOD=CONFIGURED/DIRSERV/RESOLVED/INTERFACE/GETHOSTNAME"
> > Our best idea for our externally visible IP has changed to 'IP'.
> > If 'HOSTNAME' is present, we got the new IP by resolving 'NAME'.  If the
> > method is 'CONFIGURED', the IP was given verbatim as a configuration
> > option.  If the method is 'RESOLVED', we resolved the Address
> > configuration option to get the IP.  If the method is 'GETHOSTNAME',
> > we resolved our hostname to get the IP.  If the method is 'INTERFACE',
> > we got the address of one of our network interfaces to get the IP.  If
> > the method is 'DIRSERV', a directory server told us a guess for what
> > our IP might be.


> {Controllers may want to record this info and display it to the user.}

> CHECKING\_REACHABILITY
> "ORADDRESS=IP:port"
> "DIRADDRESS=IP:port"
> > We're going to start testing the reachability of our external OR port
> > or directory port.


> {This event could affect the controller's idea of server status, but
> the controller should not interrupt the user to tell them so.}

> REACHABILITY\_SUCCEEDED
> "ORADDRESS=IP:port"
> "DIRADDRESS=IP:port"
> > We successfully verified the reachability of our external OR port or
> > directory port (depending on which of ORADDRESS or DIRADDRESS is
> > given.)


> {This event could affect the controller's idea of server status, but
> the controller should not interrupt the user to tell them so.}

> GOOD\_SERVER\_DESCRIPTOR
> > We successfully uploaded our server descriptor to at least one
> > of the directory authorities, with no complaints.


> {Originally, the goal of this event was to declare "every authority
> has accepted the descriptor, so there will be no complaints
> about it." But since some authorities might be offline, it's
> harder to get certainty than we had thought. As such, this event
> is equivalent to ACCEPTED\_SERVER\_DESCRIPTOR below. Controllers
> should just look at ACCEPTED\_SERVER\_DESCRIPTOR and should ignore
> this event for now.}

> SERVER\_DESCRIPTOR\_STATUS
> "STATUS=" "LISTED" / "UNLISTED"
> > We just got a new networkstatus consensus, and whether we're in
> > it or not in it has changed. Specifically, status is "listed"
> > if we're listed in it but previous to this point we didn't know
> > we were listed in a consensus; and status is "unlisted" if we
> > thought we should have been listed in it (e.g. we were listed in
> > the last one), but we're not.


> {Moving from listed to unlisted is not necessarily cause for
> alarm. The relay might have failed a few reachability tests,
> or the Internet might have had some routing problems. So this
> feature is mainly to let relay operators know when their relay
> has successfully been listed in the consensus.}

> [implemented yet. We should do this in 0.2.2.x. -RD](Not.md)

> NAMESERVER\_STATUS
> "NS=addr"
> "STATUS=" "UP" / "DOWN"
> "ERR=" message
> > One of our nameservers has changed status.


> {This event could affect the controller's idea of server status, but
> the controller should not interrupt the user to tell them so.}

> NAMESERVER\_ALL\_DOWN
> > All of our nameservers have gone down.


> {This is a problem; if it happens often without the nameservers
> coming up again, the user needs to configure more or better
> nameservers.}

> DNS\_HIJACKED
> > Our DNS provider is providing an address when it should be saying
> > "NOTFOUND"; Tor will treat the address as a synonym for "NOTFOUND".


> {This is an annoyance; controllers may want to tell admins that their
> DNS provider is not to be trusted.}

> DNS\_USELESS
> > Our DNS provider is giving a hijacked address instead of well-known
> > websites; Tor will not try to be an exit node.


> {Controllers could warn the admin if the relay is running as an
> exit node: the admin needs to configure a good DNS server.
> Alternatively, this happens a lot in some restrictive environments
> (hotels, universities, coffeeshops) when the user hasn't registered.}

> BAD\_SERVER\_DESCRIPTOR
> "DIRAUTH=addr:port"
> "REASON=string"
> > A directory authority rejected our descriptor.  Possible reasons
> > include malformed descriptors, incorrect keys, highly skewed clocks,
> > and so on.


> {Controllers should warn the admin, and try to cope if they can.}

> ACCEPTED\_SERVER\_DESCRIPTOR
> "DIRAUTH=addr:port"
> > A single directory authority accepted our descriptor.
> > // actually notice


> {This event could affect the controller's idea of server status, but
> the controller should not interrupt the user to tell them so.}

> REACHABILITY\_FAILED
> "ORADDRESS=IP:port"
> "DIRADDRESS=IP:port"
> > We failed to connect to our external OR port or directory port
> > successfully.


> {This event could affect the controller's idea of server status.  The
> controller should warn the admin and suggest reasonable steps to take.}

4.1.11. Our set of guard nodes has changed

> Syntax:
> > "650" SP "GUARD" SP Type SP Name SP Status ... CRLF
> > Type = "ENTRY"
> > Name = ServerSpec
> > > (Identifies the guard affected)

> > Status = "NEW" | "UP" | "DOWN" | "BAD" | "GOOD" | "DROPPED"


> The ENTRY type indicates a guard used for connections to the Tor
> network.

> The Status values are:
> > "NEW"  -- This node was not previously used as a guard; now we have
> > > picked it as one.

> > "DROPPED" -- This node is one we previously picked as a guard; we
> > > no longer consider it to be a member of our guard list.

> > "UP"   -- The guard now seems to be reachable.
> > "DOWN" -- The guard now seems to be unreachable.
> > "BAD"  -- Because of flags set in the consensus and/or values in the
> > > configuration, this node is now unusable as a guard.

> > "GOOD" -- Because of flags set in the consensus and/or values in the
> > > configuration, this node is now usable as a guard.


> Controllers must accept unrecognized types and unrecognized statuses.

4.1.12. Network status has changed

> Syntax:
> > "650" "+" "NS" CRLF 1\*NetworkStatus "." CRLF "650" SP "OK" CRLF


> The event is used whenever our local view of a relay status changes.
> This happens when we get a new v3 consensus (in which case the entries
> we see are a duplicate of what we see in the NEWCONSENSUS event,
> below), but it also happens when we decide to mark a relay as up or
> down in our local status, for example based on connection attempts.

> [added in 0.1.2.3-alpha](First.md)

4.1.13. Bandwidth used on an application stream

> The syntax is:
> > "650" SP "STREAM\_BW" SP StreamID SP BytesWritten SP BytesRead CRLF
> > BytesWritten = 1\*DIGIT
> > BytesRead = 1\*DIGIT


> BytesWritten and BytesRead are the number of bytes written and read
> by the application since the last STREAM\_BW event on this stream.

> Note that from Tor's perspective, **reading** a byte on a stream means
> that the application **wrote** the byte. That's why the order of "written"
> vs "read" is opposite for stream\_bw events compared to bw events.

> These events are generated about once per second per stream; no events
> are generated for streams that have not written or read. These events
> apply only to streams entering Tor (such as on a SOCKSPort, TransPort,
> or so on). They are not generated for exiting streams.

4.1.14. Per-country client stats

> The syntax is:
> > "650" SP "CLIENTS\_SEEN" SP TimeStarted SP CountrySummary SP
> > IPVersions CRLF


> We just generated a new summary of which countries we've seen clients
> from recently. The controller could display this for the user, e.g.
> in their "relay" configuration window, to give them a sense that they
> are actually being useful.

> Currently only bridge relays will receive this event, but once we figure
> out how to sufficiently aggregate and sanitize the client counts on
> main relays, we might start sending these events in other cases too.

> TimeStarted is a quoted string indicating when the reported summary
> counts from (in UTCS).

> The CountrySummary keyword has as its argument a comma-separated,
> possibly empty set of "countrycode=count" pairs. For example (without
> linebreak),
> 650-CLIENTS\_SEEN TimeStarted="2008-12-25 23:50:43"
> CountrySummary=us=16,de=8,uk=8

> The IPVersions keyword has as its argument a comma-separated set of
> "protocol-family=count" pairs. For example,
> IPVersions=v4=16,v6=40

4.1.15. New consensus networkstatus has arrived

> The syntax is:
> > "650" "+" "NEWCONSENSUS" CRLF 1\*NetworkStatus "." CRLF "650" SP
> > "OK" CRLF


> A new consensus networkstatus has arrived. We include NS-style lines for
> every relay in the consensus. NEWCONSENSUS is a separate event from the
> NS event, because the list here represents every usable relay: so any
> relay **not** mentioned in this list is implicitly no longer recommended.

> [added in 0.2.1.13-alpha](First.md)

4.1.16. New circuit buildtime has been set

> The syntax is:
> > "650" SP "BUILDTIMEOUT\_SET" SP Type SP "TOTAL\_TIMES=" Total SP
> > > "TIMEOUT\_MS=" Timeout SP "XM=" Xm SP "ALPHA=" Alpha SP
> > > "CUTOFF\_QUANTILE=" Quantile SP "TIMEOUT\_RATE=" TimeoutRate SP
> > > "CLOSE\_MS=" CloseTimeout SP "CLOSE\_RATE=" CloseRate
> > > CRLF

> > Type = "COMPUTED" / "RESET" / "SUSPENDED" / "DISCARD" / "RESUME"
> > Total = Integer count of timeouts stored
> > Timeout = Integer timeout in milliseconds
> > Xm = Estimated integer Pareto parameter Xm in milliseconds
> > Alpha = Estimated floating point Paredo paremter alpha
> > Quantile = Floating point CDF quantile cutoff point for this timeout
> > TimeoutRate = Floating point ratio of circuits that timeout
> > CloseTimeout = How long to keep measurement circs in milliseconds
> > CloseRate = Floating point ratio of measurement circuits that are closed


> A new circuit build timeout time has been set. If Type is "COMPUTED",
> Tor has computed the value based on historical data. If Type is "RESET",
> initialization or drastic network changes have caused Tor to reset
> the timeout back to the default, to relearn again. If Type is
> "SUSPENDED", Tor has detected a loss of network connectivity and has
> temporarily changed the timeout value to the default until the network
> recovers. If type is "DISCARD", Tor has decided to discard timeout
> values that likely happened while the network was down. If type is
> "RESUME", Tor has decided to resume timeout calculation.

> The Total value is the count of circuit build times Tor used in
> computing this value. It is capped internally at the maximum number
> of build times Tor stores (NCIRCUITS\_TO\_OBSERVE).

> The Timeout itself is provided in milliseconds. Internally, Tor rounds
> this value to the nearest second before using it.

> [added in 0.2.2.7-alpha](First.md)

4.1.17. Signal received

> The syntax is:
> > "650" SP "SIGNAL" SP Signal CRLF


> Signal = "RELOAD" / "DUMP" / "DEBUG" / "NEWNYM" / "CLEARDNSCACHE"

> A signal has been received and actions taken by Tor. The meaning of each
> signal, and the mapping to Unix signals, is as defined in section 3.7.
> Future versions of Tor MAY generate signals other than those listed here;
> controllers MUST be able to accept them.

> If Tor chose to ignore a signal (such as NEWNYM), this event will not be
> sent.  Note that some options (like ReloadTorrcOnSIGHUP) may affect the
> semantics of the signals here.

> Note that the HALT (SIGTERM) and SHUTDOWN (SIGINT) signals do not currently
> generate any event.

> [added in 0.2.3.1-alpha](First.md)

4.1.18. Configuration changed

> The syntax is:
> > StartReplyLine **(MidReplyLine) EndReplyLine**


> StartReplyLine = "650-CONF\_CHANGED" CRLF
> MidReplyLine = "650-" KEYWORD ["=" VALUE] CRLF
> EndReplyLine = "650 OK"

> Tor configuration options have changed (such as via a SETCONF or RELOAD
> signal). KEYWORD and VALUE specify the configuration option that was changed.
> Undefined configuration options contain only the KEYWORD.

4.1.19. Circuit status changed slightly

> The syntax is:

> "650" SP "CIRC\_MINOR" SP CircuitID SP CircEvent [Path](SP.md)
> > ["BUILD\_FLAGS=" BuildFlags](SP.md) ["PURPOSE=" Purpose](SP.md)
> > ["HS\_STATE=" HSState](SP.md) ["REND\_QUERY=" HSAddress](SP.md)
> > ["TIME\_CREATED=" TimeCreated](SP.md)
> > ["OLD\_PURPOSE=" Purpose [SP "OLD\_HS\_STATE=" HSState](SP.md)] CRLF


> CircEvent =
> > "PURPOSE\_CHANGED" / ; circuit purpose or HS-related state changed
> > "CANNIBALIZED"      ; circuit cannibalized


> Clients MUST accept circuit events not listed above.

> The "OLD\_PURPOSE" field is provided for both PURPOSE\_CHANGED and
> CANNIBALIZED events.  The "OLD\_HS\_STATE" field is provided whenever
> the "OLD\_PURPOSE" field is provided and is a hidden-service-related
> purpose.

> Other fields are as specified in section 4.1.1 above.

> [added in 0.2.3.11-alpha](First.md)

4.1.20. Pluggable transport launched

> The syntax is:

> "650" SP "TRANSPORT\_LAUNCHED" SP Type SP Name SP TransportAddress SP Port
> Type = "server" | "client"
> Name = The name of the pluggable transport
> TransportAddress = An IPv4 or IPv6 address on which the pluggable
> > transport is listening for connections

> Port = The TCP port on which it is listening for connections.

> A pluggable transport called 'Name' of type 'Type' was launched
> successfully and is now listening for connections on 'Address':'Port'.

4.1.21. Bandwidth used on an OR or DIR or EXIT connection

> The syntax is:
> > "650" SP "CONN\_BW" SP "ID=" ConnID SP "TYPE=" ConnType
> > > SP "READ=" BytesRead SP "WRITTEN=" BytesWritten CRLF


> ConnType = "OR" /  ; Carrying traffic within the tor network. This can
> > either be our own (client) traffic or traffic we're
> > relaying within the network.
> > "DIR" / ; Fetching tor descriptor data, or transmitting
> > > descriptors we're mirroring.

> > "EXIT"  ; Carrying traffic between the tor network and an
> > > external destination.


> BytesRead = 1\*DIGIT
> BytesWritten = 1\*DIGIT

> Controllers MUST tolerate unrecognized connection types.

> BytesWritten and BytesRead are the number of bytes written and read
> by Tor since the last CONN\_BW event on this connection.

> These events are generated about once per second per connection; no
> events are generated for connections that have not read or written.
> These events are only generated if TestingTorNetwork is set.

> [added in 0.2.5.2-alpha](First.md)

4.1.22. Bandwidth used by all streams attached to a circuit

> The syntax is:
> > "650" SP "CIRC\_BW" SP "ID=" CircuitID SP "READ=" BytesRead SP
> > > "WRITTEN=" BytesWritten CRLF

> > BytesRead = 1\*DIGIT
> > BytesWritten = 1\*DIGIT


> BytesRead and BytesWritten are the number of bytes read and written by
> all applications with streams attached to this circuit since the last
> CIRC\_BW event.

> These events are generated about once per second per circuit; no events
> are generated for circuits that had no attached stream writing or
> reading.

> [added in 0.2.5.2-alpha](First.md)

4.1.23. Per-circuit cell stats

> The syntax is:
> > "650" SP "CELL\_STATS"
> > > [SP "ID=" CircuitID ](.md)
> > > [SP "InboundQueue=" QueueID SP "InboundConn=" ConnID ](.md)
> > > [SP "InboundAdded=" CellsByType ](.md)
> > > [ SP "InboundRemoved=" CellsByType SP
> > > > "InboundTime=" MsecByType ]

> > > [SP "OutboundQueue=" QueueID SP "OutboundConn=" ConnID ](.md)
> > > [SP "OutboundAdded=" CellsByType ](.md)
> > > [ SP "OutboundRemoved=" CellsByType SP
> > > > "OutboundTime=" MsecByType ] CRLF

> > CellsByType, MsecByType = CellType ":" 1\*DIGIT
> > > 0**( "," CellType ":" 1\*DIGIT )

> > CellType = 1**( "a" - "z" / "0" - "9" / "_" )_


> Examples are:
> > 650 CELL\_STATS ID=14 OutboundQueue=19403 OutboundConn=15
> > > OutboundAdded=create\_fast:1,relay\_early:2
> > > OutboundRemoved=create\_fast:1,relay\_early:2
> > > OutboundTime=create\_fast:0,relay\_early:0

> > 650 CELL\_STATS InboundQueue=19403 InboundConn=32
> > > InboundAdded=relay:1,created\_fast:1
> > > InboundRemoved=relay:1,created\_fast:1
> > > InboundTime=relay:0,created\_fast:0
> > > OutboundQueue=6710 OutboundConn=18
> > > OutboundAdded=create:1,relay\_early:1
> > > OutboundRemoved=create:1,relay\_early:1
> > > OutboundTime=create:0,relay\_early:0


> ID is the locally unique circuit identifier that is only included if the
> circuit originates at this node.

> Inbound and outbound refer to the direction of cell flow through the
> circuit which is either to origin (inbound) or from origin (outbound).

> InboundQueue and OutboundQueue are identifiers of the inbound and
> outbound circuit queues of this circuit.  These identifiers are only
> unique per OR connection.  OutboundQueue is chosen by this node and
> matches InboundQueue of the next node in the circuit.

> InboundConn and OutboundConn are locally unique IDs of inbound and
> outbound OR connection.  OutboundConn does not necessarily match
> InboundConn of the next node in the circuit.

> InboundQueue and InboundConn are not present if the circuit originates
> at this node.  OutboundQueue and OutboundConn are not present if the
> circuit (currently) ends at this node.

> InboundAdded and OutboundAdded are total number of cells by cell type
> added to inbound and outbound queues.  Only present if at least one cell
> was added to a queue.

> InboundRemoved and OutboundRemoved are total number of cells by
> cell type processed from inbound and outbound queues.  InboundTime and
> OutboundTime are total waiting times in milliseconds of all processed
> cells by cell type.  Only present if at least one cell was removed from
> a queue.

> These events are generated about once per second per circuit; no
> events are generated for circuits that have not added or processed any
> cell.  These events are only generated if TestingTorNetwork is set.

> [added in 0.2.5.2-alpha](First.md)

4.1.24. Token buckets refilled

> The syntax is:
> > "650" SP "TB\_EMPTY" SP BucketName [SP "ID=" ConnID ](.md) SP
> > > "READ=" ReadBucketEmpty SP "WRITTEN=" WriteBucketEmpty SP
> > > "LAST=" LastRefill CRLF


> BucketName = "GLOBAL" / "RELAY" / "ORCONN"
> ReadBucketEmpty = 1\*DIGIT
> WriteBucketEmpty = 1\*DIGIT
> LastRefill = 1\*DIGIT

> Examples are:
> > 650 TB\_EMPTY ORCONN ID=16 READ=0 WRITTEN=0 LAST=100
> > 650 TB\_EMPTY GLOBAL READ=93 WRITTEN=93 LAST=100
> > 650 TB\_EMPTY RELAY READ=93 WRITTEN=93 LAST=100


> This event is generated when refilling a previously empty token
> bucket.  BucketNames "GLOBAL" and "RELAY" keywords are used for the
> global or relay token buckets, BucketName "ORCONN" is used for the
> token buckets of an OR connection.  Controllers MUST tolerate
> unrecognized bucket names.

> ConnID is only included if the BucketName is "ORCONN".

> If both global and relay buckets and/or the buckets of one or more OR
> connections run out of tokens at the same time, multiple separate
> events are generated.

> ReadBucketEmpty (WriteBucketEmpty) is the time in millis that the read
> (write) bucket was empty since the last refill.  LastRefill is the
> time in millis since the last refill.

> If a bucket went negative and if refilling tokens didn't make it go
> positive again, there will be multiple consecutive TB\_EMPTY events for
> each refill interval during which the bucket contained zero tokens or
> less.  In such a case, ReadBucketEmpty or WriteBucketEmpty are capped
> at LastRefill in order not to report empty times more than once.

> These events are only generated if TestingTorNetwork is set.

> [added in 0.2.5.2-alpha](First.md)

5. Implementation notes

5.1. Authentication

> If the control port is open and no authentication operation is enabled, Tor
> trusts any local user that connects to the control port.  This is generally
> a poor idea.

> If the 'CookieAuthentication' option is true, Tor writes a "magic
> cookie" file named "control\_auth\_cookie" into its data directory (or
> to another file specified in the 'CookieAuthFile' option).  To
> authenticate, the controller must demonstrate that it can read the
> contents of the cookie file:

  * Current versions of Tor support cookie authentication
> > using the "COOKIE" authentication method: the controller sends the
> > contents of the cookie file, encoded in hexadecimal.  This
> > authentication method exposes the user running a controller to an
> > unintended information disclosure attack whenever the controller
> > has greater filesystem read access than the process that it has
> > connected to.  (Note that a controller may connect to a process
> > other than Tor.)  It is almost never safe to use, even if the
> > controller's user has explicitly specified which filename to read
> > an authentication cookie from.  For this reason, the COOKIE
> > authentication method has been deprecated and will be removed from
> > Tor before some future version of Tor.

  * 0.2.2.x versions of Tor starting with 0.2.2.36, and all versions of
> > Tor after 0.2.3.12-alpha, support cookie authentication using the
> > "SAFECOOKIE" authentication method, which discloses much less
> > information about the contents of the cookie file.


> If the 'HashedControlPassword' option is set, it must contain the salted
> hash of a secret password.  The salted hash is computed according to the
> S2K algorithm in RFC 2440 (OpenPGP), and prefixed with the s2k specifier.
> This is then encoded in hexadecimal, prefixed by the indicator sequence
> "16:".  Thus, for example, the password 'foo' could encode to:
    1. :660537E3E1CD49996044A3BF558097A981F539FEA2F9DA662B4626C1C2
> > > ++++++++++++++++<sup>^</sup><sup>^</sup><sup>^</sup><sup>^</sup><sup>^</sup><sup>^</sup><sup>^</sup><sup>^</sup><sup>^</sup><sup>^</sup><sup>^</sup><sup>^</sup><sup>^</sup>^
> > > > salt                       hashed value
> > > > > indicator

> You can generate the salt of a password by calling
> > 'tor --hash-password 

&lt;password&gt;

'

> or by using the example code in the Python and Java controller libraries.
> To authenticate under this scheme, the controller sends Tor the original
> secret that was used to generate the password, either as a quoted string
> or encoded in hexadecimal.

5.2. Don't let the buffer get too big.

> If you ask for lots of events, and 16MB of them queue up on the buffer,
> the Tor process will close the socket.

5.3. Backward compatibility with v0 control protocol.

> The 'version 0' control protocol was replaced in Tor 0.1.1.x. Support
> was removed in Tor 0.2.0.x. Every non-obsolete version of Tor now
> supports the version 1 control protocol.

> For backward compatibility with the "version 0" control protocol,
> Tor used to check whether the third octet of the first command is zero.
> (If it was, Tor assumed that version 0 is in use.)

> This compatibility was removed in Tor 0.1.2.16 and 0.2.0.4-alpha.

5.4. Tor config options for use by controllers

> Tor provides a few special configuration options for use by controllers.
> These options can be set and examined by the SETCONF and GETCONF commands,
> but are not saved to disk by SAVECONF.

> Generally, these options make Tor unusable by disabling a portion of Tor's
> normal operations.  Unless a controller provides replacement functionality
> to fill this gap, Tor will not correctly handle user requests.

> AllDirActionsPrivate

> If true, Tor will try to launch all directory operations through
> anonymous connections.  (Ordinarily, Tor only tries to anonymize
> requests related to hidden services.)  This option will slow down
> directory access, and may stop Tor from working entirely if it does not
> yet have enough directory information to build circuits.

> (Boolean. Default: "0".)

> DisablePredictedCircuits

> If true, Tor will not launch preemptive "general-purpose" circuits for
> streams to attach to.  (It will still launch circuits for testing and
> for hidden services.)

> (Boolean. Default: "0".)

> LeaveStreamsUnattached

> If true, Tor will not automatically attach new streams to circuits;
> instead, the controller must attach them with ATTACHSTREAM.  If the
> controller does not attach the streams, their data will never be routed.

> (Boolean. Default: "0".)

> HashedControlSessionPassword

> As HashedControlPassword, but is not saved to the torrc file by
> SAVECONF.  Added in Tor 0.2.0.20-rc.

> ReloadTorrcOnSIGHUP

> If this option is true (the default), we reload the torrc from disk
> every time we get a SIGHUP (from the controller or via a signal).
> Otherwise, we don't.  This option exists so that controllers can keep
> their options from getting overwritten when a user sends Tor a HUP for
> some other reason (for example, to rotate the logs).

> (Boolean.  Default: "1")

> OwningControllerProcess

> If this option is set to a process ID, Tor will periodically check
> whether a process with the specified PID exists, and exit if one
> does not.  Added in Tor 0.2.2.28-beta.  This option's intended use
> is documented in section 3.23 with the related TAKEOWNERSHIP
> command.

> Note that this option can only specify a single process ID, unlike
> the TAKEOWNERSHIP command which can be sent along multiple control
> connections.

> (String.  Default: unset.)

5.5. Phases from the Bootstrap status event.

> This section describes the various bootstrap phases currently reported
> by Tor. Controllers should not assume that the percentages and tags
> listed here will continue to match up, or even that the tags will stay
> in the same order. Some phases might also be skipped (not reported)
> if the associated bootstrap step is already complete, or if the phase
> no longer is necessary. Only "starting" and "done" are guaranteed to
> exist in all future versions.

> Current Tor versions enter these phases in order, monotonically.
> Future Tors MAY revisit earlier stages.

> Phase 0:
> tag=starting summary="Starting"

> Tor starts out in this phase.

> Phase 5:
> tag=conn\_dir summary="Connecting to directory mirror"

> Tor sends this event as soon as Tor has chosen a directory mirror --
> e.g. one of the authorities if bootstrapping for the first time or
> after a long downtime, or one of the relays listed in its cached
> directory information otherwise.

> Tor will stay at this phase until it has successfully established
> a TCP connection with some directory mirror. Problems in this phase
> generally happen because Tor doesn't have a network connection, or
> because the local firewall is dropping SYN packets.

> Phase 10:
> tag=handshake\_dir summary="Finishing handshake with directory mirror"

> This event occurs when Tor establishes a TCP connection with a relay used
> as a directory mirror (or its https proxy if it's using one). Tor remains
> in this phase until the TLS handshake with the relay is finished.

> Problems in this phase generally happen because Tor's firewall is
> doing more sophisticated MITM attacks on it, or doing packet-level
> keyword recognition of Tor's handshake.

> Phase 15:
> tag=onehop\_create summary="Establishing one-hop circuit for dir info"

> Once TLS is finished with a relay, Tor will send a CREATE\_FAST cell
> to establish a one-hop circuit for retrieving directory information.
> It will remain in this phase until it receives the CREATED\_FAST cell
> back, indicating that the circuit is ready.

> Phase 20:
> tag=requesting\_status summary="Asking for networkstatus consensus"

> Once we've finished our one-hop circuit, we will start a new stream
> for fetching the networkstatus consensus. We'll stay in this phase
> until we get the 'connected' relay cell back, indicating that we've
> established a directory connection.

> Phase 25:
> tag=loading\_status summary="Loading networkstatus consensus"

> Once we've established a directory connection, we will start fetching
> the networkstatus consensus document. This could take a while; this
> phase is a good opportunity for using the "progress" keyword to indicate
> partial progress.

> This phase could stall if the directory mirror we picked doesn't
> have a copy of the networkstatus consensus so we have to ask another,
> or it does give us a copy but we don't find it valid.

> Phase 40:
> tag=loading\_keys summary="Loading authority key certs"

> Sometimes when we've finished loading the networkstatus consensus,
> we find that we don't have all the authority key certificates for the
> keys that signed the consensus. At that point we put the consensus we
> fetched on hold and fetch the keys so we can verify the signatures.

> Phase 45
> tag=requesting\_descriptors summary="Asking for relay descriptors"

> Once we have a valid networkstatus consensus and we've checked all
> its signatures, we start asking for relay descriptors. We stay in this
> phase until we have received a 'connected' relay cell in response to
> a request for descriptors.

> Phase 50:
> tag=loading\_descriptors summary="Loading relay descriptors"

> We will ask for relay descriptors from several different locations,
> so this step will probably make up the bulk of the bootstrapping,
> especially for users with slow connections. We stay in this phase until
> we have descriptors for at least 1/4 of the usable relays listed in
> the networkstatus consensus. This phase is also a good opportunity to
> use the "progress" keyword to indicate partial steps.

> Phase 80:
> tag=conn\_or summary="Connecting to entry guard"

> Once we have a valid consensus and enough relay descriptors, we choose
> some entry guards and start trying to build some circuits. This step
> is similar to the "conn\_dir" phase above; the only difference is
> the context.

> If a Tor starts with enough recent cached directory information,
> its first bootstrap status event will be for the conn\_or phase.

> Phase 85:
> tag=handshake\_or summary="Finishing handshake with entry guard"

> This phase is similar to the "handshake\_dir" phase, but it gets reached
> if we finish a TCP connection to a Tor relay and we have already reached
> the "conn\_or" phase. We'll stay in this phase until we complete a TLS
> handshake with a Tor relay.

> Phase 90:
> tag=circuit\_create summary="Establishing circuits"

> Once we've finished our TLS handshake with an entry guard, we will
> set about trying to make some 3-hop circuits in case we need them soon.

> Phase 100:
> tag=done summary="Done"

> A full 3-hop exit circuit has been established. Tor is ready to handle
> application connections now.