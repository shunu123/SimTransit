import Foundation

class LLMVoiceParser {
    static let shared = LLMVoiceParser()
    private init() {}
    
    func parseIntent(transcript: String) async -> LLMIntentResponse? {
        do {
            let result = try await APIService.shared.parseVoiceIntent(transcript: transcript)
            print("🤖 Backend LLM Result: \(result.command)")
            return result
        } catch {
            print("❌ LLMVoiceParser Error: \(error)")
            return nil
        }
    }
}
