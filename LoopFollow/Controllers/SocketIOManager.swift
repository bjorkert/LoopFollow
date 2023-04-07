//
//  SocketIOManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-04-07.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
import SocketIO

class SocketIOManager {
    private let manager: SocketManager
    private let socket: SocketIOClient
    private let apiSecret: String
    
    init(url: URL, apiSecret: String) {
        self.apiSecret = apiSecret
        manager = SocketManager(socketURL: url, config: [.compress, .version(.two)]) //.log(true), .forceWebsockets(true)
        socket = manager.defaultSocket
        
        setupHandlers()
        socket.connect()
    }
    
    private func setupHandlers() {
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            guard let self = self else { return }
            print("Socket.IO connected")
            self.authorizeSocket()
        }
        
        socket.on(clientEvent: .disconnect) { data, ack in
            print("Socket.IO disconnected:", data)
        }
        
        socket.on("dataUpdate") { data, ack in
            print("Received dataUpdate:", Date())
        }
        
        //socket.onAny {print("Got event: \($0.event), with items: \($0.items!)")}
    }
    
    private func authorizeSocket() {
        //print("Authorizing socket")
        let authData: [String: Any] = [
            "client": "web",
            "secret": apiSecret
        ]
        
        socket.emitWithAck("authorize", authData).timingOut(after: 3) { data in
            //print("Authorization response:", data)
        }
    }
}
