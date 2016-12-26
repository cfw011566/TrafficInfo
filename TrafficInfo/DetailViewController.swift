//
//  DetailViewController.swift
//  TrafficInfo
//
//  Created by formosa on 2015/10/16.
//  Copyright © 2015年 formosa. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {

    @IBOutlet weak var modifyTimeLabel: UILabel!
    @IBOutlet weak var happenTimeLabel: UILabel!
    @IBOutlet weak var sourceLabel: UILabel!
    @IBOutlet weak var commentText: UITextView!
    
    var trafficInfo: TrafficInfo!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        var myTitle = ""
        if self.trafficInfo!.areaName != "" {
            myTitle += self.trafficInfo!.areaName
            if self.trafficInfo!.direction != "" {
                myTitle += " [" + self.trafficInfo!.direction + "]"
            }
        } else if self.trafficInfo!.road != "" {
            myTitle += self.trafficInfo!.road
        }
        navigationItem.title = myTitle
        addRightNavItemButton(self.trafficInfo!.iconName)
        
        commentText.text = self.trafficInfo!.comment
        commentText.scrollRangeToVisible(NSRange(location: 0, length: 0))
        
        if self.trafficInfo!.source.isEmpty {
            sourceLabel.text = "消息來源 : 無"
        } else {
            sourceLabel.text = "消息來源 : " + self.trafficInfo!.source
        }
        
        var myTime = self.trafficInfo!.modifyTime
        myTime.removeSubrange(myTime.characters.index(myTime.startIndex, offsetBy: 19)..<myTime.endIndex)
        modifyTimeLabel.text = "更新時間 : " + myTime
        myTime = self.trafficInfo!.happenTime
        myTime.removeSubrange(myTime.characters.index(myTime.startIndex, offsetBy: 8)..<myTime.endIndex)
        myTime = "發生時間 : " + self.trafficInfo!.happenDate + " " + myTime
        happenTimeLabel.text = myTime
        
        // Google Analytics
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIDescription, value: trafficInfo.uid)
        let builder: NSObject = GAIDictionaryBuilder.createScreenView().build()
        tracker?.send(builder as! [NSObject : AnyObject])
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    func addRightNavItemButton(_ iconName: String) {
        let iconRoadType: UIButton = UIButton(type: UIButtonType.custom)
        iconRoadType.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        let myImage = UIImage(named: iconName)?.withRenderingMode(.alwaysTemplate)
        iconRoadType.setImage(myImage, for: UIControlState())
        iconRoadType.isUserInteractionEnabled = false
        let rightBarButtonRoadType: UIBarButtonItem = UIBarButtonItem(customView: iconRoadType)
        self.navigationItem.setRightBarButton(rightBarButtonRoadType, animated: false)
    }
    
}
