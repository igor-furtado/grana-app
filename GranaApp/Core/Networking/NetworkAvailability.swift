import Auth
import Foundation
import PostgREST

enum NetworkAvailability {
    static func isUnavailable(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }
}

enum RemoteSessionFailure {
    static func requiresLogin(_ error: any Error) -> Bool {
        if let authError = error as? AuthError, authError == .sessionMissing {
            return true
        }
        if let postgrestError = error as? PostgrestError, postgrestError.code == "42501" {
            return true
        }
        return false
    }
}
