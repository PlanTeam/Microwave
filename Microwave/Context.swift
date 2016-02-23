//
//  Context.swift
//  Microwave
//
//  Created by Joannis Orlandos on 20/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import PlanTCP
import When

public enum MicrowaveError : ErrorType {
    case IncorrectRequest
    case InternalError
}

public class HttpClient {
    internal let socket: Int32
    public let context: Context
    public private(set) var webSocket: Bool = false
    
    internal init(socket: Int32, context: Context) {
        self.socket = socket
        self.context = context
    }
}

public class Context {
    public let requestProtocol: String
    public let host: String
    public let method: String
    public let path: String
    public private(set) var headers: [String: String]
    
    internal let server: Microwave
    internal let client: Int32
    public private(set) var socketClient: HttpClient!
    
    internal init(server: Microwave, client: Int32, requestProtocol: String, headers: [String: String], host: String, method: String, path: String) {
        self.requestProtocol = requestProtocol
        self.host = host
        self.method = method
        self.path = path
        
        self.server = server
        self.client = client
        self.headers = headers
        self.socketClient = HttpClient(socket: client, context: self)
    }
    
    internal init(server: Microwave, client: Int32, request: String) throws {
        var lines = request.componentsSeparatedByString("\r\n")
        
        guard lines.count > 1 else {
            throw MicrowaveError.IncorrectRequest
        }
        
        let lineOne = lines.removeFirst()
        let lineOnePieces = lineOne.componentsSeparatedByString(" ")
        
        guard lineOnePieces.count == 3 else {
            throw MicrowaveError.IncorrectRequest
        }
        
        self.server = server
        self.client = client
        
        self.method = lineOnePieces[0]
        self.path = lineOnePieces[1]
        self.requestProtocol = lineOnePieces[2]
        self.headers = [String: String]()
        
        for line in lines where line != "" {
            if let linePieces: [String] = line.characters.split(" ", maxSplit: 1, allowEmptySlices: false).map(String.init) {
                guard linePieces.count == 2 else {
                    throw MicrowaveError.IncorrectRequest
                }
                
                headers[linePieces[0].stringByReplacingOccurrencesOfString(":", withString: "")] = linePieces[1]
            }
        }
        
        self.host = headers["Host"] ?? ""
        self.socketClient = HttpClient(socket: client, context: self)
    }
    
    public func respond(data: [UInt8], autoClose: Bool = true) throws {
        try server.server.send(client, buffer: data)
        
        if autoClose {
            server.server.closeClient(client)
        }
    }
    
    internal func convertToWebsocket(client client: WebSocketClient) -> ThrowingFuture<Void> {
        socketClient.webSocket = true
        
        let future = ThrowingFuture<Void> {
            while self.server.connected {
                try client.receiveData(try self.server.server.receive(self.client))
            }
        }
        
        return future
    }
}