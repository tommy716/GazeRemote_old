//
//  ViewController.swift
//  GazeRemote
//
//  Created by Tommy on 2021/05/27.
//

import UIKit
import Alamofire

class RemoteControlViewController: UIViewController {
    let baseUrl = "https://api.nature.global/1/"
    var token: String = ""
    let buttonIds: [String:String] = [
        "power": "d9558865-591e-43b1-bf88-72a908f8cb98",
        "input": "2c2bf0ff-f5dc-476e-85c7-0e72f9699f2c",
        "top": "db3ff1f5-b2c9-4798-bfe2-2f5d5494131a",
        "bottom": "f9f8ba0d-215d-4686-86e8-af2a126317cc",
        "left": "0987fc8b-7182-4bb6-aa69-4415cadbe4b5",
        "right": "b26e0096-95a2-453a-bcb6-a21d1121c1e5",
        "enter": "6b45a920-711d-4f3a-8735-d103a473d953",
        "back": "4a85da2f-95af-4404-8238-e160a0ba3da0",
        "mute": "2889f781-bb93-49e2-9291-ac3758af3082",
        "minus": "f41ca104-00da-4151-9edd-bd18e29e887a",
        "plus": "3dd34695-e0bd-4069-98cf-c33b0fc27ee3",
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        var property: Dictionary<String, Any> = [:]
        let path = Bundle.main.path(forResource: "token", ofType: "plist")
        let configurations = NSDictionary(contentsOfFile: path!)
        if let _: [String : Any]  = configurations as? [String : Any] {
            property = configurations as! Dictionary<String, Any>
        }
        token = property["token"] as! String
    }
    
    @IBAction func powerButton() {
        guard let targetButton = buttonIds["power"] else { return }
        let requestUrl  = baseUrl + "signals/" + targetButton + "/send"
        let Auth_header: HTTPHeaders = [
            "Authorization" : "Bearer " + token
        ]
        AF.request(requestUrl, method: .post, parameters: nil, headers: Auth_header).responseJSON{ response in
            if let error = response.error {
                print("Error: \(error)")
            } else {
                print("Success")
            }
        }
    }
}
