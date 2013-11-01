package  {
	
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileStream;
	import flash.filesystem.FileMode;
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import org.torproject.events.TorControlEvent;
	import org.torproject.TorControl;
	/**
	 * Sample class to demonstrate dynamically launching Tor network connectivity using the included
	 * application package within an AIR app, then using it to both send and receive HTTP requests as 
	 * well control the Tor network client via its public API.
	 * 
	 * @author Patrick Bay
	 */
	public class TorLauncher extends MovieClip {
		
		private static var torProcess:NativeProcess=null;
		private static var torControl:TorControl=null;
		public static const rootTorPath:String = "./Tor/"; 
		public static const executable:String = "tor.exe"; 
		public static const configFile:String = "torrc"; 		
		public static const controlPassHash:String = "";
		public static const configData:XML =<config><![CDATA[# Tor Configuration Options, written to torrc
ControlPort 9151
ControlListenAddress 127.0.0.1
ClientOnly 1
SOCKSListenAddress 127.0.0.1:1080			
         ]]></config>
		
		public function TorLauncher() {
			//Ensure everything has been instantiated and initialized first...
			this.addEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);			
		}	
		
		private function onAddedToStage(eventObj:Event):void {
			this.removeEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);
			this.launchTorProcess();
		}		
		
		private function launchTorControl():void {
			if (torControl==null) {
				torControl = new TorControl("127.0.0.1", 9151, controlPassHash);
				torControl.addEventListener(TorControlEvent.ONAUTHENTICATE, this.onTorControlReady);
				torControl.connect();
			}//if
		}
		
		private function launchTorProcess():void {
			if (NativeProcess.isSupported) {
				var launchInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
				var exeDirectory:File = File.applicationDirectory;
				var exeFile:File = File.applicationDirectory;
				var cfgFile:File = File.applicationStorageDirectory;				
				exeFile = exeFile.resolvePath(rootTorPath+executable);
				exeDirectory = exeDirectory.resolvePath(rootTorPath);				
				cfgFile = cfgFile.resolvePath(configFile);
				this.generateConfigFile(cfgFile); //Simply ensures that it always exists with expected data (see above)
				launchInfo.executable = exeFile;
				launchInfo.workingDirectory = exeDirectory;
				launchInfo.arguments.push("-f");
				launchInfo.arguments.push(cfgFile.nativePath);
				torProcess = new NativeProcess();
				//Debug and log data are received over STDOUT
				torProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, this.onStandardOutData);
				torProcess.start(launchInfo);
				this.launchTorControl();
			} else {
				trace ("NativeProcess is not supported. Tor must be started manually.");
			}
		}
		
		private function generateConfigFile(configFile:File):void {
			var stream:FileStream = new FileStream();
			trace ("Opening: " + configFile.nativePath);
			stream.open(configFile, FileMode.WRITE);
			stream.writeMultiByte(configData.children()[0].toString(), "iso-8859-1");
			stream.close();
		}
		
		private function onStandardOutData(eventObj:ProgressEvent):void {
			var stdoutMsg:String = torProcess.standardOutput.readMultiByte(torProcess.standardOutput.bytesAvailable, "iso-8859-1");
			trace ("Tor.exe > " + stdoutMsg);
		}
		
		private function onTorControlReady(eventObj:TorControlEvent):void {
			trace ("TorLauncher > Tor control reports that it's ready to receive commands.");
		}
		
	}

}