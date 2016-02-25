//
//  WebSocket.swift
//  Microwave
//
//  Created by Joannis Orlandos on 22/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import When
import CryptoSwift

typealias WebSocketListener = ((websocket: WebSocketClient, message: WebSocketFrame) -> Void)

public class WebSocketClient {
    internal var client: HttpClient
    internal var listener: WebSocketListener
    
    internal func receiveData(data: [UInt8]) throws {
        let frame = try WebSocketFrame(fromBytes: data)
        
        listener(websocket: self, message: frame)
    }
    
    init(client: HttpClient, listener: WebSocketListener) {
        self.client = client
        self.listener = listener
    }
    
    public func selectProtocol(requestedProtocols: [String]) -> String {
        return requestedProtocols.first ?? ""
    }
    
    internal func badRequest() throws {
        let response = UInt8ResponseBuilder(responseCode: .BadRequest).generate()
        
        try client.context.respond(response)
        client.context.server.server.closeClient(client.socket)
    }
    
    public func respond(data: [UInt8]) throws {
        var frame = WebSocketFrame(withPayload: data, opcode: .Text)
        
        try client.context.respond(try frame.getBytes(), autoClose: false)
    }
    
    // TODO: Validate Origin
    // TODO: TLS
    public func respondToUpgrade() throws {
        let headers = client.context.headers
        
        guard headers.keys.contains("Connection") && headers.keys.contains("Sec-WebSocket-Key") && headers.keys.contains("Sec-WebSocket-Version") && headers.keys.contains("Upgrade") else {
            try badRequest()
            throw MicrowaveError.IncorrectRequest
        }
        
        guard headers["Connection"]?.lowercaseString == "upgrade" && headers["Sec-WebSocket-Version"] == "13" && headers["Upgrade"]?.lowercaseString == "websocket" else {
            try badRequest()
            throw MicrowaveError.IncorrectRequest
        }
        
//        let originalKey = NSData(base64EncodedString: headers["Sec-WebSocket-Key"] ?? "", options: NSDataBase64DecodingOptions(rawValue: 0))
//        
//        guard var originalKeyString: String = String(originalKey) else {
//            throw MicrowaveError.IncorrectRequest
//        }
        
        let stringThingy = (headers["Sec-WebSocket-Key"] ?? "") +  "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        
        var newKeyBytes = [UInt8]()
        newKeyBytes.appendContentsOf(stringThingy.utf8)
        
        let data =  NSData(bytes: newKeyBytes).sha1()
        
        guard let realData: NSData = data else {
            throw MicrowaveError.InternalError
        }
        
        let acceptKey = realData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding64CharacterLineLength)
        
        let protocols = headers["Sec-WebSocket-Protocol"]?.componentsSeparatedByString(",").map { $0.stringByReplacingOccurrencesOfString(" ", withString: "") }
        
        var responseString = "HTTP/1.1 101 Switching Protocols\r\n"
        responseString += "Connection: Upgrade\r\n"
        responseString += "Upgrade: websocket\r\n"
        responseString += "Sec-WebSocket-Accept: \(acceptKey)\r\n"
        
        let usedProtocol = selectProtocol(protocols ?? [])
        
        if !usedProtocol.isEmpty {
            responseString += "Sec-WebSocket-Protocol: \(usedProtocol)\r\n"
        }
//
//        for (key, value) in headers {
//            responseString += "\(key): \(value)\r\n"
//        }
        
        responseString += "\r\n"
        var responseData = [UInt8]()
        responseData.appendContentsOf(responseString.utf8)
        _ = client.context.convertToWebsocket(client: self).onError { _ in
            print("Error receiving data")
        }
        
        try client.context.respond(responseData, autoClose: false)
    }
}

