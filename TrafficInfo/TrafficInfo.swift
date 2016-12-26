//
//  TrafficInfo.swift
//  TrafficInfo
//
//  Created by formosa on 2015/10/10.
//  Copyright © 2015年 formosa. All rights reserved.
//

import UIKit

struct TrafficInfo {
    let uid: String         // UID
    let region: String      // region
    let source: String      // srcdetail
    let areaName: String    // areaNm
    let direction: String   // direction
    let roadType: String    // roadtype
    let road: String        // road
    let comment: String     // comment
    let longitude: Double   // x1
    let latitude: Double    // y1
    let happenDate: String  // happendate
    let happenTime: String  // happentime
    let modifyTime: String     // modDttm
    let iconName: String
    let roadTypeColor: UIColor
    let roadTypeRaw: RoadType
    let isAnnotation: Bool
    let annotationInterval: Double
    let daysAfterHappen: Double

    init(uid: String, region: String, source: String, areaName: String, direction: String, roadType:String, road: String, comment: String, longitude: String, latitude: String, happenDate: String, happenTime: String, modifyTime: String, interval: Double) {
        self.uid = uid
        self.region = region
        self.source = source
        self.areaName = areaName
        self.direction = direction
        self.roadType = roadType
        self.road = road
        self.comment = comment
        if longitude == "0.0" {
            self.longitude = 0.0
            self.latitude = 0.0
            self.isAnnotation = false
        } else {
            let mylongitude:Double = (longitude as NSString).doubleValue
            let mylatitude:Double = (latitude as NSString).doubleValue
            self.longitude = mylongitude
            self.latitude = mylatitude
            self.isAnnotation = true
        }
        self.happenDate = happenDate
        self.happenTime = happenTime
        self.modifyTime = modifyTime
        switch roadType {
        case "事故":
            self.iconName = "accident"
            self.roadTypeColor = UIColor.red
            self.roadTypeRaw = .accident
        case "交通障礙":
            self.iconName = "barrier"
            self.roadTypeColor = UIColor.brown
            self.roadTypeRaw = .barrier
        case "阻塞":
            self.iconName = "jam"
            self.roadTypeColor = UIColor.magenta
            self.roadTypeRaw = .jam
        case "交通管制":
            self.iconName = "control"
            self.roadTypeColor = UIColor.orange
            self.roadTypeRaw = .control
        case "號誌故障":
            self.iconName = "semaphore"
            self.roadTypeColor = UIColor.blue
            self.roadTypeRaw = .semaphore
        case "道路施工":
            self.iconName = "working"
            self.roadTypeColor = UIColor.purple
            self.roadTypeRaw = .working
        case "災變":
            self.iconName = "alarm"
            self.roadTypeColor = UIColor.yellow
            self.roadTypeRaw = .alarm
        case "正常":
            self.iconName = "normal"
            self.roadTypeColor = UIColor.green
            self.roadTypeRaw = .normal
        default:
            self.iconName = "other"
            self.roadTypeColor = UIColor.cyan
            self.roadTypeRaw = .other
        }
        self.annotationInterval = interval
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SS"
        let modifyDateTime = dateFormatter.date(from: modifyTime)
        let happenDateTime = dateFormatter.date(from: happenDate + " " + happenTime)
        let secondsInterval: Double = modifyDateTime!.timeIntervalSince(happenDateTime!)
        self.daysAfterHappen = secondsInterval / 86400.0
    }
    
    static func trafficInfoWithJSON(_ results: [[String: Any]]) -> [TrafficInfo] {
        var allInfo = [TrafficInfo]()
        if results.count > 0 {
            let nowDateTime = Date(timeIntervalSinceNow: 0)
            let kSecondsFiltering = 28800.0 // 6hours = 21600, 4hours = 14400
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SS"
            for result in results {
                let uid = result["UID"] as? String ?? ""
                let region = result["region"] as? String ?? ""
                let source = result["srcdetail"] as? String ?? ""
                let areaName = result["areaNm"] as? String ?? ""
                let direction = result["direction"] as? String ?? ""
                let roadType = result["roadtype"] as? String ?? ""
                let road = result["road"] as? String ?? ""
                let comment = result["comment"] as? String ?? ""
                var longitude = result["x1"] as? String ?? ""
                if longitude == "" {
                    longitude = "0.0"
                }
                var latitude = result["y1"] as? String ?? ""
                if latitude == "" {
                    latitude = "0.0"
                }
                var happenDate = result["happendate"] as? String ?? ""
                if happenDate == "" {
                    happenDate = "2010-01-01"
                }
                var happenTime = result["happentime"] as? String ?? ""
                if happenTime == "" {
                    happenTime = "00:00:00.00"
                }
                var modifyTime = result["modDttm"] as? String ?? ""
                if modifyTime == "" {
                    modifyTime = "2010-01-01 00:00:00.00"
                }
                let modifyDateTime = dateFormatter.date(from: modifyTime)
                let timeInterval: Double = nowDateTime.timeIntervalSince(modifyDateTime!)
                if timeInterval <= kSecondsFiltering {
                    let newInfo = TrafficInfo(uid: uid, region: region, source: source, areaName: areaName, direction: direction, roadType: roadType, road: road, comment: comment, longitude: longitude, latitude: latitude, happenDate: happenDate, happenTime: happenTime, modifyTime: modifyTime, interval: timeInterval)
                    allInfo.append(newInfo)
                }
            }
        }
        print(allInfo.count)
        return allInfo
    }
}
