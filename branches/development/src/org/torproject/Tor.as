package org.torproject {
	
	import flash.events.EventDispatcher;
	import flash.net.Socket;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.events.IOErrorEvent;	
	import flash.events.SecurityErrorEvent;
	import org.torproject.model.tor.DirAuthority;
	
	/**
	 * Main interface for connecting to and communicating with the Tor network directly
	 * (rather than using the Tor and SOCKS5Tunnel classes, for example).
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
	public class Tor {
		
		private var _dirAuthorities:Vector.<DirAuthority> = new Vector.<DirAuthority>();
		
		public function Tor():void {
			this.populateDefaultDirAuthorities();
		}//constructor
		
		public function get directoryAuthorities():Vector.<DirAuthority> {
			return (this._dirAuthorities);
		}
		
		private function populateDefaultDirAuthorities():void {
			/*As specified in config.c (Tor source):
			add_default_trusted_dir_authorities(dirinfo_type_t type)
			etc.
			*/
			this._dirAuthorities.push(new DirAuthority("moria1", "128.31.0.39", 9131, 9101, "D586D18309DED4CD6D57C18FDB97EFA96D330566", "9695 DFC3 5FFE B861 329B 9F1A B04C 4639 7020 CE31"));
			this._dirAuthorities.push(new DirAuthority("tor26", "86.59.21.38", 80, 443, "14C131DFC5C6F93646BE72FA1401C02A8DF2E8B4", "847B 1F85 0344 D787 6491 A548 92F9 0493 4E4E B85D"));
			this._dirAuthorities.push(new DirAuthority("dizum", "194.109.206.212", 80, 443, "E8A9C45EDE6D711294FADF8E7951F4DE6CA56B58", "7EA6 EAD6 FD83 083C 538F 4403 8BBF A077 587D D755"));
			this._dirAuthorities.push(new DirAuthority("Tonga", "82.94.251.203", 80, 443, "", "4A0C CD2D DC79 9508 3D73 F5D6 6710 0C8A 5831 F16D"));
			this._dirAuthorities.push(new DirAuthority("turtles", "76.73.17.194", 80, 9090, "27B6B5996C426270A5C95488AA5BCEB6BCC86956", "F397 038A DC51 3361 35E7 B80B D99C A384 4360 292B"));
			this._dirAuthorities.push(new DirAuthority("gabelmoo", "212.112.245.170", 80, 9090, "ED03BB616EB2F60BEC80151114BB25CEF515B226", "F204 4413 DAC2 E02E 3D6B CF47 35A1 9BCA 1DE9 7281"));
			this._dirAuthorities.push(new DirAuthority("dannenberg", "193.23.244.244", 80, 9090, "585769C78764D58426B8B52B6651A5A71137189A", "7BE6 83E6 5D48 1413 21C5 ED92 F075 C553 64AC 7123"));
			this._dirAuthorities.push(new DirAuthority("urras", "208.83.223.34", 443, 80, "80550987E1D626E3EBA5E5E75A458DE0626D088C", "0AD3 FA88 4D18 F89E EA2D 89C0 1937 9E0E 7FD9 4417"));
			this._dirAuthorities.push(new DirAuthority("maatuska", "171.25.193.9", 443, 80, "49015F787433103580E3B66A1707A00E60F2D15B", "BD6A 8292 55CB 08E6 6FBE 7D37 4836 3586 E46B 3810"));
			this._dirAuthorities.push(new DirAuthority("Faravahar", "154.35.32.5", 443, 80, "EFCBE720AB3A82B99F9E953CD5BF50F7EEFC7B97", "CF6D 0AAF B385 BE71 B8E1 11FC 5CFF 4B47 9237 33BC"));
		}
		
	}//Tor class	
	
}//package