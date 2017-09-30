//
//  ViewController.swift
//  TrafficInfo
//
//  Created by formosa on 2015/10/10.
//  Copyright (c) 2015年 formosa. All rights reserved.
//

import UIKit
import GoogleMaps
import iAd

enum ViewType: Int {
    case viewTable = 0
    case viewMap
}

enum RoadType: Int {
    case normal = 0
    case accident
    case alarm
    case control
    case barrier
    case semaphore
    case working
    case jam
    case other
}

enum PreferenceKey: String {
    case SelectedRegionIndex = "SelectedRegionIndex"
    case SelectedIntervalIndex = "SelectedIntervalIndex"
    case CurrentViewType = "CurrentViewType"
    case TrafficOn = "TrafficOn"
    case LongTermTrafficOn = "LongTermTrafficOn"
}

var urlIndex = 0

class TrafficViewController: UIViewController, UIPopoverPresentationControllerDelegate {

    @IBOutlet weak var mapView: GMSMapView!
    @IBOutlet weak var tableView: UITableView!
    
    let kCellIdentifier = "TrafficInfoCell"
    let kRefreshInterval = 30.0
    let locationManager = CLLocationManager()
    
    var api: APIController!
    var searchController: UISearchController!
    
    var trafficData = [TrafficInfo]()
    var selectedData = [TrafficInfo]()
    var filteredData = [TrafficInfo]()
    var markerInfo: TrafficInfo!
    var trafficMarkers = [GMSMarker]()
    
    var currentLocation: CLLocationCoordinate2D!
    var selectedRegion = "A"
    var selectedRegionIndex = 0
    var selectedIntervalIndex = 0
    var trafficOn = false
    var trafficLongTerm = false
    
    var viewType: ViewType = .viewMap
    var lastRefresh = Date(timeIntervalSinceNow: 0)
    
    let imageAccident = UIImage(named: "accident")
    let imageBarrier = UIImage(named: "barrier")
    let imageJam = UIImage(named: "jam")
    let imageControl = UIImage(named: "control")
    let imageSemaphore = UIImage(named: "semaphore")
    let imageWorking = UIImage(named: "working")
    let imageAlarm = UIImage(named: "alarm")
    let imageNormal = UIImage(named: "normal")
    let imageOther = UIImage(named: "other")
    
    var segmentRegion: UISegmentedControl!
    var segmentInterval: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let myAppDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
        myAppDelegate.myViewController = self

        addNavItemOnView()
        
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.searchBar.sizeToFit()
        //        appsTableView.tableHeaderView = searchController.searchBar

        self.canDisplayBannerAds = true
        
        locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        
        mapView.delegate = self
//        mapView.trafficEnabled = true
        
        tableView.delegate = self
        tableView.dataSource = self
        
        definesPresentationContext = true
        
