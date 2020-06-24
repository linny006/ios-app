//
//  MapScrollView.swift
//  IVPNClient
//
//  Created by Juraj Hilje on 20/02/2020.
//  Copyright © 2020 IVPN. All rights reserved.
//

import UIKit
import Bamboo
import SnapKit

class MapScrollView: UIScrollView {
    
    // MARK: - @IBOutlets -
    
    @IBOutlet weak var mapImageView: UIImageView!
    
    // MARK: - Properties -
    
    var viewModel: ProofsViewModel! {
        didSet {
            if oldValue == nil {
                UIView.animate(withDuration: 0.65) {
                    self.alpha = 1
                }
            }
            
            if !viewModel.model.isIvpnServer && Application.shared.connectionManager.status.isDisconnected() {
                updateMapPosition(animated: oldValue != nil)
                markerGatewayView.hide(animated: true)
                markerLocalView.show(animated: oldValue != nil)
            }
        }
    }
    
    let markerLocalView = MapMarkerView()
    let markerGatewayView = MapMarkerView()
    
    private lazy var iPadConstraints = bb.left(MapConstants.Container.iPadLandscapeLeftAnchor).top(MapConstants.Container.iPadLandscapeTopAnchor).constraints.deactivate()
    private var markers: [UIButton] = []
    
    // MARK: - View lifecycle -
    
    override func awakeFromNib() {
        setupConstraints()
        setupView()
        initGestures()
        placeServerLocationMarkers()
        placeMarkers()
        updateSelectedMarker()
        addObservers()
    }
    
    deinit {
        removeObservers()
    }
    
    // MARK: - Methods -
    
    func setupConstraints() {
        if UIDevice.current.userInterfaceIdiom == .pad && UIDevice.current.orientation.isLandscape {
            iPadConstraints.activate()
        } else {
            iPadConstraints.deactivate()
        }
    }
    
    func updateMapPosition(animated: Bool = false) {
        guard let viewModel = viewModel else { return }
        
        updateMapPosition(latitude: viewModel.model.latitude, longitude: viewModel.model.longitude, animated: animated, isLocalPosition: true)
    }
    
    func updateMapPosition(latitude: Double, longitude: Double, animated: Bool = false, isLocalPosition: Bool) {
        let halfWidth = Double(UIScreen.main.bounds.width / 2)
        let halfHeight = Double(UIScreen.main.bounds.height / 2)
        let point = getCoordinatesBy(latitude: latitude, longitude: longitude)
        let bottomOffset = Double((MapConstants.Container.getBottomAnchor() / 2) - MapConstants.Container.getTopAnchor())
        let leftOffset = Double((MapConstants.Container.getLeftAnchor()) / 2)
        
        if animated {
            UIView.animate(withDuration: 0.55, delay: 0, options: .curveEaseInOut, animations: {
                self.setContentOffset(CGPoint(x: point.0 - halfWidth + leftOffset, y: point.1 - halfHeight + bottomOffset), animated: false)
            })
        } else {
            setContentOffset(CGPoint(x: point.0 - halfWidth + leftOffset, y: point.1 - halfHeight + bottomOffset), animated: false)
        }
        
        updateMarkerPosition(x: point.0 - 49, y: point.1 - 49, isLocalPosition: isLocalPosition)
    }
    
    // MARK: - Private methods -
    
