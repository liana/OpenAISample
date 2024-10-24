//
//  ContentView.swift
//  OpenAISample
//
//  Created by Liana Leahy on 10/24/24.
//

import SwiftUI

struct ContentView: View {
    @State var prompt = ""
    @State var answer = ""
    
    let openAIConnector = OpenAIConnector()
    
    var body: some View {
        VStack {
            if !answer.isEmpty {
                Text(answer)
            }
            ZStack {
                TextEditor(text: $prompt)
                    .font(.body)
                    .cornerRadius(10)
                    .frame(height: 200)
                if prompt.isEmpty {
                    Text("Type a question here...").foregroundColor(.gray)
                }
            }
            Button(action: {
                answer = openAIConnector.processPrompt(prompt: prompt)!
            }) {
                Text("Submit")
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


public class OpenAIConnector {
    let openAIURL = URL(string: "https://api.openai.com/v1/chat/completions")
    var openAIKey: String {
        return "SECRET"
    }
    
    private let responseHandler = OpenAIResponseHandler()
    
    private func executeRequest(request: URLRequest, withSessionConfig sessionConfig: URLSessionConfiguration?) -> Data? {
        let semaphore = DispatchSemaphore(value: 0)
        let session: URLSession
        if (sessionConfig != nil) {
            session = URLSession(configuration: sessionConfig!)
        } else {
            session = URLSession.shared
        }
        var requestData: Data?
        let task = session.dataTask(with: request as URLRequest, completionHandler:{ (data: Data?, response: URLResponse?, error: Error?)
            -> Void in
            if error != nil {
                print("error: \(error!.localizedDescription): \(error!.localizedDescription)")
            } else if data != nil {
                requestData = data
            }
            
            print ("Semaphore signalled")
            semaphore.signal()
        })
        task.resume()
        
        //Handle async with semaphores. Max wait of 10 seconds
        let timeout = DispatchTime.now() + .seconds(20)
        print("waiting for sepahore signal")
        let retVal = semaphore.wait(timeout: timeout)
        print ("Done waiting, obtained - \(retVal)")
        return requestData
    }
    
    public func processPrompt(
        prompt: String
    ) -> Optional<String> {
        
        var request = URLRequest(url: self.openAIURL!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(self.openAIKey)", forHTTPHeaderField: "Authorization")
        
        let httpBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages":
                [
                    [
                        "role": "user",
                        "content": prompt
                    ]
                ]
        ]
        
        var httpBodyJson: Data
        
        do {
            httpBodyJson = try JSONSerialization.data(withJSONObject: httpBody, options: .prettyPrinted)
        } catch
        {
            print("Unable to convert to JSON: \(error)")
            return nil
        }
        request.httpBody = httpBodyJson
        
        if let requestData = executeRequest(request: request, withSessionConfig: nil),
           let jsonStr = String(data: requestData, encoding: .utf8),
           let response = self.responseHandler.decodeJson(jsonString: jsonStr),
           let choices = response.choices,!choices.isEmpty {
            return choices[0].message.content
        } else {
            print("Error processing response")
            return nil
        }
    }
    
    struct OpenAIResponseHandler {
        func decodeJson(jsonString: String) -> OpenAIResponse? {
            let json = jsonString.data(using: .utf8)!
            
            let decoder = JSONDecoder()
            do {
                let product = try decoder.decode(OpenAIResponse.self, from: json)
                return product
            } catch {
                print("Error decoding OpenAI API Response:\(error)")
                return nil
            }
        }
    }
}
struct OpenAIResponse: Codable{
    var id: String
    var object: String
    var created: Int
    var model: String
    var choices: [Choice]?
}
struct Choice: Codable{
    var message: Message
    var index: Int
    var logprobs: String?
    var finish_reason: String
}
struct Message: Codable {
    var role: String
    var content: String
    var refusal: String?
}

public extension Binding where Value: Equatable {
    init(_ source: Binding<Value?>, replacingNilWith nilProxy: Value) {
        self.init(
            get: { source.wrappedValue ?? nilProxy },
            set: { newValue in
                if newValue == nilProxy {
                    source.wrappedValue = nilProxy
                }
                else {
                    source.wrappedValue = newValue
                }
        })
    }
}