        segmentRegion = UISegmentedControl(items: [" 全 ", " 北 ", " 中 ", " 南 ", " 東 "])
        segmentRegion.sizeToFit()
        segmentRegion.addTarget(self, action: #selector(segmentRegionChanged(_:)), for: .valueChanged)
        
        segmentInterval = UISegmentedControl(items: ["1小時", "2小時", "4小時", "8小時"])
        segmentInterval.sizeToFit()
//        segmentInterval.tintColor = UIColor(red:0.99, green:0.00, blue:0.25, alpha:1.00)
        segmentInterval.addTarget(self, action: #selector(segmentIntervalChanged(_:)), for: .valueChanged)

        api = APIController(delegate: self)
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        api.getTrafficInfo(urlIndex: urlIndex)
        
//        self.navigationController?.hidesBarsOnTap = true
        
    }

    override func viewWillAppear(_ animated: Bool) {
        let userDefaults = UserDefaults.standard
        
        let selectedRegionIndex = userDefaults.integer(forKey: PreferenceKey.SelectedRegionIndex.rawValue)
        segmentRegion.selectedSegmentIndex = selectedRegionIndex
        setRegionWithIndex(selectedRegionIndex)
        
        let selectedIntervalIndex = userDefaults.integer(forKey: PreferenceKey.SelectedIntervalIndex.rawValue)
        segmentInterval.selectedSegmentIndex = selectedIntervalIndex
        setIntervalWithIndex(selectedIntervalIndex)
        
        let trafficOn = userDefaults.bool(forKey: PreferenceKey.TrafficOn.rawValue)
        setTraffic(trafficOn)
 
        let trafficLongTerm = userDefaults.bool(forKey: PreferenceKey.LongTermTrafficOn.rawValue)
        self.trafficLongTerm = trafficLongTerm
        
        let currentViewType: Int = userDefaults.integer(forKey: PreferenceKey.CurrentViewType.rawValue)
        self.viewType = ViewType(rawValue: currentViewType)!
        showViews(self.viewType)
        addNavItemOnView()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: segue
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if self.viewType == .viewTable {
            self.navigationItem.title = "表格"
        } else {
            self.navigationItem.title = "地圖"
        }
        if segue.identifier == "DetailInfo" {
            if let detailViewController: DetailViewController = segue.destination as? DetailViewController {
                var info: TrafficInfo
                if self.viewType == .viewTable {
                    let infoIndex = tableView!.indexPathForSelectedRow!.row
                    if searchController.isActive {
                        info = self.filteredData[infoIndex]
                    } else {
                        info = self.selectedData[infoIndex]
                    }
                } else {
                    info = self.markerInfo
                }
                detailViewController.trafficInfo = info
                
                if self.navigationController!.isNavigationBarHidden {
                    self.navigationController?.setNavigationBarHidden(false, animated: false)
                }
            }
        }
    }
    
    func addTrafficMarker() {
        self.mapView.clear()
        self.trafficMarkers.removeAll()
        for info in self.trafficData {
            if info.isAnnotation {
                let position = CLLocationCoordinate2DMake(info.latitude, info.longitude)
                let marker = GMSMarker(position: position)
                marker?.userData = info.uid
                marker?.title = info.comment
                var myTime = info.modifyTime
                myTime.removeSubrange(myTime.characters.index(myTime.startIndex, offsetBy: 19)..<myTime.endIndex)
                marker?.snippet = myTime
                if info.daysAfterHappen > 1.0 {
                    marker?.opacity = 0.5
                }
//                marker.icon = UIImage(named: info.iconName)
                marker?.icon = imageFromRoadType(info.iconName)
                marker?.map = self.mapView
                self.trafficMarkers.append(marker!)
            }
        }
    }
    
    func onePixelImageWithColor(_ color : UIColor) -> UIImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        context?.setFillColor(color.cgColor)
        context?.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let image = UIImage(cgImage: (context?.makeImage()!)!)
        return image
    }