    private func setupView() {
        isUserInteractionEnabled = true
        isScrollEnabled = true
        backgroundColor = UIColor.init(named: Theme.ivpnGray19)
        mapImageView.backgroundColor = .clear
        mapImageView.tintColor = UIColor.init(named: Theme.ivpnGray20)
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateSelectedMarker), name: Notification.Name.ServerSelected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateSelectedMarker), name: Notification.Name.PingDidComplete, object: nil)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.ServerSelected, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.PingDidComplete, object: nil)
    }
    
    private func initGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }
    
    @objc private func handleTap() {
        NotificationCenter.default.post(name: Notification.Name.HideConnectionInfoPopup, object: nil)
    }
    
    private func placeServerLocationMarkers() {
        for server in Application.shared.serverList.servers {
            placeMarker(latitude: server.latitude, longitude: server.longitude, city: server.city)
        }
    }
    
    private func placeMarkers() {
        markerLocalView.hide()
        markerGatewayView.hide()
        addSubview(markerLocalView)
        addSubview(markerGatewayView)
    }
    
    private func updateMarkerPosition(x: Double, y: Double, isLocalPosition: Bool) {
        if isLocalPosition {
            markerLocalView.snp.updateConstraints { make in
                make.left.equalTo(x)
                make.top.equalTo(y)
            }
            
            UIView.animate(withDuration: 0.15) {
                self.layoutIfNeeded()
            }
        } else {
            markerGatewayView.snp.updateConstraints { make in
                make.left.equalTo(x)
                make.top.equalTo(y)
            }
            
            UIView.animate(withDuration: 0.15) {
                self.layoutIfNeeded()
            }
        }
    }
    
    private func placeMarker(latitude: Double, longitude: Double, city: String) {
        guard city != "Bratislava" else { return }
        guard city != "New Jersey, NJ" else { return }
        
        let point = getCoordinatesBy(latitude: latitude, longitude: longitude)
        
        let button = UIButton(frame: CGRect(x: point.0 - 50, y: point.1 - 21, width: 100, height: 20))
        button.setTitle(city, for: .normal)
        button.setTitleColor(UIColor.init(named: Theme.ivpnGray21), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 10, weight: .regular)
        button.addTarget(self, action: #selector(selectServer), for: .touchUpInside)
        
        let marker = UIView(frame: CGRect(x: 50 - 3, y: 18, width: 6, height: 6))
        marker.layer.cornerRadius = 3
        marker.backgroundColor = UIColor.init(named: Theme.ivpnGray21)
        marker.tag = 1
        
        button.addSubview(marker)
        addSubview(button)
        
        markers.append(button)
    }
    
    @objc private func updateSelectedMarker() {
        Application.shared.connectionManager.needsUpdateSelectedServer()
        
        let city = Application.shared.settings.selectedServer.city
        
        for marker in markers {
            if let circle = marker.viewWithTag(1) {
                if marker.titleLabel?.text == city {
                    circle.layer.cornerRadius = 5
                    circle.snp.remakeConstraints { make in
                        make.size.equalTo(10)
                        make.left.equalTo(45)
                        make.top.equalTo(16)
                    }
                } else {
                    circle.layer.cornerRadius = 3
                    circle.snp.remakeConstraints { make in
                        make.size.equalTo(6)
                        make.left.equalTo(47)
                        make.top.equalTo(18)
                    }
                }
            }
        }
        
        if !Application.shared.connectionManager.status.isDisconnected() {
            Application.shared.connectionManager.reconnect()
        }
    }
    
    @objc private func selectServer(_ sender: UIButton) {
        let city = sender.titleLabel?.text ?? ""
        
        if let server = Application.shared.serverList.getServer(byCity: city) {
            Application.shared.settings.selectedServer = server
            updateSelectedMarker()
            NotificationCenter.default.post(name: Notification.Name.ServerSelected, object: nil)
        }
    }
    
    private func getCoordinatesBy(latitude: Double, longitude: Double) -> (Double, Double) {
        let bitmapWidth: Double = 3909
        let bitmapHeight: Double = 2942
        
        var y: Double
        var blackMagicCoef: Double
        
        // Using this coefficients to compensate for the curvature of the map
        let xMapCoefficient = 0.026
        let yMapCoefficient = 0.965
        
        // Logic to convert longitude, latitude into x, y
        var x: Double = (longitude + 180.0) * (bitmapWidth / 360.0)
        let latRadius: Double = latitude * Double.pi / 180
        blackMagicCoef = log(tan((Double.pi / 4) + (latRadius / 2)))
        y = (bitmapHeight / 2) - (bitmapWidth * blackMagicCoef / (2 * Double.pi))
        
        // Trying to compensate for the curvature of the map
        x -= bitmapWidth * xMapCoefficient
        if y < bitmapHeight / 2 {
            y *= yMapCoefficient
        }
        
        return (x, y)
    }
    
}
