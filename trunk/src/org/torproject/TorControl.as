package org.torproject  {
	
	import flash.events.EventDispatcher;
	import flash.net.Socket;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import org.torproject.events.TorControlEvent;
	import org.torproject.model.TorControlModel;
	import flash.utils.setTimeout;
	
	/**
	 * Provides control and event handling services for core Tor services.
	 * 
	 * @author Patrick Bay
	 */
	public class TorControl extends EventDispatcher {
		
		private static const defaultControlIP:String = "127.0.0.1";
		private static const defaultControlPort:int = 9151;
		private var _controlIP:String = defaultControlIP;
		private var _controlPort:int = defaultControlPort;
		private var _controlPassHash:String = "";
		private var _socket:Socket = null;
		private var _connectDelay:Number = 1; //The delay, in seconds, to hold before attempting to connect to the control socket
		private var _connected:Boolean = false;
		private var _authenticated:Boolean = false;
		
		public function TorControl(controlIP:String=defaultControlIP, controlPort:int=defaultControlPort, controlPassHash:String="", connectDelay:Number=1) {
			this._controlIP = controlIP;
			this._controlPort = controlPort;
			this._controlPassHash = controlPassHash;
			this._connectDelay = connectDelay*1000;
		}		
		
		public function connect(... args):void {			
			if (this._socket == null) {
				if ((this._connectDelay > 0) && (args[0]!=true)){
					trace ("TorControl > Delaying connection by " + (this._connectDelay/1000) + " seconds...");
					setTimeout(this.connect, this._connectDelay, true);					
					return;
				}//if				
				trace ("TorControl > Now connecting...");
				this._socket = new Socket(this._controlIP, this._controlPort);
				this._socket.addEventListener(Event.CONNECT, this.onConnect);
				this._socket.addEventListener(ProgressEvent.SOCKET_DATA, this.onData);				
			} else {				
			}
		}
				
		
		private function onConnect(eventObj:Event):void {
			trace ("TorControl >> Connected to Tor control socket at " + this._controlIP + ":" + this._controlPort);
			this._connected = true;
			this.dispatchEvent(new TorControlEvent(TorControlEvent.ONCONNECT));
			this.authenticate();
		}
		
		private function authenticate():void {
			this._authenticated = false;
			this.sendRawControlMessage(TorControlModel.getControlMessage("authenticate"));
		}//authenticate
		
		public function sendRawControlMessage(msg:String):Boolean {
			if (!this._connected) {
				return (false);
			}
			if (this._socket == null) {
				return (false);
			}
			msg = msg + TorControlModel.controlLineEnd; //Add CRLF to end of message, as per protocol
			this._socket.writeMultiByte(msg, "iso-8859-1");
			this._socket.flush();
			return (true);
		}
		
		private function onData(eventObj:ProgressEvent):void {
			var receivedMsg:String = this._socket.readMultiByte(this._socket.bytesAvailable, "iso-8859-1");
			var msgObj:Object = this.parseReceivedData(receivedMsg);			
			if ((!this._authenticated) && (!TorControlModel.isControlResponseError(msgObj.status))) {
				trace ("TorControl > Received control authentication response: "+msgObj.status+" "+msgObj.body);				
				this._authenticated = true;
				var event:TorControlEvent = new TorControlEvent(TorControlEvent.ONAUTHENTICATE);
				event.status = msgObj.status;
				event.multilineStatusIndicator = msgObj.multilineStatusIndicator;
				event.body = msgObj.body;
				event.rawMessage = receivedMsg;
				this.dispatchEvent(event);
			} else {
				trace ("TorControl > Received control response: "+msgObj.status+" "+msgObj.body);
				event = new TorControlEvent(TorControlEvent.ONRESPONSE);
				event.status = msgObj.status;
				event.multilineStatusIndicator = msgObj.multilineStatusIndicator;
				event.body = msgObj.body;
				event.rawMessage = receivedMsg;
				this.dispatchEvent(event);
			}
		}
		
		private function parseReceivedData(dataStr:String):Object {
			var responseCodeStr:String = dataStr.substr(0, 3);
			var codeValue:int = new int(responseCodeStr);
			var multilineSeparator:String = dataStr.substr(3, 1);
			var responseBody:String = dataStr.substr(4);			
			var returnObj:Object = new Object();
			returnObj.status = codeValue;
			returnObj.multilineStatusIndicator = codeValue;
			returnObj.body = responseBody;
			return (returnObj);
		}
		
	}

}