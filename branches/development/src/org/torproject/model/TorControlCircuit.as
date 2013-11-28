package org.torproject.model {
	
	import org.torproject.model.TorControlCircuitHop;
	
	/**
	 * Parses and stores information on an established Tor circuit. The raw data for this class is supplied via a Tor circuit string such as would be 
	 * received with a TorControlEvent.TOR_CIRC event.
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
	public class TorControlCircuit {
		
		public static const circuitDataDelimiter:String = String.fromCharCode(32);
		public static const circuitDataSectionDelimiter:String = ",";
		public static const circuitTailDataDelimiter:String = "=";
		
		private var _rawCircuitData:String = null;
		private var _circuitID:int = -1;
		private var _circuitStatus:String = null;
		private var _circuitPath:String = null;		
		private var _circuitHops:Vector.<TorControlCircuitHop> = null;
		private var _circuitFlags:Vector.<String> = null;
		private var _circuitTimeCreated:String = null;
		private var _circuitPurpose:String = null;
		private var _circuitHSState:String = null;
		private var _circuitHSAddress:String = null;
		private var _circuitReason:String = null;
		private var _circuitRemoteReason:String = null;
		private var _isValid:Boolean = false;
		
		public function TorControlCircuit(circuitData:String) {
			if ((rawCircuitData != null ) && (rawCircuitData != "")) {
				this._rawCircuitData = circuitData;
			}//if
		}//TorControlCircuit
		
		/**
		 * Returns true if the supplied Tor circuit data appears to be valid and could be parsed successfully, false otherwise.
		 */
		public function get isValid():Boolean {
			return (this._isValid);
		}//get isValid
		
		/**
		 * Gets the raw, unparsed circuit data supplied to the TorControlCircuit instance.
		 */
		public function get rawCircuitData():String {
			return (this._rawCircuitData);
		}//get rawCircuitData
		
		private function parseCircuitData():void {
			try {
				var dataSplit:Array = this._rawCircuitData.split(circuitDataDelimiter);
				this._circuitID = new int(dataSplit[0] as String);
				this._circuitStatus = new String(dataSplit[1] as String);
				this._circuitPath = new String(dataSplit[2] as String);
				for (var count:uint = 3; count < dataSplit.length; count++) {
					var circuitTail:String = dataSplit[count] as String;
					var tailElementName:String = new String(circuitTail.split(circuitTailDataDelimiter)[0] as String);
					var tailElementValue:String = new String(circuitTail.split(circuitTailDataDelimiter)[1] as String);
					switch (tailElementName.toUpperCase()) {
						case "BUILD_FLAGS" :
							this.parseCircuitFlags(tailElementValue);
							break;
						case "PURPOSE" :
							this._circuitPurpose = tailElementValue;
							break;
						case "TIME_CREATED" :
							this._circuitTimeCreated = tailElementValue;
							break;
						case "REASON" :
							this._circuitReason = tailElementValue;
							break;	
						case "HS_STATE" :
							this._circuitHSState = tailElementValue;
							break;	
						case "REND_QUERY" :
							this._circuitHSAddress = tailElementValue;
							break;	
						case "REMOTE_REASON" :
							this._circuitRemoteReason = tailElementValue;
							break;
						default: break;
					}//switch
				}//for
			} catch (err:*) {
				this._isValid = false;
			}//catch
		}//parseCircuitData
		
		private function parseCircuitHops():void {
			if ((this._circuitPath == null) || (this._circuitPath == "")) {
				return;
			}//if
			var hopParts:Array = this._circuitPath.split(circuitDataSectionDelimiter);
			this._circuitHops = new Vector.<TorControlCircuitHop>();
			for (var count:uint = 0; count < hopParts.length; count++) {
				var currentHopString:String = hopParts[count] as String;
				var circuitHop:TorControlCircuitHop = new TorControlCircuitHop(currentHopString);
				if (circuitHop.isValid) {
					this._circuitHops.push(circuitHop);
				}//if
			}//for
		}//parseCircuitHops
		
		private function parseCircuitFlags(flagsData:String=null):void {
			if ((flagsData == null) || (flagsData == "")) {
				return;
			}//if
			var flagsSplit:Array = flagsData.split(circuitDataSectionDelimiter);
			this._circuitFlags = new Vector.<String>();
			for (var count:uint = 0; count < flagsSplit.length; count++) {
				var currentFlag:String = new String(flagsSplit[count] as String);
				if ((currentFlag != null) && (currentFlag != "")) {
					this._circuitFlags.push(currentFlag);
				}//if
			}//for
		}//parseCircuitFlags		
		
	}//TorControlCircuit class

}//package