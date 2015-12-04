//
//  PeerKit.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/5/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import Foundation
import MultipeerConnectivity

// MARK: Type Aliases

public typealias PeerBlock = ((myPeerID: MCPeerID, peerID: MCPeerID) -> Void)
public typealias EventBlock = ((peerID: MCPeerID, event: String, object: AnyObject?) -> Void)
public typealias ObjectBlock = ((peerID: MCPeerID, object: AnyObject?) -> Void)
public typealias ResourceBlock = ((myPeerID: MCPeerID, resourceName: String, peer: MCPeerID, localURL: NSURL) -> Void)

// MARK: Event Blocks

public var onConnecting: PeerBlock?
public var onConnect: PeerBlock?
public var onDisconnect: PeerBlock?
public var onEvent: EventBlock?
public var onEventObject: ObjectBlock?
public var onFinishReceivingResource: ResourceBlock?
public var eventBlocks = [String: ObjectBlock]()

// MARK: PeerKit Globals

#if os(iOS)
import UIKit
public let myName = String(UIDevice.currentDevice().hash)
#else
public let myName = NSHost.currentHost().localizedName ?? ""
#endif

public var transceiver = Transceiver(displayName: myName)
public var session: MCSession?

// MARK: Event Handling

func didConnecting(myPeerID: MCPeerID, peer: MCPeerID) {
    if let onConnecting = onConnecting {
        dispatch_async(dispatch_get_main_queue()) {
            onConnecting(myPeerID: myPeerID, peerID: peer)
        }
    }
}

func didConnect(myPeerID: MCPeerID, peer: MCPeerID) {
    if session == nil {
        session = transceiver.session.mcSession
    }
    if let onConnect = onConnect {
        dispatch_async(dispatch_get_main_queue()) {
            onConnect(myPeerID: myPeerID, peerID: peer)
        }
    }
}

func didDisconnect(myPeerID: MCPeerID, peer: MCPeerID) {
    if let onDisconnect = onDisconnect {
        dispatch_async(dispatch_get_main_queue()) {
            onDisconnect(myPeerID: myPeerID, peerID: peer)
        }
    }
}

func didReceiveData(data: NSData, fromPeer peer: MCPeerID) {
    if let dict = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? [String: AnyObject] {
        print("Received dictionary")
        if        let event = dict["event"] as? String {
            print("Received event \(event)")
        if let object: AnyObject? = dict["object"] {
            print("Received object")
            print("\tunarchived data from \(peer.displayName)")
            dispatch_async(dispatch_get_main_queue()) {
                if let onEvent = onEvent {
                    print("\tonEvent")
                    onEvent(peerID: peer, event: event, object: object)
                }
                if let eventBlock = eventBlocks[event] {
                    print("\teventBlock")
                    eventBlock(peerID: peer, object: object)
                }
            }
            }
        }
        }
        print("\tEnd of didReceiveData from \(peer.displayName)")
}

func didFinishReceivingResource(myPeerID: MCPeerID, resourceName: String, fromPeer peer: MCPeerID, atURL localURL: NSURL) {
    if let onFinishReceivingResource = onFinishReceivingResource {
        dispatch_async(dispatch_get_main_queue()) {
            onFinishReceivingResource(myPeerID: myPeerID, resourceName: resourceName, peer: peer, localURL: localURL)
        }
    }
}

// MARK: Advertise/Browse

public func transceive(serviceType: String, discoveryInfo: [String: String]? = nil) {
    transceiver.startTransceiving(serviceType: serviceType, discoveryInfo: discoveryInfo)
}

public func advertise(serviceType: String, discoveryInfo: [String: String]? = nil) {
    transceiver.startAdvertising(serviceType: serviceType, discoveryInfo: discoveryInfo)
}

public func browse(serviceType: String) {
    transceiver.startBrowsing(serviceType: serviceType)
}

public func stopTransceiving() {
    transceiver.stopTransceiving()
    session = nil
}

// MARK: Events

public func sendEvent(event: String, object: AnyObject? = nil, toPeers peers: [MCPeerID]? = session?.connectedPeers) {
    guard let peers = peers where !peers.isEmpty else {
        return
    }

    var rootObject: [String: AnyObject] = ["event": event]

    if let object: AnyObject = object {
        rootObject["object"] = object
    }

    let data = NSKeyedArchiver.archivedDataWithRootObject(rootObject)

    do {
        try session?.sendData(data, toPeers: peers, withMode: .Reliable)
    } catch let errors as NSError{
        NSLog("Error sending data: \(errors.localizedDescription)")
    }
}

public func sendResourceAtURL(resourceURL: NSURL,
                   withName resourceName: String,
  toPeers peers: [MCPeerID]? = session?.connectedPeers,
  withCompletionHandler completionHandler: ((NSError?) -> Void)?) -> [NSProgress?]? {

    if let session = session {
        return peers?.map { peerID in
            return session.sendResourceAtURL(resourceURL, withName: resourceName, toPeer: peerID, withCompletionHandler: completionHandler)
        }
    }
    return nil
}
