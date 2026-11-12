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
    public static func emailLogin(_ email: String, password: String) throws -> HTTPRequest {
        try .json(.post, "/plan/auth/email/login", body: ["email": email, "password": password], requiresAuth: false)
    }
    /// 가입은 `email/verify` 가 준 `signupTicket` 이 있어야 서버가 받습니다(Android `PlanRepository.emailSignup`).
    /// 예전에는 로그인과 같은 본문(이메일·비밀번호)만 보내 서버가 늘 거절했고, 화면에는 "가입하지 못했어요" 만 떴습니다.
    public static func emailSignup(_ email: String, password: String, signupTicket: String) throws -> HTTPRequest {
        try .json(.post, "/plan/auth/email/signup", body: ["email": email, "password": password, "signupTicket": signupTicket], requiresAuth: false)
    }
    public static func emailReset(_ email: String, code: String, password: String) throws -> HTTPRequest {
        try .json(.post, "/plan/auth/email/password/reset", body: ["email": email, "code": code, "newPassword": password], requiresAuth: false)
    }
    public static func googleLogin(idToken: String) throws -> HTTPRequest {
        try .json(.post, "/plan/auth/google/login", body: ["idToken": idToken], requiresAuth: false)
    }
}
