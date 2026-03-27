//
//  PeerConnectionManager.swift
//  Pulse
//
//  Manages peer connections and state tracking
//

import Foundation
import MultipeerConnectivity
import Combine

@MainActor
class PeerConnectionManager: NSObject, ObservableObject, MCSessionDelegate {
    @Published var nearbyPeers: [PulsePeer] = []
    @Published var connectedPeerIds: Set<String> = []

    private(set) var myPeerID: MCPeerID
    private(set) var session: MCSession

    init(myPeerID: MCPeerID) {
        self.myPeerID = myPeerID
        self.session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        super.init()
    }

    func startTracking() {
        session.delegate = self
    }

    func addOrUpdatePeer(_ peer: PulsePeer) {
        if let index = nearbyPeers.firstIndex(where: { $0.id == peer.id }) {
            var existingPeer = nearbyPeers[index]
            existingPeer.status = peer.status
            existingPeer.distance = peer.distance
            existingPeer.publicKey = peer.publicKey
            nearbyPeers[index] = existingPeer
        } else {
            nearbyPeers.append(peer)
        }
    }

    func removePeer(_ peerId: String) {
        nearbyPeers.removeAll { $0.id == peerId }
    }

    func isConnected(_ peerId: String) -> Bool {
        return connectedPeerIds.contains(peerId)
    }

    var connectedPeerCount: Int {
        return connectedPeerIds.count
    }

    func getConnectedPeer(withId peerId: String) -> MCPeerID? {
        return session.connectedPeers.first(where: { $0.displayName == peerId })
    }

    nonisolated func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        let displayName = peerID.displayName
        Task { @MainActor in
            switch state {
            case .connected:
                self.connectedPeerIds.insert(displayName)
            case .notConnected:
                self.connectedPeerIds.remove(displayName)
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?
    ) {}
}
