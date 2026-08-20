import Foundation

/// 소켓 재연결 대기 시간 계산.
///
/// - Important: **상한(시도 횟수 제한)을 두지 않는다.** 웹 설정(`reconnectionAttempts: 5`)을
///   그대로 옮기면 지하철·엘리베이터처럼 잠깐 끊기는 상황에서 5번 실패한 뒤 영영 죽은 채로
///   남는다. 사용자는 방을 나갔다 다시 들어와야 복구된다. 데스크톱 브라우저와 달리 모바일은
///   와이파이↔셀룰러 전환이 일상이라 계속 시도해야 한다.
public enum SocketBackoff {

    /// 첫 대기 시간(초).
    public static let initialDelay: Double = 1

    /// 최대 대기 시간(초). 서버가 죽어 있을 때 재연결 요청이 몰리지 않게 막는다.
    public static let maxDelay: Double = 30

    /// 흔들림 폭. 웹 `randomizationFactor: 0.5` 와 같다.
    public static let jitterRange: ClosedRange<Double> = 0...0.5

    /// 1초에서 시작해 두 배씩, 최대 30초. 거기에 흔들림을 곱한다.
    ///
    /// - Parameters:
    ///   - attempt: 1부터 세는 재시도 횟수.
    ///   - jitter: 0...0.5. 테스트에서 고정할 수 있게 인자로 받는다.
    public static func delay(attempt: Int, jitter: Double) -> Double {
        let safeAttempt = max(attempt, 1)
        // 2^30 도 넘기지 않도록 지수를 먼저 자른다 (Double 오버플로 방지).
        let exponent = Double(min(safeAttempt - 1, 16))
        let base = min(initialDelay * pow(2, exponent), maxDelay)
        let clampedJitter = min(max(jitter, jitterRange.lowerBound), jitterRange.upperBound)
        return base * (1 + clampedJitter)
    }

    /// 실제 사용용 — 흔들림을 무작위로 뽑는다.
    public static func delay(attempt: Int) -> Double {
        delay(attempt: attempt, jitter: Double.random(in: jitterRange))
    }
}
