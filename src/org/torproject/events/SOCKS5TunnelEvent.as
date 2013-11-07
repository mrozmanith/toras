package org.torproject.events {
	
	import flash.events.Event;
	
	/**
	 * Contains data and information from various events raised within a SOCKS5Tunnel instance.
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
	public class SOCKS5TunnelEvent extends Event {
		
		/**
		 * Dispatched when the SOCKS5Tunnel instance successfully connects to the tunnel socket.
		 */
		public static const ONCONNECT:String = "Event.SOCKS5TunnelEvent.ONCONNECT";
		/**
		 * Dispatched when the SOCKS5Tunnel instance received a complete response to a tunneled HTTP request.
		 */
		public static const ONHTTPRESPONSE:String = "Event.SOCKS5TunnelEvent.ONHTTPRESPONSE";
		
		public var HTTPResponseBody:String = null;
		public var HTTPResponseHeaders:String = null;
		
		public function SOCKS5TunnelEvent(p_type:String, p_bubbles:Boolean=false, p_cancelable:Boolean=false) {
			super(p_type, p_bubbles, p_cancelable);
		}//consructor
		
	}//SOCKS5TunnelEvent

}//package