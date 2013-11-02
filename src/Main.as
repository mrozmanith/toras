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
				torControl.addEventListener(TorControlEvent.ONEVENT, this.onTorEvent);
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
			torControl.enableTorEvent("SIGNAL");
			torControl.enableTorEvent("CIRC");
		}
		
	}

}