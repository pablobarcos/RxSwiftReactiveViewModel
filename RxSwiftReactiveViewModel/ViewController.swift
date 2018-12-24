//
//  ViewController.swift
//  RxSwiftReactiveViewModel
//
//  Created by Pablo Barcos on 24/12/2018.
//  Copyright © 2018 Pablo Barcos. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import SnapKit
import MapKit
import Overture

struct Station {
    var name: String
    var docks: String
    var location: CLLocation
}

struct Api {
    var closestStations: (CLLocation) -> Observable<[Station]> = { location in
        let station1 = Station(name: "Station 1", docks: "5", location: CLLocation.cibeles)
        let station2 = Station(name: "Station 2", docks: "6", location: CLLocation.cibeles)
        let station3 = Station(name: "Station 3", docks: "7", location: CLLocation.plazaMayor)
        let result = Observable<[Station]>.create { (observer) -> Disposable in
            observer.onNext([station1, station2, station3])
            observer.onCompleted()
            return Disposables.create()
        }.delay(5.0, scheduler: MainScheduler.instance)
        
        return result
    }
}

struct LocationManager {
    var location: Observable<CLLocation> = {
        Observable<CLLocation>.create { (observer) -> Disposable in
            observer.onNext(CLLocation(latitude: 40.416691, longitude: -3.703264))
            observer.onCompleted()
            return Disposables.create()
    }
    }()
}

struct Enviroment {
    var api = Api()
    var date: () -> Date = { Date() }
    var locationManager = LocationManager()
}

private let updatedDateFormatter = with(
    DateFormatter(),
    concat(
        mut(\DateFormatter.dateFormat, "h:mm:ss a"),
        mut(\DateFormatter.locale, Locale.current)
    )
)

extension CLLocation {
    static let madrid = CLLocation(latitude: 40.416691, longitude: -3.703264)
    static let plazaMayor = CLLocation(latitude: 40.415665, longitude: -3.707187)
    static let cibeles = CLLocation(latitude: 40.419264, longitude: -3.692928)
}

let env = Enviroment()

class ViewController: UIViewController, MKMapViewDelegate {

    private let disposeBag = DisposeBag()
    
