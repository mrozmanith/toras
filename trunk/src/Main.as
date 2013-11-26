package  {
		
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.net.URLVariables;
	import org.torproject.events.TorControlEvent;
	import org.torproject.model.HTTPResponseHeader;
	import org.torproject.TorControl;
	import org.torproject.events.SOCKS5TunnelEvent
	import org.torproject.SOCKS5Tunnel;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	
	/**
	 * Sample class to demonstrate dynamically launching Tor network connectivity using the included
	 * application package within an AIR app, then using it to both send and receive HTTP requests as 
	 * well control the Tor network client via its public API.
	 * 
	 * @author Patrick Bay
	 * 
	 * The MIT License (MIT)
	 * 
	 * Copyright (c) 2013 Patrick Bay
	 * 
	 * Permission is hereby granted, free of charge, to any person obtaining a copy
	 * of this software and associated documentation files (the "Software"), to deal
	 * in the Software without restriction, including without limitation the rights
	 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	 * copies of the Software, and to permit persons to whom the Software is
	 * furnished to do so, subject to the following conditions:
	 * 
	 * The above copyright notice and this permission notice shall be included in
	 * all copies or substantial portions of the Software.
	 * 
	 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	 * THE SOFTWARE. 
	 */
	public class Main extends MovieClip {
		
		private static var torControl:TorControl = null;
		private var tunnel:SOCKS5Tunnel = null;
		
		public function Main() {
			this.launchTorControl();	
		}			
		
		private function launchTorControl():void {
			if (torControl==null) {
				torControl = new TorControl();
				//We want to listen to .ONAUTHENTICATE since .ONCONNECT only signals that a connection has been established.
				torControl.addEventListener(TorControlEvent.ONAUTHENTICATE, this.onTorControlReady);
				torControl.addEventListener(TorControlEvent.ONLOGMSG, this.onTorLogMessage);			
				torControl.connect();
			}//if
		}
						
		private function onHTTPResponse(eventObj:SOCKS5TunnelEvent):void {
			trace ("--------------------------------------------------------");
			trace ("Loaded via Tor: ");
			trace(" ");
			trace ("STATUS: " + eventObj.httpResponse.statusCode + " " + eventObj.httpResponse.status);
			trace(" ");
			trace ("HEADERS: ");
			trace(" ");
			if (eventObj.httpResponse.headers!=null) {
				for (var count:uint = 0; count < eventObj.httpResponse.headers.length; count++) {
					var httpHeader:HTTPResponseHeader = eventObj.httpResponse.headers[count];
					trace (httpHeader.name + ": " + httpHeader.value);
				}//for
			} else {
				trace ("No response headers -- either a bad response or a severe error.");
			}
			trace(" ");			
			trace ("RESPONSE BODY: ");
			trace(" ");
			trace (eventObj.httpResponse.body);		
			trace ("--------------------------------------------------------");		
		}
		
		/* PRIVATE */
		private function onHTTPRedirect(eventObj:SOCKS5TunnelEvent):void {
			trace ("Received HTTP redirect error " + eventObj.httpResponse.statusCode);
			trace ("Redirecting to: " + SOCKS5Tunnel(eventObj.target).activeRequest.url);			
			var headers:Vector.<HTTPResponseHeader> = eventObj.httpResponse.headers;
			trace ("HEADERS >>>");
			for (var count:uint = 0; count < headers.length; count++) {
				trace (headers[count].name + ": " + headers[count].value);
			}
		}
		
		/* PRIVATE */
		private function onSOCKS5TunnelDisconnect(eventObj:SOCKS5TunnelEvent):void {
			trace ("SOCKS5 tunnel disconnected.");			
		}
		
		/* PRIVATE */
		private function onTorLogMessage(eventObj:TorControlEvent):void {
			//STDOUT log from Tor -- only available if we're launching the process using TorControl
			trace (TorControl.executable + " > "+eventObj.rawMessage);
		}
		
		/* PRIVATE */
		private function onTorWARNMessage(eventObj:TorControlEvent):void {
			trace ("Tor WARN event: "+eventObj.body);
		}
		
		/* PRIVATE */
		private function onTorINFOMessage(eventObj:TorControlEvent):void {
			trace ("Tor INFO event: "+eventObj.body);
		}
		
		/* PRIVATE */
		private function onTorNOTICEMessage(eventObj:TorControlEvent):void {
			trace ("Tor NOTICE event: "+eventObj.body);
		}
				
		/* PRIVATE */
		private function onTorControlReady(eventObj:TorControlEvent):void {
			trace ("Main.as > TorControl is connected, authenticated, and ready for commands.");
			//Listen for some internal Tor events...
			torControl.addEventListener(TorControlEvent.TOR_INFO, this.onTorINFOMessage);
			torControl.addEventListener(TorControlEvent.TOR_WARN, this.onTorWARNMessage);
			torControl.addEventListener(TorControlEvent.TOR_NOTICE, this.onTorNOTICEMessage);			
			//Create an anonymous tunnel connection for streaming HTTP requests through Tor...
			this.tunnel = new SOCKS5Tunnel();			
			var proxyRequest:URLRequest = new URLRequest("http://patrickbay.ca/TorAS/echoservice/");
			//Create some variables to send with the request...
			var variables:URLVariables = new URLVariables();			
			variables.query = "TorAS ActionScript Library";		
			variables.url = "https://code.google.com/p/toras/";
			variables.dateTime = new Date().toString();
			//Set submission method to POST...
			proxyRequest.method = URLRequestMethod.POST;
			proxyRequest.data = variables;			
			this.tunnel.addEventListener(SOCKS5TunnelEvent.ONHTTPRESPONSE, this.onHTTPResponse);
			this.tunnel.addEventListener(SOCKS5TunnelEvent.ONHTTPREDIRECT, this.onHTTPRedirect);
			this.tunnel.addEventListener(SOCKS5TunnelEvent.ONDISCONNECT, this.onSOCKS5TunnelDisconnect);
			this.tunnel.loadHTTP(proxyRequest);
		}	
		
	}

}