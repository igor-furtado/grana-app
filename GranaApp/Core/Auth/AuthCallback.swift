import Foundation

enum AuthCallback {
    static let scheme = "com.igorfurtado.GranaApp"
    static let host = "auth-callback"

    static let redirectURL = URL(string: "\(scheme)://\(host)")!
}
