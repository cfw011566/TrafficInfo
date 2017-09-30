//
//  APIController.swift
//  TrafficInfo
//
//  Created by formosa on 2015/10/10.
//  Copyright © 2015年 formosa. All rights reserved.
//

import Foundation
import UIKit
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


protocol APIControllerProtocol {
    func didReceiveAPIResults(_ results: NSArray)
    func cannotConnect(_ errorMessage: String)
}

class APIController {
    var delegate: APIControllerProtocol
    
    init(delegate: APIControllerProtocol) {
        self.delegate = delegate
    }
    
    func getTrafficInfo(urlIndex: Int) {
//        let urlPath1 = "http://210.69.35.216/data/api/pbs"
//        let urlPath0 = "http://od.moi.gov.tw/data/api/pbs"
//        let urlPath = "http://service.partime-match.com/pbs"
        var urlPath = ""
        if urlIndex == 0 {
            urlPath = "http://od.moi.gov.tw/data/api/pbs"
        } else {
            urlPath = "http://210.69.35.216/data/api/pbs"
        }
        let url = URL(string: urlPath)
        let session = URLSession.shared
        let task = session.dataTask(with: url!, completionHandler: { data, response, error -> Void in
            print("Task completed")
            if (error != nil) {
                // If there is an error in the web request, print it to the console
                let message = error!.localizedDescription
                self.delegate.cannotConnect(message)
            } else {
                if (data?.count > 0) {
                    do {
                        let jsonResult: NSDictionary = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as! NSDictionary
                        if let results: NSArray = jsonResult["result"] as? NSArray {
                            self.delegate.didReceiveAPIResults(results)
                        }
                    } catch {
                        print("JSON Error : \(error)")
                    }
                } else {
                    self.delegate.cannotConnect("系統無回傳資料")
                }
            }
        })
        
        // The task is just an object with all these properties set
        // In order to actually make the web request, we need to "resume"
        task.resume()
    }
}
