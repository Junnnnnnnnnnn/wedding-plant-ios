import Foundation

extension Endpoint {
    public static func emailCheck(_ email: String) throws -> HTTPRequest {
        try .json(.post, "/plan/auth/email/check", body: ["email": email], requiresAuth: false)
    }
    public static func emailCode(_ email: String) throws -> HTTPRequest {
        try .json(.post, "/plan/auth/email/code", body: ["email": email], requiresAuth: false)
    }
    public static func emailVerify(_ email: String, code: String) throws -> HTTPRequest {
        try .json(.post, "/plan/auth/email/verify", body: ["email": email, "code": code], requiresAuth: false)
    }
    public static func emailLogin(_ email: String, password: String, signup: Bool = false) throws -> HTTPRequest {
        try .json(.post, "/plan/auth/email/\(signup ? "signup" : "login")", body: ["email": email, "password": password], requiresAuth: false)
    }
    public static func emailReset(_ email: String, code: String, password: String) throws -> HTTPRequest {
        try .json(.post, "/plan/auth/email/password/reset", body: ["email": email, "code": code, "newPassword": password], requiresAuth: false)
    }
    public static func googleLogin(idToken: String) throws -> HTTPRequest {
        try .json(.post, "/plan/auth/google/login", body: ["idToken": idToken], requiresAuth: false)
    }
}
