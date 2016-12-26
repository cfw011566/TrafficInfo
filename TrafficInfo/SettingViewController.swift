//
//  SettingViewController.swift
//  TrafficInfo
//
//  Created by formosa on 2015/10/17.
//  Copyright © 2015年 formosa. All rights reserved.
//

import UIKit

protocol SettingViewControllerProtocol {
    func setRegionWithIndex(_ regionIndex: Int)
    func setIntervalWithIndex(_ intervalIndex: Int)
    func setTraffic(_ traffic: Bool)
    func setLongTermTraffic(_ longTerm: Bool)
}

class SettingViewController: UIViewController {

    @IBOutlet weak var regionSegment: UISegmentedControl!
    @IBOutlet weak var intervalSegment: UISegmentedControl!
    @IBOutlet weak var switchTraffic: UISwitch!
    @IBOutlet weak var switchLongTermTraffic: UISwitch!
    
    var delegate: SettingViewControllerProtocol?
    var viewType: ViewType?
    var selectedRegion: Int?
    var selectedInterval: Int?
    var trafficOn: Bool?
    var trafficLongTerm: Bool?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.regionSegment.selectedSegmentIndex = self.selectedRegion!
        self.intervalSegment.selectedSegmentIndex = self.selectedInterval!
        self.switchTraffic.isOn = self.trafficOn!
        self.switchLongTermTraffic.isOn = self.trafficLongTerm!
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.regionSegment.isEnabled = (self.viewType == .viewTable)
        self.intervalSegment.isEnabled = (self.viewType == .viewMap)
        self.switchTraffic.isEnabled = (self.viewType == .viewMap)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    @IBAction func changeTraffic(_ sender: AnyObject) {
        self.trafficOn = self.switchTraffic.isOn
        delegate?.setTraffic(self.trafficOn!)
    }
    
    @IBAction func changeInterval(_ sender: AnyObject) {
        self.selectedInterval = self.intervalSegment.selectedSegmentIndex
        if (self.delegate != nil) {
            delegate!.setIntervalWithIndex(selectedInterval!)
        }
    }

    @IBAction func changeRegion(_ sender: AnyObject) {
        self.selectedRegion = self.regionSegment.selectedSegmentIndex
        if (self.delegate != nil) {
            delegate!.setRegionWithIndex(selectedRegion!)
        }
    }
    
    @IBAction func changeLongTermTraffic(_ sender: UISwitch) {
        self.trafficLongTerm = self.switchLongTermTraffic.isOn
        if (self.delegate != nil) {
            delegate!.setLongTermTraffic(trafficLongTerm!)
        }
    }
}
