package org.torproject.events {
	
	import flash.events.Event;
	
	public class DirAuthorityEvent extends Event {
		
		public static const ONLOAD:String = "Event.DirAuthorityEvent.ONLOAD";
		public static const ONPARSE:String = "Event.DirAuthorityEvent.ONPARSE";
		public static const ONLOADERROR:String = "Event.DirAuthorityEvent.ONLOADERROR";
		
		public function DirAuthorityEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) {
			super(type, bubbles, cancelable);
			
		}
		
	}

}