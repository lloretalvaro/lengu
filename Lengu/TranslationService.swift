//
//  TranslationService.swift
//  Lengu
//
//  Created by Alvaro Lloret Lopez on 12/6/22.
//

import Foundation


struct TranslationBody: Codable {
    let text: String
    let to: String
}

struct Translation: Codable{
    let translations: [TranslationBody]
}


func makeTranslationRequest(text: String) -> String {
    let sem = DispatchSemaphore.init(value: 0)
    
    let translation_body = [[
        "text": text
    ]]

    let jsonData = try? JSONSerialization.data(withJSONObject: translation_body)

    let url = URL(string: "https://api-eur.cognitive.microsofttranslator.com/translate?api-version=3.0&from=en&to=es")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("f090c0af71254f68bca17e00bb1f3be0", forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
    request.setValue("westeurope", forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
    request.setValue("944161d6-455c-4dc0-9c30-aba05cdf1c67", forHTTPHeaderField: "X-ClientTraceId")

    request.httpBody = jsonData
  
    var translationResult: String = ""
    
    //Make the request
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        
        defer { sem.signal() }
        
        guard let data = data, error == nil else {
            print(error?.localizedDescription ?? "No data")
            return
        }
        
        do {
            let responseJSON = try JSONDecoder().decode([Translation].self, from: data)
            print("INSIDE: \(responseJSON[0].translations[0].text)")
            translationResult = "\(responseJSON[0].translations[0].text)"
            
        }catch {
            print(error)
        }
    }

    task.resume()
    
    sem.wait()
    
    return translationResult
}

