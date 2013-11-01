package org.torproject.model {
	
	/**
	 * Stores protocol lookup and other dynamic and static information for use with the Tor control socket connection.
	 * 
	 * @author Patrick Bay
	 */
	public class TorControlModel {
		
		public static const TorControlTable:XML =
		<TorControlTable>
			<message type="authenticate">AUTHENTICATE</message>
		</TorControlTable>
		
		public static const TorResponseTable:XML =
		<TorResponseTable>
			<status type="250">OK</status>
			<errorstatus type="251">Generic Error</errorstatus>
		</TorResponseTable>
		
		public static const controlLineEnd:String = String.fromCharCode(13) + String.fromCharCode(10);
		
		public static function getControlMessage(msgType:String):String {
			if ((msgType == "") || (msgType == null)) {
				return (null);
			}
			var compareMsgType:String = new String(msgType);
			compareMsgType = compareMsgType.toLowerCase();
			var messages:XMLList = TorControlTable.children();
			for (var count:uint = 0; count < messages.length(); count++) {
				var currentMessage:XML = messages[count] as XML;
				var currentMsgType:String = new String(currentMessage.@type);
				currentMsgType = currentMsgType.toLowerCase();
				if (currentMsgType == compareMsgType) {
					var messageStr:String = new String();
					messageStr = currentMessage.children()[0].toString();
					return (messageStr);
				}				
			}
			return (null);
		}
		
		public static function getControlResponse(status:int):String {
			if (status<0) {
				return (null);
			}			
			var messages:XMLList = TorResponseTable.child("status");
			for (var count:uint = 0; count < messages.length(); count++) {
				var currentMessage:XML = messages[count] as XML;
				var currentMsgStatusStr:String = new String(currentMessage.@type);
				var currentMsgStatus:int = int(currentMsgStatusStr);				
				if (status == currentMsgStatus) {
					var messageStr:String = new String();
					messageStr = currentMessage.children()[0].toString();
					return (messageStr);
				}				
			}
			return (null);
		}		
		
		public static function isControlResponseError(status:int):Boolean {
			if (status<0) {
				return (false);
			}			
			var messages:XMLList = TorResponseTable.child("errorstatus");
			for (var count:uint = 0; count < messages.length(); count++) {
				var currentMessage:XML = messages[count] as XML;
				var currentMsgStatusStr:String = new String(currentMessage.@type);
				var currentMsgStatus:int = int(currentMsgStatusStr);				
				if (status == currentMsgStatus) {					
					return (true);
				}				
			}
			return (false);
		}		
		
	}

}