    func addNavItemOnView() {
        let infoButton: UIButton = UIButton(type: .detailDisclosure)
        infoButton.addTarget(self, action: #selector(TrafficViewController.displayInfo(_:)), for: .touchUpInside)
        let infoButtonItem: UIBarButtonItem = UIBarButtonItem(customView: infoButton)
        
        let settingButton: UIButton = UIButton(type: .custom)
        settingButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        let settingImage = UIImage(named: "setting")?.withRenderingMode(.alwaysTemplate)
        settingButton.setImage(settingImage, for: UIControlState())
        settingButton.addTarget(self, action: #selector(TrafficViewController.settingPopover(_:)), for: .touchUpInside)
        let settingButtonItem: UIBarButtonItem = UIBarButtonItem(customView: settingButton)
        
        /*
         let locationButton: UIButton = UIButton(type: .custom)
         locationButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
         let locationImage = UIImage(named: "location")?.withRenderingMode(.alwaysTemplate)
         locationButton.setImage(locationImage, for: UIControlState())
         locationButton.addTarget(self, action: #selector(TrafficViewController.setUserLocation(_:)), for: .touchUpInside)
         let locationButtonItem: UIBarButtonItem = UIBarButtonItem(customView: locationButton)
         */
        
        let searchButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(TrafficViewController.searchTraffic(_:)))
        
        let refreshButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(TrafficViewController.getTrafficData(_:)))
        
        let tableButton: UIButton = UIButton(type: .custom)
        tableButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        let tableImage = UIImage(named: "table")?.withRenderingMode(.alwaysTemplate)
        tableButton.setImage(tableImage, for: UIControlState())
        tableButton.addTarget(self, action: #selector(TrafficViewController.switchView(_:)), for: .touchUpInside)
        let tableButtonItem: UIBarButtonItem = UIBarButtonItem(customView: tableButton)
        
        let mapButton: UIButton = UIButton(type: .custom)
        mapButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        let mapImage = UIImage(named: "map")?.withRenderingMode(.alwaysTemplate)
        mapButton.setImage(mapImage, for: UIControlState())
        mapButton.addTarget(self, action: #selector(TrafficViewController.switchView(_:)), for: .touchUpInside)
        let mapButtonItem: UIBarButtonItem = UIBarButtonItem(customView: mapButton)
        
        if self.viewType == .viewMap {
            self.navigationItem.setRightBarButtonItems([infoButtonItem, settingButtonItem], animated: true)
            self.navigationItem.setLeftBarButtonItems([tableButtonItem, refreshButtonItem], animated: true)
            self.navigationItem.titleView = segmentInterval
        } else {
            self.navigationItem.setRightBarButtonItems([infoButtonItem, searchButtonItem], animated: true)
            self.navigationItem.setLeftBarButtonItems([mapButtonItem, refreshButtonItem], animated: true)
            self.navigationItem.titleView = segmentRegion
        }
    }
    
    func showViews(_ viewType: ViewType) {
        if viewType == .viewMap {
            self.tableView.isHidden = true
            self.mapView.isHidden = false
        } else {
            self.tableView.isHidden = false
            self.mapView.isHidden = true
            self.tableView.reloadData()
        }
        self.showTitleText()
        
        // Google Analytics
        var name: String
        if viewType == .viewTable {
            name = "TableView"
        } else {
            name = "MapView"
        }
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIDescription, value: name)
        let builder: NSObject = GAIDictionaryBuilder.createScreenView().build()
        tracker?.send(builder as! [NSObject : AnyObject])
    }
    
    // MARK: NavBarButton selector
    
    @objc func switchView(_ sender: UIButton) {
        if self.viewType == .viewMap {
            self.viewType = .viewTable
        } else {
            self.viewType = .viewMap
        }
        showViews(self.viewType)
        addNavItemOnView()
        let userDefaults = UserDefaults.standard
        userDefaults.set(self.viewType.rawValue, forKey: PreferenceKey.CurrentViewType.rawValue)
    }
    
    @objc func getTrafficData(_ sender: UIBarButtonItem) {
        getCurrentTrafficData()
        
        // Google Analytics
        let tracker = GAI.sharedInstance().defaultTracker
        let builder: NSObject = GAIDictionaryBuilder.createEvent(withCategory: "GetTrafficData", action: "click", label: nil, value: nil).build()
        tracker?.send(builder as! [NSObject : AnyObject])

    }
    
    @objc func searchTraffic(_ sender: UIBarButtonItem) {
        self.tableView.contentOffset = CGPoint.zero
        self.tableView.tableHeaderView = self.searchController.searchBar
        self.searchController.searchBar.becomeFirstResponder()
        //        self.searchController.active = true
        
        // Google Analytics
        let tracker = GAI.sharedInstance().defaultTracker
        let builder: NSObject = GAIDictionaryBuilder.createEvent(withCategory: "SearchTraffic", action: "click", label: nil, value: nil).build()
        tracker?.send(builder as! [NSObject : AnyObject])

    }

    func setUserLocation(_ sender: UIButton) {
        if (self.currentLocation != nil) {
            mapView.animate(toLocation: self.currentLocation)
            mapView.animate(toZoom: 14)
        } else {
            let myTitle = "無法定位"
            let myMessage = "請確認是否打開定位功能"
            let alert = UIAlertController(title: myTitle, message: myMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        
        // Google Analytics
        let tracker = GAI.sharedInstance().defaultTracker
        let builder: NSObject = GAIDictionaryBuilder.createEvent(withCategory: "SetUserLocation", action: "click", label: nil, value: nil).build()
        tracker?.send(builder as! [NSObject : AnyObject])

    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    @objc func settingPopover(_ sender: UIButton) {
        let settingVC: SettingViewController = self.storyboard?.instantiateViewController(withIdentifier: "SettingViewController") as! SettingViewController
        settingVC.modalPresentationStyle = .popover
        settingVC.preferredContentSize = CGSize(width: 300, height: 250)
        settingVC.viewType = self.viewType
        settingVC.selectedRegion = self.selectedRegionIndex
        settingVC.selectedInterval = self.selectedIntervalIndex
        settingVC.trafficOn = self.trafficOn
        settingVC.trafficLongTerm = self.trafficLongTerm
        settingVC.delegate = self
        let popoverController = settingVC.popoverPresentationController
        popoverController?.permittedArrowDirections = .any
        popoverController?.delegate = self
        popoverController?.sourceView = sender
        popoverController?.sourceRect = sender.bounds
        present(settingVC, animated: true, completion: nil)
    }
    
    @objc func displayInfo(_ sender: UIButton) {
        self.performSegue(withIdentifier: "AttributionInfo", sender: tableView)
    }
    
    @objc func segmentRegionChanged(_ sender: UISegmentedControl) {
        setRegionWithIndex(segmentRegion.selectedSegmentIndex)
    }
    
    @objc func segmentIntervalChanged(_ sender: UISegmentedControl) {
        setIntervalWithIndex(segmentInterval.selectedSegmentIndex)
    }
    
    // MARK: helper functions
    
    func getCurrentTrafficData() {
        let nowDateTime = Date(timeIntervalSinceNow: 0)
        let timeInterval: Double = nowDateTime.timeIntervalSince(lastRefresh)
        if timeInterval > kRefreshInterval {
            lastRefresh = nowDateTime
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            api.getTrafficInfo(urlIndex: urlIndex)
            if self.trafficData.count > 0 {
                self.tableView.contentOffset = CGPoint.zero
            }
        }
    }
    
    func selectRegion(_ region: String) -> [TrafficInfo] {
        var selected = [TrafficInfo]()
        for info in trafficData {
            if (!self.trafficLongTerm && info.daysAfterHappen > 1.0) {
                continue
            }
            if region == "A" || info.region == region {
                selected.append(info)
            }
        }
        return selected
    }
    
    func selectWithoutLocation() -> [TrafficInfo] {
        var selected = [TrafficInfo]()
        for info in trafficData {
            if (!self.trafficLongTerm && info.daysAfterHappen > 1.0) {
                continue
            }
            if !info.isAnnotation {
                selected.append(info)
            }
        }
        return selected
    }
    
    func filterMarkers(_ minutes: Double) {
        self.mapView.clear()
        self.trafficMarkers.removeAll()
        for info in self.trafficData {
            if (!self.trafficLongTerm && info.daysAfterHappen > 1.0) {
                continue
            }
            if info.isAnnotation && info.annotationInterval <= minutes {
                let position = CLLocationCoordinate2DMake(info.latitude, info.longitude)
                let marker = GMSMarker(position: position)
                marker?.userData = info.uid
                marker?.title = info.comment
                var myTime = info.modifyTime
                myTime.removeSubrange(myTime.characters.index(myTime.startIndex, offsetBy: 19)..<myTime.endIndex)
                marker?.snippet = myTime
                if info.daysAfterHappen > 1.0 {
                    marker?.opacity = 0.5
                }
//                marker.icon = UIImage(named: info.iconName)
                marker?.icon = imageFromRoadType(info.iconName)
                marker?.map = self.mapView
                self.trafficMarkers.append(marker!)
            }
        }
        print("\(trafficMarkers.count)")
    }
    
    func showTitleText() {
        var text: String
        if self.viewType == .viewMap {
            switch selectedIntervalIndex {
            case 0:
                text = "1小時"
            case 1:
                text = "2小時"
            case 2:
                text = "4小時"
            case 3:
                text = "8小時"
            default:
                text = ""
            }
        } else {
            switch selectedRegionIndex {
            case 0:
                text = "全區"
            case 1:
                text = "北區"
            case 2:
                text = "中區"
            case 3:
                text = "南區"
            case 4:
                text = "東區"
            default:
                text = "無"
            }
        }
        self.navigationItem.title = text
    }
    
    func imageFromRoadType(_ iconname: String) -> UIImage {
        switch iconname {
        case "accident" :
            return imageAccident!
        case "alarm" :
            return imageAlarm!
        case "barrier" :
            return imageBarrier!
        case "control" :
            return imageControl!
        case "jam" :
            return imageJam!
        case "normal" :
            return imageNormal!
        case "semaphore" :
            return imageSemaphore!
        case "working" :
            return imageWorking!
        default :
            return imageOther!
        }
    }

}

// MARK: CLLocationManagerDelegate
extension TrafficViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            self.locationManager.startUpdatingLocation()
            self.mapView.isMyLocationEnabled = true
            self.mapView.settings.myLocationButton = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first as CLLocation! {
            var zoom = self.mapView.camera.zoom
            if (zoom < 10.0 || zoom > 16.0) {
                zoom = 14.0
            }
            self.mapView.camera = GMSCameraPosition(target: location.coordinate, zoom: zoom, bearing: 0, viewingAngle: 0)
            self.locationManager.stopUpdatingLocation()
            self.currentLocation = locationManager.location?.coordinate
        }
    }
    
}

// MARK: GMSMapViewDelegate
extension TrafficViewController: GMSMapViewDelegate {
    
    func mapView(_ mapView: GMSMapView!, didTapAt coordinate: CLLocationCoordinate2D) {
//        print("You tapped at \(coordinate.latitude), \(coordinate.longitude) and zoom: \(self.mapView.camera.zoom)")
        self.navigationController?.setNavigationBarHidden(self.mapView.settings.myLocationButton, animated: true)
        self.mapView.settings.myLocationButton = !self.mapView.settings.myLocationButton
    }
    
    func mapView(_ mapView: GMSMapView!, didTapInfoWindowOf marker: GMSMarker!) {
        for info in self.trafficData {
            if info.uid == marker.userData as! String {
                self.markerInfo = info
                break
            }
        }
        self.performSegue(withIdentifier: "DetailInfo", sender: tableView)
    }
    
}

// MARK: APIControllerProtocol
extension TrafficViewController: APIControllerProtocol {
    
    func didReceiveAPIResults(_ results: NSArray) {
        let kMoiODURL = "http://data.moi.gov.tw/MoiOD/Data/DataDetail.aspx?oid=1E96B384-422B-4171-A02D-A26B783EF87F"
        DispatchQueue.main.async(execute: {
            self.trafficData = TrafficInfo.trafficInfoWithJSON(results as! [[String : Any]])
            if (self.trafficData.count == 0) {
                let alert = UIAlertController(title: "資料錯誤", message: "資料過舊或網站無回傳資料\n請聯絡內政部開放資料平臺網站\n\(kMoiODURL)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            } else {
//                self.addTrafficMarker()
                self.setIntervalWithIndex(self.selectedIntervalIndex)
                self.selectedData = self.selectRegion(self.selectedRegion)
                self.tableView.reloadData()
            }
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        })
    }
    
    func cannotConnect(_ errorMessage: String) {
        let myTitle = "無法取得資料"
        let myMessage = "請確認網路連線狀態或\n重新整理一次(切換到備援服務器)"
        let alert = UIAlertController(title: myTitle, message: myMessage + "\n" + errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        if urlIndex == 0 {
            urlIndex = 1
        } else {
            urlIndex = 0
        }
        lastRefresh = Date(timeIntervalSinceNow: 0)
    }

}

// MARK: UITableViewDelegate
extension TrafficViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "DetailInfo", sender: tableView)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchController.isActive {
            return self.filteredData.count
        } else {
            return self.selectedData.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = self.tableView.dequeueReusableCell(withIdentifier: kCellIdentifier) as UITableViewCell!
        
        var info: TrafficInfo
        if searchController.isActive {
            info = self.filteredData[indexPath.row]
        } else {
            info = self.selectedData[indexPath.row]
        }
        
        let modTime = info.modifyTime
        var myTitle = modTime.substring(with: modTime.characters.index(modTime.startIndex, offsetBy: 11)..<modTime.characters.index(modTime.startIndex, offsetBy: 16))
        if info.areaName != "" {
            myTitle += "  " + info.areaName
            if info.direction != "" {
                myTitle += "[" + info.direction + "]"
            }
        } else if info.road != "" {
            myTitle += "  " + info.road
        }
        cell.textLabel!.text = myTitle
        cell.detailTextLabel!.text = info.comment
        cell.imageView!.image = UIImage(named: info.iconName)
        if (info.daysAfterHappen > 1.0) {
            cell.imageView?.alpha = 0.5
        } else {
            cell.imageView?.alpha = 1.0
        }
        cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
        
        return cell
    }
}

// MARK: SettingViewControllerProtocol
extension TrafficViewController: SettingViewControllerProtocol {
    
    func setRegionWithIndex(_ regionIndex: Int) {
        let userDefaults = UserDefaults.standard
        userDefaults.set(regionIndex, forKey: PreferenceKey.SelectedRegionIndex.rawValue)
        self.selectedRegionIndex = regionIndex
        
        switch regionIndex {
        case 0:
            selectedRegion = "A"
        case 1:
            selectedRegion = "N"
        case 2:
            selectedRegion = "M"
        case 3:
            selectedRegion = "S"
        case 4:
            selectedRegion = "E"
        default:
            selectedRegion = "Z"
        }
        if selectedRegion == "Z" {
            selectedData = selectWithoutLocation()
        } else {
            selectedData = selectRegion(self.selectedRegion)
        }
        self.showTitleText()
        self.tableView.reloadData()
        if selectedData.count > 0 {
            self.tableView.contentOffset = CGPoint.zero
        }
        
        // Google Analytics
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIDescription, value: "SettingView")
        let builder: NSObject = GAIDictionaryBuilder.createEvent(withCategory: "Setting", action: "change", label: "Region", value: regionIndex as NSNumber!).build()
        tracker?.send(builder as! [NSObject : AnyObject])
    }
    
    func setIntervalWithIndex(_ intervalIndex: Int) {
        let userDefaults = UserDefaults.standard
        userDefaults.set(intervalIndex, forKey: PreferenceKey.SelectedIntervalIndex.rawValue)
        self.selectedIntervalIndex = intervalIndex
        
        var minutes: Double
        switch intervalIndex {
        case 0:
            minutes = 3600.0
        case 1:
            minutes = 7200.0
        case 2:
            minutes = 14400.0
        default:
            minutes = Double.infinity
        }
        filterMarkers(minutes)
        self.showTitleText()
        
        // Google Analytics
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIDescription, value: "SettingView")
        let builder: NSObject = GAIDictionaryBuilder.createEvent(withCategory: "Setting", action: "change", label: "Interval", value: intervalIndex as NSNumber!).build()
        tracker?.send(builder as! [NSObject : AnyObject])
    }
    
