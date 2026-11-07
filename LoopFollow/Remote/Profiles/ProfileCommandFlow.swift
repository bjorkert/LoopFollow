// LoopFollow
// ProfileCommandFlow.swift

import SwiftUI

/// Device authentication and sending for profile commands. The result arrives through the tracker state.
enum ProfileCommandFlow {
    static func authenticateAndSend(
        _ command: ProfileCommand,
        to remote: ProfileRemote,
        reason: String,
        onFailure: @escaping (String) -> Void
    ) {
        AuthService.authenticate(reason: reason) { result in
            switch result {
            case .success:
                RemoteCommandTracker.shared.sendProfileCommand(command, to: remote) { success, error in
                    if !success {
                        LogManager.shared.log(category: .apns, message: "Profile command not sent: \(error ?? "unknown error")")
                    }
                }
            case let .unavailable(message):
                onFailure(message)
            case .failed:
                onFailure("Authentication failed")
            case .canceled:
                break
            }
        }
    }

    static func resultTitle(kind: ProfileCommandKind, success: Bool, message: String, remote: ProfileRemote) -> String {
        if message == remote.timeoutMessage { return "No Reply From \(remote.appName)" }
        switch (kind, success) {
        case (.activate, true): return "Profile Activated"
        case (.activate, false): return "Profile Not Activated"
        case (.save, true): return "Profile Saved"
        case (.save, false): return "Profile Not Saved"
        case (.delete, true): return "Profile Deleted"
        case (.delete, false): return "Profile Not Deleted"
        case (.saveScheduledSwitches, true): return "Scheduled Switches Saved"
        case (.saveScheduledSwitches, false): return "Scheduled Switches Not Saved"
        }
    }

    /// The tracker keys of all profile commands for this app.
    static func isAnyPending(_ tracker: RemoteCommandTracker, remote: ProfileRemote) -> Bool {
        tracker.isBusy(keyPrefixes: remote.keyPrefixes)
    }
}

/// Reports a finished profile command once, also when the view was left while it was pending.
struct ProfileCommandResultModifier: ViewModifier {
    let keys: [String]
    let onResult: (String, Bool, String) -> Void

    @ObservedObject private var tracker = RemoteCommandTracker.shared

    func body(content: Content) -> some View {
        content
            .onAppear { keys.forEach(check) }
            .onChange(of: keys.map { tracker.states[$0] }) { _, _ in keys.forEach(check) }
    }

    private func check(_ key: String) {
        guard case let .done(success, message) = tracker.states[key] else { return }
        tracker.consume(key: key)
        // A result that arrives at once comes while the confirmation alert is still closing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onResult(key, success, message)
        }
    }
}

extension View {
    func onProfileCommandResult(keys: [String], perform: @escaping (String, Bool, String) -> Void) -> some View {
        modifier(ProfileCommandResultModifier(keys: keys, onResult: perform))
    }
}

/// The note shown where profiles are introduced and before a change is sent.
struct ProfileCareTeamNote: View {
    var body: some View {
        Text("Profiles hold the settings used to dose insulin. Agree on profiles and any change to them with the care team. LoopFollow does not give medical advice.")
    }
}

/// The warning shown when a change applies to the profile that is in use.
struct ActiveProfileWarning: View {
    let remote: ProfileRemote

    var body: some View {
        Label {
            Text("This is the active profile. Saving changes insulin dosing right away: \(remote.appName) sends the new basal rates to the pump and starts using all new values as soon as it gets the command.")
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundColor(.red)
        .font(.callout.weight(.semibold))
    }
}
