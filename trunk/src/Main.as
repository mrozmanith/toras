package  {
	
	import flash.display.MovieClip;
	import flash.events.Event;
	import org.torproject.events.TorControlEvent;
	import org.torproject.TorControl;
	
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
		
		private static var torControl:TorControl=null;
		
		public function Main() {
			this.launchTorControl();	
		}	
		
		private function launchTorControl():void {
			if (torControl==null) {
				torControl = new TorControl();
				//We want to listen to .ONAUTHENTICATE since .ONCONNECT only signals that a connection has been established.
				torControl.addEventListener(TorControlEvent.ONAUTHENTICATE, this.onTorControlReady);
				torControl.addEventListener(TorControlEvent.ONLOGMSG, this.onTorLogMessage);
			//	torControl.addEventListener(TorControlEvent.ONEVENT, this.onTorEvent);
				torControl.connect();
			}//if
		}
		
		private function onTorLogMessage(eventObj:TorControlEvent):void {
			trace (TorControl.executable + " > "+eventObj.rawMessage);
		}
		
		private function onTorEvent(eventObj:TorControlEvent):void {
			trace ("Main.as > Async event \""+eventObj.torEvent+"\" received: "+eventObj.body);
		}
		
		private function onTorControlReady(eventObj:TorControlEvent):void {
			trace ("Main.as > TorControl is connected, authenticated, and ready for commands.");
			//Enable "CIRC" event notification, see document "TC: A Tor control protocol (Version 1) -- 4.1. Asynchronous events" for more information, here:
			//   https://gitweb.torproject.org/torspec.git?a=blob_plain;hb=HEAD;f=control-spec.txt
			//Event listener added to TorControl instance should listen for TorControlEvent.ONEVENT
			torControl.enableTorEvent("CIRC"); 
		}
		
	}

}