    func setTraffic(_ traffic: Bool) {
        let userDefaults = UserDefaults.standard
        userDefaults.set(traffic, forKey: PreferenceKey.TrafficOn.rawValue)
        self.trafficOn = traffic
        self.mapView.isTrafficEnabled = self.trafficOn
        
        // Google Analytics
        var myValue: NSNumber = 0
        if traffic {
            myValue = 1
        }
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIDescription, value: "SettingView")
        let builder: NSObject = GAIDictionaryBuilder.createEvent(withCategory: "Setting", action: "change", label: "Traffic", value: myValue).build()
        tracker?.send(builder as! [NSObject : AnyObject])
    }
    
    func setLongTermTraffic(_ longTerm: Bool) {
        let userDefaults = UserDefaults.standard
        userDefaults.set(longTerm, forKey: PreferenceKey.LongTermTrafficOn.rawValue)
        self.trafficLongTerm = longTerm
        
        self.setIntervalWithIndex(self.selectedIntervalIndex)
        self.selectedData = self.selectRegion(self.selectedRegion)
        self.tableView.reloadData()
        
        // Google Analytics
        var myValue: NSNumber = 0
        if longTerm {
            myValue = 1
        }
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIDescription, value: "SettingView")
        let builder: NSObject = GAIDictionaryBuilder.createEvent(withCategory: "Setting", action: "change", label: "LongTermTraffic", value: myValue).build()
        tracker?.send(builder as! [NSObject : AnyObject])
    }
    
}

//MARK: UISearchBarDelegate
extension TrafficViewController: UISearchResultsUpdating, UISearchBarDelegate {
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchController.isActive = false
        self.tableView.tableHeaderView?.removeFromSuperview()
        self.tableView.tableHeaderView = nil
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text
        filterForSearchText(searchText!)
        self.tableView.reloadData()
    }
    
    func filterForSearchText(_ searchText: String) {
        self.filteredData = [TrafficInfo]()
        var stringMatch: Bool = true
        self.filteredData = self.selectedData.filter({ (info: TrafficInfo) -> Bool in
            if searchText != "" {
                if (info.areaName != "") {
                    stringMatch = (info.areaName.range(of: searchText) != nil)
                } else {
                    stringMatch = (info.comment.range(of: searchText) != nil)
                }
            } else {
                stringMatch = true
            }
            return stringMatch
        })
    }

}
