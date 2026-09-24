//
//  DexterOllamaMinimalVisionDiagnostic.swift
//  leanring-buddy
//

import Foundation

enum DexterOllamaMinimalVisionDiagnostic {
    struct Result: Equatable {
        let modelName: String
        let imageBytes: Int
        let base64Length: Int
        let httpStatus: Int?
        let elapsedSeconds: TimeInterval
        let assistantText: String?
        let errorBody: String?
    }

    static func run(
        jpegData: Data,
        modelName: String = OllamaModelConfiguration.visionModelName,
        endpointBaseURL: URL = URL(string: OllamaProvider.defaultEndpointString)!
    ) async -> Result {
        let startDate = Date()
        let base64Image = jpegData.base64EncodedString()

        let minimalPayload: [String: Any] = [
            "model": modelName,
            "stream": false,
            "think": false,
            "messages": [
                [
                    "role": "user",
                    "content": "What is visible in this image? Answer in two short sentences.",
                    "images": [base64Image]
                ]
            ]
        ]

        guard let requestBody = try? JSONSerialization.data(withJSONObject: minimalPayload) else {
            return Result(
                modelName: modelName,
                imageBytes: jpegData.count,
                base64Length: base64Image.count,
                httpStatus: nil,
                elapsedSeconds: Date().timeIntervalSince(startDate),
                assistantText: nil,
                errorBody: "Failed to encode JSON request body"
            )
        }

        var urlRequest = URLRequest(url: endpointBaseURL.appendingPathComponent("api/chat"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120
        urlRequest.httpBody = requestBody

        print("[SCREEN-VISION] request started")
        print("[SCREEN-VISION] image bytes=\(jpegData.count)")
        print("[OLLAMA-VISION] model=\(modelName)")
        print("[OLLAMA-VISION] imageBytes=\(jpegData.count)")
        print("[OLLAMA-VISION] base64Length=\(base64Image.count)")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            let elapsed = Date().timeIntervalSince(startDate)
            let httpStatus = (response as? HTTPURLResponse)?.statusCode
            let responseBody = String(data: data, encoding: .utf8) ?? ""

            print("[SCREEN-VISION] Ollama HTTP status=\(httpStatus ?? -1)")
            print("[OLLAMA-VISION] status=\(httpStatus ?? -1)")
            print("[OLLAMA-VISION] elapsed=\(String(format: "%.2f", elapsed))s")

            guard let httpStatus, (200...299).contains(httpStatus) else {
                print("[SCREEN-VISION] error body=\(responseBody)")
                print("[OLLAMA-VISION] errorBody=\(responseBody)")
                return Result(
                    modelName: modelName,
                    imageBytes: jpegData.count,
                    base64Length: base64Image.count,
                    httpStatus: httpStatus,
                    elapsedSeconds: elapsed,
                    assistantText: nil,
                    errorBody: responseBody
                )
            }

            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = jsonObject["message"] as? [String: Any],
               let content = message["content"] as? String {
                print("[SCREEN-VISION] response received")
                print("[OLLAMA-VISION] responseText=\(content.prefix(120))…")
                return Result(
                    modelName: modelName,
                    imageBytes: jpegData.count,
                    base64Length: base64Image.count,
                    httpStatus: httpStatus,
                    elapsedSeconds: elapsed,
                    assistantText: content,
                    errorBody: nil
                )
            }

            print("[OLLAMA-VISION] errorBody=\(responseBody)")
            return Result(
                modelName: modelName,
                imageBytes: jpegData.count,
                base64Length: base64Image.count,
                httpStatus: httpStatus,
                elapsedSeconds: elapsed,
                assistantText: nil,
                errorBody: "Unexpected response shape: \(responseBody.prefix(280))"
            )
        } catch {
            let elapsed = Date().timeIntervalSince(startDate)
            print("[OLLAMA-VISION] errorBody=\(error.localizedDescription)")
            return Result(
                modelName: modelName,
                imageBytes: jpegData.count,
                base64Length: base64Image.count,
                httpStatus: nil,
                elapsedSeconds: elapsed,
                assistantText: nil,
                errorBody: error.localizedDescription
            )
        }
    }
}