    private lazy var mapView: MKMapView = {
        let view = MKMapView()
        view.showsUserLocation = true
        let regionRadius: CLLocationDistance = 1000
        let coordinateRegion = MKCoordinateRegion(center: CLLocation.madrid.coordinate,
                                                  latitudinalMeters: regionRadius * 1.0, longitudinalMeters: regionRadius * 1.0)
        view.setRegion(coordinateRegion, animated: true)
        view.delegate = self
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        title = "Dock Finder"
        view.backgroundColor = .white
        
        let titleLabel = with(
            UILabel(),
            concat(
                mut(\.textColor, UIColor.darkGray),
                mut(\.font, UIFont.boldSystemFont(ofSize: 22))
            )
        )
        
        let subtitleLabel = with(
            UILabel(),
            concat(
                mut(\.textColor, UIColor.gray),
                mut(\.font, UIFont.systemFont(ofSize: 18))
            )
        )
        
        let dockCountLabel = with(
            UILabel(),
            concat(
                mut(\.textColor, UIColor.white),
                mut(\.font, UIFont.boldSystemFont(ofSize: 32))
            )
        )
        
        let dockCountContainerView = with(
            UIView(),
            mut(\.layer.cornerRadius, 8)
        )
        
        let titleStack = with(
            UIStackView(arrangedSubviews: [titleLabel, subtitleLabel]),
            concat(
                mut(\UIStackView.axis, .vertical),
                mut(\UIStackView.spacing, 6)
            )
        )
        
        let dockLabel = with(
            UILabel(),
            concat(
                mut(\.text, "DOCKS"),
                mut(\.textColor, UIColor.white),
                mut(\.font, UIFont.boldSystemFont(ofSize: 12))
            )
        )
        
        let dockLabelStack = with(
            UIStackView(arrangedSubviews: [dockCountLabel, dockLabel]),
            concat(
                mut(\UIStackView.axis, .vertical),
                mut(\UIStackView.spacing, 2),
                mut(\UIStackView.alignment, .center)
            )
        )
        
        let refreshButton = UIButton(type: .roundedRect)
        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.contentEdgeInsets = .init(top: 10, left: 20, bottom: 10, right: 20)
        refreshButton.layer.borderColor = UIColor.gray.cgColor
        refreshButton.layer.borderWidth = 1
        
        let updatedLabel = with(
            UILabel(),
            concat(
                mut(\.textColor, UIColor.gray),
                mut(\.font, UIFont.boldSystemFont(ofSize: 16))
            )
        )
        
        dockCountContainerView.backgroundColor = UIColor.red
        dockCountContainerView.addSubview(dockLabelStack)
        
        let contentStack = with(
            UIStackView(arrangedSubviews: [titleStack, dockCountContainerView]),
            concat(
                mut(\UIStackView.axis, .horizontal),
                mut(\UIStackView.spacing, 15),
                mut(\UIStackView.distribution, .equalSpacing),
                mut(\UIStackView.alignment, .center)
            )
        )
        
        view.addSubview(contentStack)
        view.addSubview(mapView)
        view.addSubview(refreshButton)
        view.addSubview(updatedLabel)
        
        dockLabelStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets.init(top: 10, left: 8, bottom: 10, right: 8))
        }
        
        contentStack.snp.makeConstraints { make in
            make.top.equalTo(topLayoutGuide.snp.bottom).offset(80)
            make.leading.trailing.equalToSuperview().inset(40)
        }
        
        refreshButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(contentStack.snp.bottom).offset(40)
        }
        
        updatedLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(refreshButton.snp.bottom).offset(40)
        }
        
        mapView.snp.makeConstraints { make in
            make.top.equalTo(updatedLabel.snp.bottom).offset(60)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        let (
        stationNameLabelText,
            stationDistanceLabelText,
                dockCountLabelText,
                    mapViewCenteredLocation,
                        lastUpdatedLabelText
                            ) = talkDockViewModel(
                                reloadButtonTapped: refreshButton
                                    .rx
                                    .controlEvent(.touchUpInside)
                                    .asObservable(),
                                viewDidLoad: .just(())
        )
        
        stationNameLabelText
            .bind(to: titleLabel.rx.text)
            .disposed(by: disposeBag)

        stationDistanceLabelText
            .bind(to: subtitleLabel.rx.text)
            .disposed(by: disposeBag)

        dockCountLabelText
            .bind(to: dockCountLabel.rx.text)
            .disposed(by: disposeBag)

        mapViewCenteredLocation
            .bind { [weak self] location in
                self?.mapView.setCenter(location?.coordinate ?? CLLocation.plazaMayor.coordinate, animated: true)
            }
            .disposed(by: disposeBag)

        lastUpdatedLabelText
            .bind(to: updatedLabel.rx.text)
            .disposed(by: disposeBag)
    }
    


}


func talkDockViewModel(
    reloadButtonTapped: Observable<Void>,
    viewDidLoad: Observable<Void>
    ) -> (
    stationNameLabelText: Observable<String?>,
    stationDistanceLabelText: Observable<String>,
    dockCountLabelText: Observable<String?>,
    mapViewCenteredLocation: Observable<CLLocation?>,
    lastUpdatedLabelText: Observable<String>
    ) {
        
        let currentLocation = viewDidLoad
            .flatMapLatest { env.locationManager.location }
        
        let nearbyStations = viewDidLoad
            .flatMapLatest { currentLocation }
            .flatMapLatest { env.api.closestStations($0) }
            .share()
        
        let closestStation = nearbyStations
            .map { $0.first }
        
        let stationNameLabelText = closestStation
            .map { $0?.name }
            .startWith("Locating..")
        
        let stationDistanceLabelText = closestStation
            .withLatestFrom(currentLocation) { station,
                location in
                "\(Int(station?.location.distance(from: location) ?? 0))m away"
                }
            .startWith("??")
        
        let dockCountLabelText = closestStation
            .map { $0?.docks }
            .startWith("-")
        
        let mapViewCenteredLocation = closestStation
            .map { $0?.location }
            .startWith(CLLocation.madrid)
        
        
        let lastUpdatedLabelText = closestStation
            .map { _ in  "Last update: \(updatedDateFormatter.string(from:  env.date()))" }
            .startWith("Last update: Never")
        
        return (
            stationNameLabelText: stationNameLabelText,
            stationDistanceLabelText: stationDistanceLabelText,
            dockCountLabelText: dockCountLabelText,
            mapViewCenteredLocation: mapViewCenteredLocation,
            lastUpdatedLabelText: lastUpdatedLabelText
        )
}


