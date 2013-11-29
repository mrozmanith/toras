package demos {
				
	import org.torproject.TorControl;
	import org.torproject.events.TorControlEvent;	
	
	/**
	 * Demonstrates how to work with Tor circuits.
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
	public class CircuitsDemo {		
		
		public function CircuitsDemo() {	
		//	torControl.addEventListener(TorControlEvent.TOR_CIRC, this.onTorCIRCMessage);	
		}			
				
		
		/* PRIVATE */
		private function onTorLogMessage(eventObj:TorControlEvent):void {
			//STDOUT log from Tor -- only available if we're launching the process using TorControl
		//	trace (TorControl.executable + " > "+eventObj.rawMessage);
		}
		
		/* PRIVATE */
		private function onTorWARNMessage(eventObj:TorControlEvent):void {
	//		trace ("Tor WARN event: "+eventObj.body);
		}
		
		/* PRIVATE */
		private function onTorINFOMessage(eventObj:TorControlEvent):void {
	//		trace ("Tor INFO event: "+eventObj.body);
		}
		
		/* PRIVATE */
		private function onTorNOTICEMessage(eventObj:TorControlEvent):void {
	//		trace ("Tor NOTICE event: "+eventObj.body);
		}
		
		/* PRIVATE */
		private function onTorCIRCMessage(eventObj:TorControlEvent):void {
		//	trace ("Tor CIRC event: " + eventObj.body);			
			//Created another circuit, send out next request...
		//	var proxyRequest:URLRequest = new URLRequest("http://patrickbay.ca/TorAS/echoservice/");
		//	var variables:URLVariables = new URLVariables();			
		//	variables.query = "Another request on another circuit";						
		//	proxyRequest.method = URLRequestMethod.GET;
		//	proxyRequest.data = variables;						
		//	this.tunnel.loadHTTP(proxyRequest);		
		}
		
	}

}