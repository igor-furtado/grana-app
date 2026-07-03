import Foundation

enum AuthCallback {
    static let scheme = "com.igorfurtado.GranaAi"
    static let host = "auth-callback"

    static let redirectURL = URL(string: "\(scheme)://\(host)")!
}
