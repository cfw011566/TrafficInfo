//
//  AttributionViewController.swift
//  TrafficInfo
//
//  Created by formosa on 2015/10/16.
//  Copyright © 2015年 formosa. All rights reserved.
//

import UIKit
import GoogleMaps

class AttributionViewController: UIViewController {

    @IBOutlet weak var googleTextView: UITextView!
    @IBOutlet weak var taiwanTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let build = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
//        self.navigationItem.title = "顯名聲明"
        self.navigationItem.title = "版本 \(version) (\(build))"
        googleTextView.text = GMSServices.openSourceLicenseInfo()
//        googleTextView.text = GMSServices.SDKVersion()
        
        // Google Analytics
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIDescription, value: "AttributionView")
        let builder: NSObject = GAIDictionaryBuilder.createScreenView().build()
        tracker?.send(builder as! [NSObject : AnyObject])

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        googleTextView.contentOffset = CGPoint.zero
        taiwanTextView.contentOffset = CGPoint.zero
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
