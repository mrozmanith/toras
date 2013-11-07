package org.torproject.model {
	
	import flash.net.URLRequest;
	import flash.net.URLRequestDefaults;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import org.torproject.utils.URLUtil;
	
	/**
	 * Stores protocol lookup, message construction, and other information for use with the SOCKS5 tunnel connection.
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
	public class SOCKS5Model {
		
		public static const charSetEncoding:String = "iso-8859-1";
		public static const HTTP_request_prefix:String = "HTTP";
		public static const HTTP_version:String = "1.1";
		public static const lineEnd:String = String.fromCharCode(13) + String.fromCharCode(10);
		public static const doubleLineEnd:String = lineEnd+lineEnd;
		public static const commEnd:int = 0; //Byte
		
		//SOCKS5 version header (maybe support 4 some day?)
		public static const SOCKS5_head_VERSION:int = 5;
		
		// Authentication type constants
		public static const SOCKS5_auth_NUMMETHODS:int = 1; //Number of authentication methods supported (currently only one: NOAUTH)
		public static const SOCKS5_auth_NOAUTH:int = 0; //None
		public static const SOCKS5_auth_GSSAPI:int = 1; //GSSAPI
		public static const SOCKS5_auth_USER:int = 2; //Username & password
		
		//Connection type constants				
		public static const SOCKS5_conn_TCPIPSTREAM:int = 1; //TCP/IP streaming connection
		public static const SOCKS5_conn_TCPIPPORT:int = 2; //TCP/IP port binding
		public static const SOCKS5_conn_UDPPORT:int = 3; //UDP port binding
		
		//Address type constants				
		public static const SOCKS5_addr_IPV4:int = 1; //IPv4 address type
		public static const SOCKS5_addr_DOMAIN:int = 3; //Domain address type
		public static const SOCKS5_addr_IPV6:int = 4; //IPv6 address type
		
		//Connection response constants				
		public static const SOCKS5_resp_OK:int = 0; //OK response code
		public static const SOCKS5_resp_FAIL:int = 1; //General failure
		public static const SOCKS5_resp_NOTALLOWED:int = 2; //Connection not allowed
		public static const SOCKS5_resp_NETERROR:int = 3; //Network unreachable
		public static const SOCKS5_resp_HOSTERROR:int = 4; //Host unreachable
		public static const SOCKS5_resp_REFUSED:int = 5; //Connection refused
		public static const SOCKS5_resp_TTLEXP:int = 6; //TTL expired
		public static const SOCKS5_resp_CMDERROR:int = 7; //Command not supported
		public static const SOCKS5_resp_ADDRERROR:int = 8; //Address type not supported
		
		
		/**
		 * Creates a complete HTTP request string, complete with headers.
		 * 
		 * @param	request The URLRequest object to parse and create the request from.
		 * 
		 * @return A valid, complete HTTP request including request headers, etc., or null if one couldn't be created.
		 * 
		 */
		public static function createHTTPRequestString(request:URLRequest):String {
			if (request == null) {
				return (null);
			}//if
			var returnString:String = new String();
			returnString = request.method + " " + request.url + " " + HTTP_request_prefix + "/" + HTTP_version + lineEnd;
			returnString += "User-Agent: " + URLRequestDefaults.userAgent + lineEnd;
			returnString += "Host: "+ URLUtil.getServerName(request.url) + lineEnd;
			for (var count:uint = 0; count < request.requestHeaders.length; count++) {
				var currentHeader:URLRequestHeader = request[count] as URLRequestHeader;
				returnString += currentHeader.name + ": " + currentHeader.value + lineEnd;
			}//for			
			if (request.data != null) {
				returnString += lineEnd;
				//This is probably formatted differently!
				returnString += request.data;
			}//if			
			returnString += lineEnd+lineEnd;
			return (returnString);
		}//createHTTPRequestString
				
	}//SOCKS5Model class

}//package