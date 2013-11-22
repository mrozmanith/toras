package org.torproject {
	
	import flash.events.EventDispatcher;
	import flash.net.Socket;
	import flash.net.SecureSocket;	
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.events.IOErrorEvent;	
	import flash.events.SecurityErrorEvent;	
	import flash.utils.ByteArray;
	import org.torproject.events.SOCKS5TunnelEvent;
	import org.torproject.model.HTTPResponse;
	import org.torproject.model.HTTPResponseHeader;
	import org.torproject.model.SOCKS5Model;
	import org.torproject.model.TorASError;
	import flash.net.URLRequest;
	import flash.net.URLRequestDefaults;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import org.torproject.utils.URLUtil;	
	
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
		
		public static const defaultSOCKSIP:String = "127.0.0.1";
		public static const defaultSOCKSPort:int = 1080;
		public static const maxRedirects:int = 5;
		private var _tunnelSocket:Socket = null;
		private var _tunnelIP:String = null;
		private var _tunnelPort:int = -1;
		private var _connectionType:int = -1;
		private var _connected:Boolean = false;
		private var _authenticated:Boolean = false;
		private var _tunneled:Boolean = false;		
		private var _requestActive:Boolean = false;
		private var _requestBuffer:Array = new Array();
		private var _responseBuffer:ByteArray = new ByteArray();
		private var _HTTPStatusReceived:Boolean = false;
		private var _HTTPHeadersReceived:Boolean = false;
		private var _HTTPResponse:HTTPResponse;		
		private var _currentRequest:URLRequest;
		private var _redirectCount:int = 0;		
		
		/**
		 * Creates an instance of a SOCKS5 proxy tunnel.
		 * 
		 * @param	tunnelIP The SOCKS proxy IP to use. If not specified, the current static constant values are used by default.
		 * @param	tunnelPort The SOCKS proxy port to use. If not specified, the current static constant values are used by default.
		 */
		public function SOCKS5Tunnel(tunnelIP:String=null, tunnelPort:int=-1) {
			if ((tunnelIP == null) || (tunnelIP == "")) {
				this._tunnelIP = defaultSOCKSIP;
			}//if
			if (tunnelPort < 1) {
				this._tunnelPort = defaultSOCKSPort;
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
			try {
				this._requestBuffer.push(request);			
				this._responseBuffer = new ByteArray();
				this._HTTPStatusReceived = false;
				this._HTTPHeadersReceived = false;				
				this.disconnectSocket();
				this._HTTPResponse = new HTTPResponse();
				this._connectionType = SOCKS5Model.SOCKS5_conn_TCPIPSTREAM;			
				this._tunnelSocket = new Socket();				
				this.addSocketListeners();				
				this._tunnelSocket.connect(this.tunnelIP, this.tunnelPort);
				return (true);
			} catch (err:*) {
				var eventObj:SOCKS5TunnelEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONCONNECTERROR);
				eventObj.error = new TorASError(err.toString());
				eventObj.error.rawMessage = err.toString();
				this.dispatchEvent(eventObj);
				return (false);
			}//catch
			return (false);
		}//loadHTTP		
		
		public function get activeRequest():* {
			return (this._currentRequest);
		}//get activeRequest
		
		private function disconnectSocket():void {			
			this._connected = false;
			this._authenticated = false;
			this._tunneled = false;		
			if (this._tunnelSocket != null) {
				this.removeSocketListeners();
				this._tunnelSocket.close();
				this._tunnelSocket = null;
				var eventObj:SOCKS5TunnelEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONDISCONNECT);
				this.dispatchEvent(eventObj);
			}//if			
		}
		
		private function removeSocketListeners():void {
			if (this._tunnelSocket == null) { return;}
			this._tunnelSocket.removeEventListener(Event.CONNECT, this.onTunnelConnect);
			this._tunnelSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, this.onTunnelConnectError);
			this._tunnelSocket.removeEventListener(IOErrorEvent.IO_ERROR, this.onTunnelConnectError);
			this._tunnelSocket.removeEventListener(IOErrorEvent.NETWORK_ERROR, this.onTunnelConnectError);
			this._tunnelSocket.removeEventListener(ProgressEvent.SOCKET_DATA, this.onTunnelData);	
			this._tunnelSocket.removeEventListener(Event.CLOSE, this.onTunnelDisconnect);
		}//removeSocketListeners
				
		private function addSocketListeners():void {
			if (this._tunnelSocket == null) { return;}
			this._tunnelSocket.addEventListener(Event.CONNECT, this.onTunnelConnect);
			this._tunnelSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.onTunnelConnectError);
			this._tunnelSocket.addEventListener(IOErrorEvent.IO_ERROR, this.onTunnelConnectError);
			this._tunnelSocket.addEventListener(IOErrorEvent.NETWORK_ERROR, this.onTunnelConnectError);			
			this._tunnelSocket.addEventListener(Event.CLOSE, this.onTunnelDisconnect);
		}//addSocketListeners
		
		private function onTunnelConnect(eventObj:Event):void {						
			this._connected = true;
			this._tunnelSocket.removeEventListener(Event.CONNECT, this.onTunnelConnect);			
			this._tunnelSocket.addEventListener(ProgressEvent.SOCKET_DATA, this.onTunnelData);			
			var connectEvent:SOCKS5TunnelEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONCONNECT);
			this.dispatchEvent(connectEvent);
			this.authenticateTunnel();
		}//onTunnelData	
		
		private function onTunnelConnectError(eventObj:IOErrorEvent):void {			
			this.removeSocketListeners();
			this._tunnelSocket = null;
			this._connected = false;
			this._authenticated = false;
			this._tunneled = false;
			var errorEventObj:SOCKS5TunnelEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONCONNECTERROR);
			errorEventObj.error = new TorASError(eventObj.toString());
			errorEventObj.error.status = eventObj.errorID;						
			errorEventObj.error.rawMessage = eventObj.toString();
			this.dispatchEvent(errorEventObj);
		}//onTunnelConnectError
		
		private function onTunnelDisconnect(eventObj:Event):void {						
			this.removeSocketListeners();			
			this._connected = false;
			this._authenticated = false;
			this._tunneled = false;
			this._tunnelSocket.removeEventListener(Event.CONNECT, this.onTunnelConnect);
			this._tunnelSocket.removeEventListener(Event.CLOSE, this.onTunnelDisconnect);
			this._tunnelSocket.addEventListener(ProgressEvent.SOCKET_DATA, this.onTunnelData);
			this._tunnelSocket = null;
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
			var currentRequest:* = this._requestBuffer[0];
			if (currentRequest is URLRequest) {
				this.establishHTTPTunnel();
			}//if
		}//onAuthenticateTunnel
		
		private function establishHTTPTunnel():void {
			this._tunnelSocket.writeByte(SOCKS5Model.SOCKS5_head_VERSION);
			this._tunnelSocket.writeByte(SOCKS5Model.SOCKS5_conn_TCPIPSTREAM);
			this._tunnelSocket.writeByte(0); //Reserved
			this._tunnelSocket.writeByte(SOCKS5Model.SOCKS5_addr_DOMAIN); //Most secure when using DNS through proxy
			var currentRequest:* = this._requestBuffer[0];			
			var domain:String = URLUtil.getServerName(currentRequest.url);
		//	var domainSplit:Array = domain.split(".");			
		//	if (domainSplit.length>2) {
		//		domain = domainSplit[1] + "." + domainSplit[2]; //Ensure we have JUST the domain
		//	}//if				
			var domainLength:int = int(domain.length);
			var port:int = int(URLUtil.getPort(currentRequest.url));			
			this._tunnelSocket.writeByte(domainLength);
			var portMSB:int = (port & 0xFF00) >> 8;
			var portLSB:int = port & 0xFF;			
			this._tunnelSocket.writeMultiByte(domain, SOCKS5Model.charSetEncoding);			
			this._tunnelSocket.writeByte(portMSB); //Obviously swap these if LSB comes first
			this._tunnelSocket.writeByte(portLSB);			
			this._tunnelSocket.flush();			
		}//establishHTTPTunnel
		
		private function onEstablishTunnel():void {
			var currentRequest:* = this._requestBuffer[0];
			if (currentRequest is URLRequest) {
				this.sendQueuedHTTPRequest();
			}//if		
		}//onEstablishHTTPTunnel
		
		private function sendQueuedHTTPRequest():void {
			var currentRequest:URLRequest = this._requestBuffer.shift() as URLRequest;
			this._currentRequest = currentRequest;
			if (this._HTTPResponse!=null ) {
				if (this._currentRequest.manageCookies) {
					var requestString:String = SOCKS5Model.createHTTPRequestString(currentRequest, this._HTTPResponse.cookies);		
				} else {
					requestString = SOCKS5Model.createHTTPRequestString(currentRequest, null);
				}//else
			} else {
				requestString = SOCKS5Model.createHTTPRequestString(currentRequest, null);
			}//else
			this._HTTPResponse = new HTTPResponse();
			
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
			var currentRequest:* = this._requestBuffer[0];
			if (currentRequest is URLRequest) {
				var SOCKSVersion:int = respData.readByte();
				var status:int = respData.readByte();
				if (SOCKSVersion != SOCKS5Model.SOCKS5_head_VERSION) {
					return (false);
				}//if
				if (status != 0) {
					return (false);
				}//if
				return (true);
			}//if
			return (false);
		}//tunnelResponseOkay
		
		private function tunnelRequestComplete(respData:ByteArray):Boolean {
			respData.position = respData.length - 4; //Not bytesAvailable since already read at this point!
			var respString:String = respData.readMultiByte(4, SOCKS5Model.charSetEncoding);						
			respData.position = 0;
			if (respString == SOCKS5Model.doubleLineEnd) {
				return (true);
			}//if
			return (false);
		}
		
		private function handleHTTPRedirect(responseObj:HTTPResponse):Boolean {
			if (this._currentRequest.followRedirects) {				
				if ((responseObj.statusCode == 301) || (responseObj.statusCode == 302)) {					
					var redirectInfo:HTTPResponseHeader = responseObj.getHeader("Location");						
					if (redirectInfo != null) {		
						this._redirectCount++;						
						this._currentRequest.url = redirectInfo.value;	
						
						this._HTTPStatusReceived = false;
						this._HTTPHeadersReceived = false;											
						this._responseBuffer = new ByteArray();
						if (this._redirectCount >= maxRedirects) {
							//Maximum redirects hit
							var statusEvent:SOCKS5TunnelEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONHTTPMAXREDIRECTS);			
							statusEvent.httpResponse = this._HTTPResponse;						
							this.dispatchEvent(statusEvent);							
							this.disconnectSocket();
							return (true);							
						}//if
						this._requestBuffer.push(this._currentRequest);
						statusEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONHTTPREDIRECT);			
						statusEvent.httpResponse = this._HTTPResponse;						
						this.dispatchEvent(statusEvent);	
						this.sendQueuedHTTPRequest();
						return (true);
					}//if
				}//if				
			}//if
			return (false);
		}//handleHTTPRedirect
		
		private function handleHTTPResponse(rawData:ByteArray):void {
			rawData.readBytes(this._responseBuffer, this._responseBuffer.length);			
			if (!this._HTTPStatusReceived) {				
				if (this._HTTPResponse.parseResponseStatus(this._responseBuffer)) {
					this._HTTPStatusReceived = true;
					var statusEvent:SOCKS5TunnelEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONHTTPSTATUS);			
					statusEvent.httpResponse = this._HTTPResponse;						
					this.dispatchEvent(statusEvent);												
				}//if
			}//if
			if (!this._HTTPHeadersReceived) {			
				if (this._HTTPResponse.parseResponseHeaders(this._responseBuffer)) {
					this._HTTPHeadersReceived = true;
					statusEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONHTTPHEADERS);			
					statusEvent.httpResponse = this._HTTPResponse;
					this.dispatchEvent(statusEvent);						
				}//if
			}//if				
			if (this.handleHTTPRedirect(this._HTTPResponse)) {								
				return;
			}//if
			if (!this.tunnelRequestComplete(rawData)) {	
				return;
			}//if				
			this._HTTPResponse.parseResponseBody(this._responseBuffer);
			this._responseBuffer.position = 0;			
			var dataEvent:SOCKS5TunnelEvent = new SOCKS5TunnelEvent(SOCKS5TunnelEvent.ONHTTPRESPONSE);			
			dataEvent.httpResponse = this._HTTPResponse;	
			dataEvent.httpResponse.rawResponse = new ByteArray();
			dataEvent.httpResponse.rawResponse.writeBytes(this._responseBuffer);			
			this.dispatchEvent(dataEvent);	
			this._responseBuffer = new ByteArray();		
			this._HTTPStatusReceived = false;
			this._HTTPHeadersReceived = false;			
			this.disconnectSocket();
		}//handleHTTPResponse
		
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
					this.onEstablishTunnel();
					return;
				}//if
			}//if
			if (this._currentRequest is URLRequest) {
				this.handleHTTPResponse(rawData);			
			}//if
		}//onTunnelData
		
	}//SOCKS5Tunnel class

}//package