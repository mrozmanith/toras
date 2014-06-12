package org.torproject.model.tor  {
	
	import flash.events.EventDispatcher;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.utils.ByteArray;
	import flash.utils.CompressionAlgorithm;
	import org.torproject.events.DirAuthorityEvent;
	import flash.utils.setTimeout;
	/**
	 * Functionality and information associated with a top-level Directory Authority for the Tor network.
	 * 
	 * See: https://gitweb.torproject.org/torspec.git/blob/HEAD:/dir-spec.txt
	 * 
	 * @author Patrick Bay
	 * 
	 * The MIT License (MIT)
	 * 
	 * Copyright (c) 2014 Patrick Bay
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
	public class DirAuthority extends EventDispatcher {
		
		private var _name:String = "";
		private var _ip:String = "";
		private var _directoryPort:uint = 0;
		private var _orPort:uint = 0;
		private var _v3Ident:String = "";
		private var _fingerprint:String = "";
		
		private static const CONCAT_ALL_DESC:String = "/tor/server/all";
		private static const CONCAT_COMP:String = ".z";
		
		private var _rawDescriptorData:String;
		private var _descriptorDataCompressed:Boolean = false;
		private var _parseAsynch:Boolean = true;
		private var _currentParsePosition:Number = 0;
		private var _descriptorLoader:URLLoader = null;
		private var _routers:Vector.<Router> = new Vector.<Router>();
		
		public function DirAuthority(dName:String = "", dIP:String = "", dDPort:uint = 0, dOrPort:uint = 0, dV3Ident:String = "", dFingerPrint:String = "") {
			this.name = dName;
			this.ip = dIP;			
			this.directoryPort = dDPort;
			this.orPort = dOrPort;
			this.v3Ident =  dV3Ident;
			this.fingerprint = dFingerPrint;
		}
		
		/**
		 * Loads all descriptors stored by this Directory Authority. Descriptor records are parsed
		 * into native types (for example, Router instances).
		 * 
		 * @param useCompression If true, descriptor data is transmitted using zlib compression (more processor-heavy). If false, raw text data is transmitted (larger).
		 * @param parseAsynch If true, descriptors will be parsed asynchronously (preferred due to the average size of the descriptor data). If false, parsing will 
		 * be done in a single loop (faster but may cause script timeouts).
		 */
		public function loadAllDescriptors(useCompression:Boolean = true, parseAsynch:Boolean=true):void {			
			this._descriptorDataCompressed = useCompression;
			this._parseAsynch = parseAsynch;
			this._descriptorLoader = new URLLoader();
			var url:String = "http://" + this.ip + ":" + this.directoryPort + CONCAT_ALL_DESC;			
			this._descriptorLoader.dataFormat = URLLoaderDataFormat.TEXT;
			if (useCompression) {
				url = url + CONCAT_COMP;
				this._descriptorLoader.dataFormat = URLLoaderDataFormat.BINARY;
			}//if			
			var request:URLRequest = new URLRequest(url);			
			this._descriptorLoader.addEventListener(Event.COMPLETE, this.onLoad);
			this._descriptorLoader.addEventListener(IOErrorEvent.IO_ERROR, this.onLoadError);
			this._descriptorLoader.load(request);
		}//loadAllDescriptors
		
		public function get rawDescriptors():String {
			return (this._rawDescriptorData);
		}//get rawDescriptors
		
		public function get routers():Vector.<Router> {
			return (this._routers);
		}
		
		private function onLoad(eventObj:Event):void {			
			try {
				this._descriptorLoader.removeEventListener(Event.COMPLETE, this.onLoad);
				this._descriptorLoader.removeEventListener(IOErrorEvent.IO_ERROR, this.onLoadError);
			} catch (err:*) {				
			}//catch
			if (eventObj.type == Event.COMPLETE) {
				//Broadcast ONLOAD event...
				this._rawDescriptorData = new String();
				if (this._descriptorDataCompressed) {
					var ba:ByteArray = new ByteArray();
					ba.writeUTFBytes(this._descriptorLoader.data);
					ba.position = 0;
					ba.uncompress(CompressionAlgorithm.ZLIB); //Doesn't currently work (neither does DEFLATE)! Something weird in Tor's ZLIB implementation? Another format?					
					ba.position = 0;
					this._rawDescriptorData = ba.readUTFBytes(ba.length);
				} else {
					this._rawDescriptorData = this._descriptorLoader.data;
				}//else
				this.parseDescriptors();
			}//if
		}//onLoad
		
		private function parseDescriptors():void {
			this._currentParsePosition = 0;
			if (this._parseAsynch) {
				this.parseDescsAsynch();
			} else {	
				//This will catch only one timeout
				try {
					while (this._currentParsePosition < this._rawDescriptorData.length) {
						var sectionEnd:Number = this._rawDescriptorData.indexOf("\nrouter ", this._currentParsePosition);
						var section:String = this._rawDescriptorData.substring(this._currentParsePosition, sectionEnd);			
						this._currentParsePosition = sectionEnd+1;
						this._routers.push(new Router(section));				
					}//while
					//Broadcast ONPARSE event...
				} catch (err:*) {					
				}//catch
			}//else
		}//parseDescriptors
		
		private function parseDescsAsynch():void {						
			//Process 1000 descriptors per iteration
			for (var count:uint = 0; count < 1000; count++) {
				var sectionEnd:Number = this._rawDescriptorData.indexOf("\nrouter ", this._currentParsePosition);
				var section:String = this._rawDescriptorData.substring(this._currentParsePosition, sectionEnd);			
				this._currentParsePosition = sectionEnd+1;
				this._routers.push(new Router(section));
				if (this._currentParsePosition >= this._rawDescriptorData.length) {
					//Broadcast ONPARSE event...
					return;
				}//if
			}//for
			setTimeout(this.parseDescsAsynch, 10); //10ms timer
		}//parseDescsAsynch
		
		private function onLoadError(eventObj:*):void {
			trace ("onLoadError "+eventObj);
			try {
				this._descriptorLoader.removeEventListener(Event.COMPLETE, this.onLoad);
				this._descriptorLoader.removeEventListener(IOErrorEvent.IO_ERROR, this.onLoadError);
			} catch (err:*) {				
			}//catch
		}//onLoadError
		
		public function get name():String {
			return (this._name);
		}
		
		public function set name (nameSet:String):void {
			this._name = nameSet;
		}
		
		public function get ip():String {
			return (this._ip);
		}
		
		public function set ip (ipSet:String):void {
			this._ip = ipSet;
		}
		
		public function get directoryPort():uint {
			return (this._directoryPort);
		}
		
		public function set directoryPort (dpSet:uint):void {
			this._directoryPort = dpSet;
		}		
		
		public function get orPort():uint {
			return (this._orPort);
		}
		
		public function set orPort (opSet:uint):void {
			this._orPort = opSet;
		}
		
		
		public function get v3Ident():String {
			return (this._v3Ident);
		}
		
		public function set v3Ident (v3idSet:String):void {
			this._v3Ident = v3idSet;
		}
		
		public function get fingerprint():String {
			return (this._fingerprint);
		}
		
		public function set fingerprint (fpSet:String):void {
			this._fingerprint = fpSet;
		}
		
		override public function toString():String {
			var retString:String = new String();
			retString = "[Object DirAuthority]\n";
			retString += "  Name        : " + this.name +"\n";
			retString += "  IP          : " + this.ip +"\n";
			retString += "  dirPort     : " + this.directoryPort +"\n";
			retString += "  orPort      : " + this.orPort +"\n";
			retString += "  Fingerprint : " + this.fingerprint +"\n";
			retString += "  V3 identity : " + this.v3Ident +"\n";
			return (retString);
		}
		
	}

}