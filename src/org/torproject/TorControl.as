package org.torproject  {
	
	import flash.events.EventDispatcher;
	import flash.net.Socket;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileStream;
	import flash.filesystem.FileMode;
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import org.torproject.events.TorControlEvent;
	import org.torproject.model.TorControlModel;
	import flash.utils.setTimeout;
	
	/**
	 * Provides control and event handling services for core Tor services.
	 * 
	 * @author Patrick Bay
	 * 
	 * v1.1 
	 */
	public class TorControl extends EventDispatcher {
		
		private static var torProcess:NativeProcess=null; //Native process running core Tor services
		private static const defaultControlIP:String = "127.0.0.1"; //Default control IP (usually 127.0.0.1)
		private static const defaultControlPort:int = 9151; //Default control port (usualy 9151)
		private static const defaultSOCKSIP:String = "127.0.0.1"; //Default SOCKS IP (usually 127.0.0.1)
		private static const defaultSOCKSPort:int = 1080; //Default SOCKS port (usualy 1080)
		private var _controlIP:String = defaultControlIP; //Assign defaults
		private var _controlPort:int = defaultControlPort;
		private var _SOCKSIP:String = defaultSOCKSIP; 
		private var _SOCKSPort:int = defaultSOCKSPort;
		private var _controlPassHash:String = ""; //Password hash (not yet implemented)
		private var _socket:Socket = null; //The actual control socket
		private var _connectDelay:Number = 1; //The delay, in seconds, to hold before attempting to connect to the control socket
		//Both of the following must be true before further commands can be issued:
		private var _connected:Boolean = false; //Is control socket connected?
		private var _authenticated:Boolean = false; //Has control socket authenticated?
		public static const rootTorPath:String = "./Tor_x86/"; //Relative path (to the output SWF / AIR file) to the Tor binary directory
		public static const executable:String = "tor.exe"; //Differs based on OS -- how best to dynamically control this?
		public static const configFile:String = "torrc"; //Standard config file name
		public static const controlPassHash:String = ""; //Control socket password hash (not yet implemented)
		/**
		 * The contents of the <config> node are parsed and used to generate the config file (specified above).
		 * Meta information may be included in the information. This includes:
		 * %control_ip% - The control IP currently being used by the TorControl instance and running Tor services.
		 * %control_port% - The control port currently being used by the TorControl instance and running Tor services.
		 * %socks_ip% - The SOCKS IP currently being used by the running Tor proxy.
		 * %socks_port% - The SOCKS port currently being used by the running Tor proxy.
		 * %control_passhash% - The control pasword authentication hash (not yet supported)
		 */
		public static const configData:XML =<config><![CDATA[# TorAS Dynamic Configuration -- generated by TorControl.as
ControlPort %control_port%
ControlListenAddress %control_ip%
ClientOnly 1
SOCKSListenAddress %socks_ip%:%socks_port%
]]></config>
		private var _synchResponseBuffer:String = new String(); //Used to buffer multi-line messages
		private var _asynchEventBuffer:String = new String(); //Used to buffer multi-line messages
		private var _synchRawResponseBuffer:String = new String(); //Used to buffer multi-line messages in their raw state
		private var _asynchRawEventBuffer:String = new String(); //Used to buffer multi-line messages in their raw state
		private var _enabledEvents:Array = new Array(); //Tracks which asynchronous Tor control events are enabled
		
		public function TorControl(controlIP:String = defaultControlIP, controlPort:int = defaultControlPort, 
									SOCKSIP:String=defaultSOCKSIP, SOCKSPort:int=defaultSOCKSPort,
									controlPassHash:String="", connectDelay:Number=1) {
			this._controlIP = controlIP;
			this._controlPort = controlPort;
			this._SOCKSIP = SOCKSIP;
			this._SOCKSPort = SOCKSPort;
			this._controlPassHash = controlPassHash;
			this._connectDelay = connectDelay*1000;
		}//constructor
		
		public function connect(... args):void {
			this.launchTorProcess();
			if (this._socket == null) {
				if ((this._connectDelay > 0) && (args[0]!=true)){
					setTimeout(this.connect, this._connectDelay, true);					
					return;
				}//if				
				this._socket = new Socket(this._controlIP, this._controlPort);
				this._socket.addEventListener(Event.CONNECT, this.onConnect);
				this._socket.addEventListener(ProgressEvent.SOCKET_DATA, this.onData);				
			} else {				
			}//else
		}//connect
		
		private function launchTorProcess():void {
			if (torProcess != null) {
				return;
			}//if
			if (NativeProcess.isSupported) {
				try {
					var launchInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
					var exeDirectory:File = File.applicationDirectory;
					var exeFile:File = File.applicationDirectory;
					var cfgFile:File = File.applicationStorageDirectory;				
					exeFile = exeFile.resolvePath(rootTorPath + executable);
					exeDirectory = exeDirectory.resolvePath(rootTorPath);				
					cfgFile = cfgFile.resolvePath(configFile);
					this.generateConfigFile(cfgFile); //Ensures that config data always exists as expected.
					launchInfo.executable = exeFile;
					launchInfo.workingDirectory = exeDirectory;
					launchInfo.arguments.push("-f");
					launchInfo.arguments.push(cfgFile.nativePath);
					torProcess = new NativeProcess();
					//Debug and log data are received over STDOUT
					torProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, this.onStandardOutData);
					torProcess.start(launchInfo);
				} catch (err:*) {
					trace ("TorControl.launchTorProcess > Exception thrown: "+err);
				}//catch
			} else {
				trace ("TorControl.launchTorProcess > NativeProcess is not supported. Tor must be started manually.");
			}//else
		}//launchTorProcess
		
		private function generateConfigFile(configFile:File):void {
			var stream:FileStream = new FileStream();
			stream.open(configFile, FileMode.WRITE);
			var configString:String = new String(configData.children()[0].toString());
			configString = this.replaceMeta(configString, "%control_ip%", String(this._controlIP));
			configString = this.replaceMeta(configString, "%control_port%", String(this._controlPort));
			configString = this.replaceMeta(configString, "%control_passhash%", String(this._controlPassHash));
			configString = this.replaceMeta(configString, "%socks_ip%", String(this._SOCKSIP));
			configString = this.replaceMeta(configString, "%socks_port%", String(this._SOCKSPort));
			stream.writeMultiByte(configString, TorControlModel.charSetEncoding);
			stream.close();
		}//generateConfigFile
		
		private function onStandardOutData(eventObj:ProgressEvent):void {
			var stdoutMsg:String = torProcess.standardOutput.readMultiByte(torProcess.standardOutput.bytesAvailable, TorControlModel.charSetEncoding);
			var event:TorControlEvent = new TorControlEvent(TorControlEvent.ONLOGMSG);
			event.body = stdoutMsg;
			event.rawMessage = stdoutMsg;
			this.dispatchEvent(event);
		}//onStandardOutData
		
		private function onConnect(eventObj:Event):void {
			trace ("TorControl.onConnect >> Connected to Tor control socket at " + this._controlIP + ":" + this._controlPort);
			this._connected = true;
			this.dispatchEvent(new TorControlEvent(TorControlEvent.ONCONNECT));
			this.authenticate();
		}//onConnect
		
		private function authenticate():void {
			this._authenticated = false;
			this.sendRawControlMessage(TorControlModel.getControlMessage("authenticate"));
		}//authenticate
		
		public function enableTorEvent(eventType:String):void {
			var torMessage:String = TorControlModel.getControlMessage("enableevent");
			this.addUniqueAsyncEvent(eventType);
			trace ("TorControl.enableTorEvent > " + eventType + " -- Active events: " + this.enabledAsyncEventList);
			torMessage = this.replaceMeta(torMessage, "%event_list%", this.enabledAsyncEventList);
			this.sendRawControlMessage(torMessage);
		}//enableTorEvent
		
		public function disableTorEvent(eventType:String):void {
			var torMessage:String = TorControlModel.getControlMessage("enableevent");
			this.removeAsyncEvent(eventType);
			trace ("TorControl.disableTorEvent > " + eventType + " -- Active events: " + this.enabledAsyncEventList);
			torMessage = this.replaceMeta(torMessage, "%event_list%", this.enabledAsyncEventList);
			this.sendRawControlMessage(torMessage);
		}//disableTorEvent
		
		public function disableAllTorEvents():void {
			var torMessage:String = TorControlModel.getControlMessage("enableevent");
			 this._enabledEvents = new Array();
			trace ("TorControl.disableAllTorEvents > Active events: " + this.enabledAsyncEventList);
			torMessage = this.replaceMeta(torMessage, "%event_list%", this.enabledAsyncEventList);
			this.sendRawControlMessage(torMessage);
		}//disableAllTorEvents
		
		private function get enabledAsyncEventList():String {
			var list:String = new String();
			for (var count:uint = 0; count < this._enabledEvents.length; count++) {
				var currentEvent:String = this._enabledEvents[count] as String;
				list += currentEvent + " ";
			}//for
			list=list.substr(0, (list.length-1))
			return (list);
		}//get enabledAsyncEventList
		
		private function addUniqueAsyncEvent(eventType:String):void {
			for (var count:uint = 0; count < this._enabledEvents.length; count++) {
				var currentEvent:String = this._enabledEvents[count] as String;
				if (currentEvent == eventType) {
					return;
				}//if
			}//for
			this._enabledEvents.push(eventType);
		}//addUniqueAsyncEvent
		
		private function removeAsyncEvent(eventType:String):void {
			var condensedEvents:Array = new Array();
			for (var count:uint = 0; count < this._enabledEvents.length; count++) {
				var currentEvent:String = this._enabledEvents[count] as String;
				if (currentEvent != eventType) {
					condensedEvents.push(currentEvent);
				}//if
			}//for
			this._enabledEvents = condensedEvents;
		}//removeAsyncEvent
		
		public function sendRawControlMessage(msg:String):Boolean {
			if ((!this._connected) || (this._socket == null)) {
				return (false);
			}//if
			this._synchResponseBuffer = "";
			this._synchRawResponseBuffer = "";
			msg = msg + TorControlModel.controlLineEnd;
			this._socket.writeMultiByte(msg, TorControlModel.charSetEncoding);
			this._socket.flush();
			return (true);
		}//sendRawControlMessage
		
		private function onData(eventObj:ProgressEvent):void {
			var receivedMsg:String = this._socket.readMultiByte(this._socket.bytesAvailable, TorControlModel.charSetEncoding);
			receivedMsg = receivedMsg.split(String.fromCharCode(10)).join("");
			var msgSplit:Array = receivedMsg.split(String.fromCharCode(13));
			for (var count:uint = 0; count < msgSplit.length; count++) {
				var currentLine:String = msgSplit[count] as String;
				var msgObj:Object = this.parseReceivedData(currentLine);
				if (msgObj.status == TorControlModel.asynchEventStatusCode) {
					//trace ("TorControl.onData > Received asynchronous event: "+msgObj.status+" "+msgObj.body);
					//Asynchronous notification;
					this._asynchEventBuffer += msgObj.body;
					this._asynchRawEventBuffer += receivedMsg;
					if (this.isMultilineMessage(msgObj.multilineStatusIndicator)) {
						this._asynchEventBuffer += TorControlModel.controlLineEnd;
						this._asynchRawEventBuffer += TorControlModel.controlLineEnd;
					} else {
						this.dispatchAsynchTorEvent(msgObj);
						this._asynchEventBuffer = "";
						this._asynchRawEventBuffer = "";
					}//else
					return;
				} else if ((!this._authenticated) && (!TorControlModel.isControlResponseError(msgObj.status))) {
					//Authentication response
				//	trace ("TorControl.onData > Received control authentication response: "+msgObj.status+" "+msgObj.body);				
					this._authenticated = true;
					var event:TorControlEvent = new TorControlEvent(TorControlEvent.ONAUTHENTICATE);
					event.status = msgObj.status;
					event.body = msgObj.body;
					event.rawMessage = receivedMsg;
					this.dispatchEvent(event);
					return;
				} else {
					//Standard synchronous response			
					this._synchResponseBuffer += msgObj.body;
					this._synchRawResponseBuffer += receivedMsg;
					if (this.isMultilineMessage(msgObj.multilineStatusIndicator)) {
						this._synchResponseBuffer += TorControlModel.controlLineEnd;
						this._synchRawResponseBuffer += TorControlModel.controlLineEnd;
					} else {
						this.dispatchTorResponse(msgObj);
						this._synchResponseBuffer = "";
						this._synchRawResponseBuffer = "";
					}//else
				}//else
			}//for
		}//onData
		
		private function isMultilineMessage(separator:String):Boolean {
			if (separator == " ") {
				return (false);
			} else {
				return (true);
			}//else
		}//isMultilineMessage
		
		private function dispatchAsynchTorEvent(msgObj:Object):void {
			var event:TorControlEvent = new TorControlEvent(TorControlEvent.ONEVENT);
			event.status = msgObj.status;
			event.body = this._asynchEventBuffer;
			var eventType:String = msgObj.body;
			eventType = eventType.split(" ")[0] as String;
			event.torEvent = eventType;
			event.rawMessage = this._asynchRawEventBuffer;
			this.dispatchEvent(event);
		}//dispatchAsynchTorEvent
		
		private function dispatchTorResponse(msgObj:Object):void {
			var event:TorControlEvent = new TorControlEvent(TorControlEvent.ONRESPONSE);
			event.status = msgObj.status;
			event.body = this._synchResponseBuffer;
			event.rawMessage = this._synchRawResponseBuffer;
			this.dispatchEvent(event);
		}//dispatchTorResponse
		
		private function parseReceivedData(dataStr:String):Object {
			var responseCodeStr:String = dataStr.substr(0, 3);
			var codeValue:int = new int(responseCodeStr);
			var multilineSeparator:String = dataStr.substr(3, 1);
			var responseBody:String = dataStr.substr(4);			
			var returnObj:Object = new Object();
			returnObj.status = codeValue;
			returnObj.multilineStatusIndicator = multilineSeparator;
			returnObj.body = responseBody;
			return (returnObj);
		}//parseReceivedData
		
		private function replaceMeta(input:String, meta:String, replace:String):String {
			return (input.split(meta).join(replace));
		}//replaceMeta
		
	}//TorControl class

}//package