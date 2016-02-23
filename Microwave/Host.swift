//
//  Host.swift
//  Microwave
//
//  Created by Joannis Orlandos on 21/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

public typealias Responder = ((context: Context) throws -> Void)
public typealias WebSocketHandler = ((WebSocketClient) throws -> Void)
public typealias Matcher = ((context: Context) throws -> Bool)
public typealias URLHandler = ((context: Context) throws -> [UInt8])
public typealias SimpleURLHandler = ((context: Context) throws -> String)
public typealias NonRespondingHandler = ((context: Context) throws -> Void)

public enum Response {
    case Able(responder: Responder)
    case Unable
}

public protocol Host {
    func handleRequest(context: Context) throws -> Response
}

public class SimpleHost : Host {
    public let host: String
    public let port: UInt16
    
    private var handlers = [(Matcher, NonRespondingHandler)]()
    
    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }
    
    public func addNonRespondingHandler(url: String, handler: NonRespondingHandler) {
        let matcher: Matcher = { context in
            return context.path == url
        }
        
        handlers.append((matcher, handler))
    }
    
    public func addURLhandler(url: String, handler: URLHandler) {
        let matcher: Matcher = { context in
            return context.path == url
        }
        
        let nonRespondingHandler: NonRespondingHandler = { context in
            try context.respond(handler(context: context))
        }
        
        handlers.append((matcher, nonRespondingHandler))
    }
    
    public func addURLhandler(url: String, handler: SimpleURLHandler) {
        let matcher: Matcher = { context in
            return context.path == url
        }
        
        let URLhandler: NonRespondingHandler = { context in
            let response: [UInt8]
            
            do {
                response = UInt8ResponseBuilder(responseCode: .OK, contentType: "text/html", headers: [String: String](), body: try handler(context: context)).generate()
            } catch {
                response = context.server.generateErrorPage()
            }
            
            try context.respond(response)
        }
        
        handlers.append((matcher, URLhandler))
    }
    
    public func handleRequest(context: Context) throws -> Response {
        guard context.host == "\(host):\(port)" else {
            return .Unable
        }
        
        return Response.Able { context in
            for handler in self.handlers {
                do {
                    if try handler.0(context: context) {
                        try handler.1(context: context)
                        
                        return
                    }
                } catch {}
            }
            
            if context.server.server.connected {
                var response = [UInt8]()
                response.appendContentsOf(context.server.generateErrorPage())
                try context.respond(response)
            }
        }
    }
}