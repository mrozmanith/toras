package  {
		
	import flash.display.MovieClip;
	import flash.events.Event;
	import org.torproject.events.TorControlEvent;
	import org.torproject.TorControl;
	import org.torproject.events.SOCKS5TunnelEvent
	import org.torproject.SOCKS5Tunnel;
	import flash.net.URLRequest;
	
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
				
		
		private function onSOCKSTunnelResponse(eventObj:SOCKS5TunnelEvent):void {
			trace ("Loaded via Tor:");
			trace (eventObj.httpResponse.body);		
		}
		
		private function onTorLogMessage(eventObj:TorControlEvent):void {
			trace (TorControl.executable + " > "+eventObj.rawMessage);
		}
		
		private function onTorDEBUGMessage(eventObj:TorControlEvent):void {
			trace ("Tor DEBUG event: "+eventObj.body);
		}
		
		private function onTorINFOMessage(eventObj:TorControlEvent):void {
			trace ("Tor INFO event: "+eventObj.body);
		}
		
		private function onTorNOTICEMessage(eventObj:TorControlEvent):void {
			trace ("Tor NOTICE event: "+eventObj.body);
		}
				
		private function onTorControlReady(eventObj:TorControlEvent):void {
			trace ("Main.as > TorControl is connected, authenticated, and ready for commands.");
			//Listen for some internal Tor events...
			torControl.addEventListener(TorControlEvent.TOR_INFO, this.onTorINFOMessage);
			torControl.addEventListener(TorControlEvent.TOR_DEBUG, this.onTorDEBUGMessage);
			torControl.addEventListener(TorControlEvent.TOR_NOTICE, this.onTorNOTICEMessage);			
			//Create an anonymous tunnel connection for streaming HTTP requests through Tor...
			this.tunnel = new SOCKS5Tunnel();
			var proxyRequest:URLRequest = new URLRequest("http://www.google.com/");
			this.tunnel.addEventListener(SOCKS5TunnelEvent.ONHTTPRESPONSE, this.onSOCKSTunnelResponse);
			this.tunnel.loadHTTP(proxyRequest);			
		}
		
	}

}