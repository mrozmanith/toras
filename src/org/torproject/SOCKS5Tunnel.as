package org.torproject {
	
	import air.net.SocketMonitor;
	import flash.events.EventDispatcher;
	import flash.net.Socket;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.events.IOErrorEvent;	
	import flash.events.SecurityErrorEvent;
	import flash.utils.ByteArray;
	import org.torproject.events.SOCKS5TunnelEvent;
	import org.torproject.model.HTTPResponse;
	import org.torproject.model.HTTPResponseHeader;
	import org.torproject.model.SOCKS5Model;
	import flash.net.URLRequest;
	import flash.net.URLRequestDefaults;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import org.torproject.utils.URLUtil;	
	import org.torproject.TorControl;	
	
	/**
	 * Provides SOCKS5-capable transport services for proxied network requests. This protocol is also used by Tor to transport
	 * various network requests.
	 * 
	 * Since TorControl is used to manage the Tor services process, if this process is already correctly configured and running
	 * SOCKS5Tunnel can be used completely independently (TorControl may be entirely omitted).
	 * 
	 * @author Patrick Bay
	 */
	public class SOCKS5Tunnel extends EventDispatcher {
		
		private var _tunnelSocket:Socket = null;
		private var _tunnelIP:String = null;
		private var _tunnelPort:int = -1;
		private var _connectionType:int = -1;
		private var _connected:Boolean = false;
		private var _authenticated:Boolean = false;
		private var _tunneled:Boolean = false;		
		private var _requestActive:Boolean = false;
		private var _urlRequestBuffer:Vector.<URLRequest> = new Vector.<URLRequest>();
		private var _responseBuffer:ByteArray = new ByteArray();
		private var _HTTPStatusReceived:Boolean = false;
		private var _HTTPHeadersReceived:Boolean = false;
		private var _HTTPResponse:HTTPResponse;		
		private var _currentRequest:URLRequest;
		
		/**
		 * Creates an instance of a SOCKS5 proxy tunnel.
		 * 
		 * @param	tunnelIP The SOCKS proxy IP to use. If not specified, the current settings in TorControl are used by default.
		 * @param	tunnelPort The SOCKS proxy port to use. If not specified, the current settings in TorControl are used by default.
		 */
		public function SOCKS5Tunnel(tunnelIP:String=null, tunnelPort:int=-1) {
			if ((tunnelIP == null) || (tunnelIP == "")) {
				this._tunnelIP = TorControl.SOCKSIP;
			}//if
			if (tunnelPort < 1) {
				this._tunnelPort = TorControl.SOCKSPort;
			}//if
		}//constructor
		
		/**
		 * The current SOCKS proxy tunnel IP being used by the instance.
		 */
		public function get tunnelIP():String {
			return (this._tunnelIP);
		}//get tunnelIP
		
		/**
		 * The current SOCKS proxy tunnel port being used by the instance.
		 */
		public function get tunnelPort():int {
			return (this._tunnelPort);
		}//get tunnelPort
		
		/**
		 * The tunnel connection type being managed by this instance.
		 */
		public function get connectionType():int {
			return (this._connectionType);
		}//get connectionType
		
		/**
		 * The status of the tunnel connection (true=connected, false=not connected). Requests
		 * cannot be sent through the proxy unless it is both connected and tunneled.
		 */
		public function get connected():Boolean {
			return (this._connected);
		}//get connected
		
		/**
		 * The status of the proxy tunnel (true=ready, false=not ready). Requests
		 * cannot be sent through the proxy unless it is both connected and tunneled.
		 */
		public function get tunneled():Boolean {
			return (this._tunneled);
		}//get tunneled
		
		/**
		 * Attempts to connect to the SOCKS tunnel connection using the settings supplied to the instance.
		 * 
		 * @param connType The type of connection to open for this tunnel proxy connection (defaults to 1 - TCP/IP stream). See SOCKS5Model.SOCKS5_conn_* properties
		 * for valid values.
		 */
		public function connect(connType:int = 1):void {
			
		}//connect
		
		/**
		 * Sends a HTTP request through the socks proxy, sending any included information (such as form data) in the process. Additional
		 * requests via this tunnel connection will be disallowed until this one has completed (since replies may be multi-part).
		 * 
		 * @param request The URLRequest object holding the necessary information for the request.
		 * 
		 * @return True if the request was dispatched successfully, false otherwise.
		 */
		public function loadHTTP(request:URLRequest):Boolean {
			if (request == null) {
				return (false);
			}//if			
			this._urlRequestBuffer.push(request);
			this._responseBuffer = new ByteArray();
			this._connected = false;
			this._authenticated = false;
			this._tunneled = false;		
			this._HTTPStatusReceived = false;
			this._HTTPHeadersReceived = false;
			if (this._tunnelSocket != null) {
				this._tunnelSocket.removeEventListener(ProgressEvent.SOCKET_DATA, this.onTunnelData);
				this._tunnelSocket.close();
				this._tunnelSocket = null;
			}//if
			this._HTTPResponse = new HTTPResponse();
			this._connectionType = SOCKS5Model.SOCKS5_conn_TCPIPSTREAM;
			this._tunnelSocket = new Socket(this.tunnelIP, this.tunnelPort);
			this._tunnelSocket.addEventListener(Event.CONNECT, this.onTunnelConnect);
			this._tunnelSocket.addEventListener(Event.CLOSE, this.onTunnelDisconnect);
			return (true);
		}//loadHTTP			
		
		private function onTunnelConnect(eventObj:Event):void {			
			trace ("SOCKS5Tunnel connected to \"" + this.tunnelIP + "\" on port " + this.tunnelPort);
			this._connected = true;
			this._tunnelSocket.removeEventListener(Event.CONNECT, this.onTunnelConnect);			
			this._tunnelSocket.addEventListener(ProgressEvent.SOCKET_DATA, this.onTunnelData);			
			var connectEvent:SOCKS5TunnelEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONCONNECT);
			this.dispatchEvent(connectEvent);
			this.authenticateTunnel();
		}//onTunnelData	
		
		private function onTunnelDisconnect(eventObj:Event):void {			
			trace ("SOCKS5Tunnel disconnected from \"" + this.tunnelIP + "\" on port " + this.tunnelPort);
			this._connected = false;
			this._authenticated = false;
			this._tunneled = false;
			this._tunnelSocket.removeEventListener(Event.CONNECT, this.onTunnelConnect);
			this._tunnelSocket.removeEventListener(Event.CLOSE, this.onTunnelDisconnect);
			this._tunnelSocket.addEventListener(ProgressEvent.SOCKET_DATA, this.onTunnelData);
			var connectEvent:SOCKS5TunnelEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONDISCONNECT);
			this.dispatchEvent(connectEvent);			
		}//onTunnelData			
		
		private function authenticateTunnel():void {			
			this._tunnelSocket.writeByte(SOCKS5Model.SOCKS5_head_VERSION);
			this._tunnelSocket.writeByte(SOCKS5Model.SOCKS5_auth_NUMMETHODS);
			this._tunnelSocket.writeByte(SOCKS5Model.SOCKS5_auth_NOAUTH);			
			this._tunnelSocket.flush();
		}//authenticateTunnel
		
		private function onAuthenticateTunnel():void {			
			this._tunnelSocket.writeByte(SOCKS5Model.SOCKS5_head_VERSION);
			this._tunnelSocket.writeByte(SOCKS5Model.SOCKS5_conn_TCPIPSTREAM);
			this._tunnelSocket.writeByte(0); //Reserved
			this._tunnelSocket.writeByte(SOCKS5Model.SOCKS5_addr_DOMAIN); //Most secure when using DNS through proxy
			var currentRequest:URLRequest = this._urlRequestBuffer[0] as URLRequest;
			var domain:String = URLUtil.getServerName(currentRequest.url);
			var domainLength:int = int(domain.length);
			var port:int = int(URLUtil.getPort(currentRequest.url));			
			this._tunnelSocket.writeByte(domainLength);
			var portMSB:int = (port & 0xFF00) >> 8;
			var portLSB:int = port & 0xFF;			
			this._tunnelSocket.writeMultiByte(domain, SOCKS5Model.charSetEncoding);			
			this._tunnelSocket.writeByte(portMSB); //Obviously swap these if LSB comes first
			this._tunnelSocket.writeByte(portLSB);			
			this._tunnelSocket.flush();
		}//onAuthenticateTunnel
		
		private function onEstablishHTTPTunnel():void {
			this.sendQueuedHTTPRequest();
		}//onEstablishHTTPTunnel
		
		private function sendQueuedHTTPRequest():void {
			var currentRequest:URLRequest = this._urlRequestBuffer.shift() as URLRequest;
			this._currentRequest = currentRequest;
			var requestString:String = SOCKS5Model.createHTTPRequestString(currentRequest);				
			this._tunnelSocket.writeMultiByte(requestString, SOCKS5Model.charSetEncoding);			
			this._tunnelSocket.flush();
		}//sendQueuedHTTPRequest
		
		private function authResponseOkay(respData:ByteArray):Boolean {
			respData.position = 0;
			var SOCKSVersion:int = respData.readByte();
			var authMethod:int = respData.readByte();
			if (SOCKSVersion != SOCKS5Model.SOCKS5_head_VERSION) {
				return (false);
			}//if
			if (authMethod != SOCKS5Model.SOCKS5_auth_NOAUTH) {
				return (false);
			}//if			
			return (true);
		}//authResponseOkay
		
		private function tunnelResponseOkay(respData:ByteArray):Boolean {
			respData.position = 0;
			var SOCKSVersion:int = respData.readByte();
			var status:int = respData.readByte();
			if (SOCKSVersion != SOCKS5Model.SOCKS5_head_VERSION) {
				return (false);
			}//if
			if (status != 0) {
				return (false);
			}//if			
			return (true);
		}//tunnelResponseOkay
		
		private function tunnelRequestComplete(respData:ByteArray):Boolean {
			respData.position = respData.bytesAvailable - 4;
			var respString:String = respData.readMultiByte(4, SOCKS5Model.charSetEncoding);						
			respData.position = 0;
			if (respString == SOCKS5Model.doubleLineEnd) {
				return (true);
			}//if
			return (false);
		}
		
		private function handleHTTPRedirect(responseObj:HTTPResponse):void {
			if (this._currentRequest.followRedirects) {
				if ((responseObj.statusCode == 301) || (responseObj.statusCode == 302)) {
					trace ("Detected a redirect!");
					var redirectURL:HTTPResponseHeader = responseObj.getHeader("Location");
					trace ("Trying: "+redirectURL);
					if (redirectURL != null) {
						this._currentRequest.url = redirectURL.value;
						this._urlRequestBuffer.push(this._currentRequest);
						this._HTTPStatusReceived = false;
						this._HTTPHeadersReceived = false;
						this.sendQueuedHTTPRequest();
					}//if
				}//if				
			}//if
		}//handleHTTPRedirect
		
		private function onTunnelData(eventObj:ProgressEvent):void {
			var rawData:ByteArray = new ByteArray();
			var stringData:String = new String();
			this._tunnelSocket.readBytes(rawData);	
			rawData.position = 0;
			stringData = rawData.readMultiByte(rawData.length, SOCKS5Model.charSetEncoding);
			rawData.position = 0;			
			if (!this._authenticated) {
				if (this.authResponseOkay(rawData)) {
					this._authenticated = true;
					this.onAuthenticateTunnel();
					return;
				}//if
			}//if		
			if (!this._tunneled) {
				if (this.tunnelResponseOkay(rawData)) {
					this._tunneled = true;					
					this.sendQueuedHTTPRequest();
					return;
				}//if
			}//if
			if (!this._HTTPStatusReceived) {
				if (this._HTTPResponse.parseResponseStatus(this._responseBuffer)) {
					this._HTTPStatusReceived = true;
					var statusEvent:SOCKS5TunnelEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONHTTPSTATUS);			
					statusEvent.httpResponse = this._HTTPResponse;	
					this.dispatchEvent(statusEvent);		
					trace ("STATUS RECEIVED!");
					this.handleHTTPRedirect(this._HTTPResponse);
				}//if
			}//if
			if (!this._HTTPHeadersReceived) {
				if (this._HTTPResponse.parseResponseHeaders(this._responseBuffer)) {
					this._HTTPHeadersReceived = true;
					statusEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONHTTPHEADERS);			
					statusEvent.httpResponse = this._HTTPResponse;	
					this.dispatchEvent(statusEvent);	
					trace ("HEADERS RECEIVED!");
				}//if
			}//if			
			if (!this.tunnelRequestComplete(rawData)) {				
				rawData.readBytes(this._responseBuffer, this._responseBuffer.length);				
				return;
			}//if
			rawData.readBytes(this._responseBuffer, this._responseBuffer.length);
		//	trace ("ALL DATA!");			
		//	trace (this._responseBuffer.toString());
			this._HTTPResponse.parseResponseBody(this._responseBuffer);
			this._responseBuffer.position = 0;
			stringData = this._responseBuffer.readMultiByte(this._responseBuffer.length, SOCKS5Model.charSetEncoding);					
			var dataEvent:SOCKS5TunnelEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONHTTPRESPONSE);			
			dataEvent.httpResponse = this._HTTPResponse;	
			dataEvent.httpResponse.rawResponse = new ByteArray();
			dataEvent.httpResponse.rawResponse.writeBytes(this._responseBuffer);			
			this.dispatchEvent(dataEvent);			
		}//onTunnelData
		
	}//SOCKS5Tunnel class

}//package