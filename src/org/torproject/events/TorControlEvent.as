package org.torproject.events {
	import flash.events.Event;
	
	/**
	 * ...
	 * @author Patrick Bay
	 */
	public class TorControlEvent extends Event {
		
		/**
		 * Dispatched whenever Tor sends a log message via STDOUT.
		 */
		public static const ONLOGMSG:String = "Event.TorControlEvent.ONLOGMSG";
		/**
		 * Dispatched once the Tor control connection is connected. Until authorized, the control connection should not be assumed to be usable.
		 */
		public static const ONCONNECT:String = "Event.TorControlEvent.ONCONNECT";
		/**
		 * Dispatched once the Tor control connection is authenticated and ready for additional commands.
		 */
		public static const ONAUTHENTICATE:String = "Event.TorControlEvent.ONAUTHENTICATE";
		/**
		 * Dispatched whenever the Tor control connection replies with a response. For asynchronous events registered with Tor, additional ASYNCHEVENT events
		 * will be broadcast.
		 */
		public static const ONRESPONSE:String = "Event.TorControlEvent.ONRESPONSE";
		/**
		 * Dispatched whenever the Tor control connection signals an asynchronous event. Only registered events will be processed, and these may be received at any time.
		 */
		public static const ONASYNCRESPONSE:String = "Event.TorControlEvent.ONASYNCRESPONSE";
		
		
		public var rawMessage:String = new String();
		public var body:String = new String();
		public var multilineStatusIndicator:String = new String();
		public var status:int = 0;		
		
		public function TorControlEvent(p_type:String, p_bubbles:Boolean=false, p_cancelable:Boolean=false) {
			super(p_type, p_bubbles, p_cancelable);
		}
		
	}

}