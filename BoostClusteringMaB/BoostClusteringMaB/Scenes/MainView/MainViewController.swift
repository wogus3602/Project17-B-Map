//
//  ViewController.swift
//  BoostClusteringMaB
//
//  Created by ParkJaeHyun on 2020/11/16.
//

import UIKit
import NMapsMap
import CoreData

protocol NMFMapViewProtocol {
    var coveringBounds: NMGLatLngBounds { get }
    var projection: NMFProjection { get }
}

extension NMFMapView: NMFMapViewProtocol { }

protocol MainDisplayLogic: class {
    func displayFetch(viewModel: ViewModel)
}

final class MainViewController: UIViewController {
    lazy var naverMapView = NMFNaverMapView(frame: view.frame)
    lazy var markerAnimationController: MarkerAnimateController = {
        let controller = MarkerAnimateController(frame: view.frame, markerRadius: 30, mapView: mapView)
        guard let animationView = controller.view else { return controller }
        naverMapView.addSubview(animationView)
        return controller
    }()
    //lazy var startPoint = NMGLatLng(lat: 37.50378338836959, lng: 127.05559154398587) // 강남
    lazy var startPoint = NMGLatLng(lat: 37.56295485320913, lng: 126.99235958053829) // 을지로

    var displayedData: ViewModel = .init(markers: [], polygons: [], bounds: [], count: 0)
    var interactor: MainBusinessLogic?
    var mapView: NMFMapView { naverMapView.mapView }
    var projection: NMFProjection { naverMapView.mapView.projection }
    var fetchedResultsController: NSFetchedResultsController<ManagedPOI>?
    
    @IBOutlet var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureVIP()
        configureMapView()
        setDetailView()
        initializeFetchedResultsController()
    }

    func initializeFetchedResultsController() {
        
        let coreDataLayer = CoreDataLayer()
        
        fetchedResultsController = coreDataLayer.makeFetchResultsController(
            southWest: LatLng(lat: 30, lng: 120),
            northEast: LatLng(lat: 45, lng: 135)
        )
        
        fetchedResultsController?.delegate = self
        
        do {
            try fetchedResultsController?.performFetch()
            //            collectionView.reloadData()
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
        
    }

    func setDetailView() {
        view.bringSubviewToFront(collectionView)
        collectionView.backgroundColor = UIColor.clear.withAlphaComponent(0)
    }

    // MARK: - configure VIP
    private func configureVIP() {
        let interactor = MainInteractor()
        let presenter = MainPresenter()
        self.interactor = interactor
        interactor.presenter = presenter
        interactor.clustering?.tool = self
        interactor.clustering?.data = presenter
        presenter.viewController = self
    }
    
    private func configureMapView() {
        naverMapView.showZoomControls = true
        mapView.addCameraDelegate(delegate: self)
        mapView.moveCamera(.init(scrollTo: startPoint))
        
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(makeMarker(_:)))
        naverMapView.addGestureRecognizer(gestureRecognizer)
        view.addSubview(naverMapView)
    }
    
    @objc func makeMarker(_ sender: UILongPressGestureRecognizer) {
        let point = sender.location(in: view)
        let latlng = point.convert(mapView: mapView)
        
        var nowZoomLevel = mapView.zoomLevel
        let stdZoomLevel = NMF_MAX_ZOOM - 2
        if  nowZoomLevel < stdZoomLevel {
            nowZoomLevel = stdZoomLevel
        }
        
        let cameraUpdate = NMFCameraUpdate(scrollTo: latlng, zoomTo: nowZoomLevel)
        cameraUpdate.animation = .easeIn
        cameraUpdate.animationDuration = 0.8
        
        showAlert(latlng: latlng, cameraUpdate: cameraUpdate)
        
        sender.state = .ended
    }
    
    private func showAlert(latlng: NMGLatLng, cameraUpdate: NMFCameraUpdate) {
        let alert = UIAlertController(title: "POI를 추가하시겠습니까?",
                                      message: "OK를 누르면 추가합니다",
                                      preferredStyle: UIAlertController.Style.alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.mapView.moveCamera(cameraUpdate)
            let marker = NMFMarker()
            marker.position = latlng
            marker.mapView = self.mapView
            //coreData에 저장시켜 주세요
        })
        alert.addAction(cancelAction)
        alert.addAction(okAction)
        present(alert, animated: false, completion: nil)
    }
}

extension MainViewController: MainDisplayLogic {
    func displayFetch(viewModel: ViewModel) {
        let oldViewModel = displayedData
        displayedData = viewModel
        redrawMap(oldViewModel: oldViewModel, newViewModel: viewModel)
        collectionView.reloadData()
    }
    
    private func redrawMap(oldViewModel: ViewModel?, newViewModel: ViewModel) {
        guard let oldViewModel = oldViewModel else {
            self.configureFirstMarkers(newMarkers: newViewModel.markers, bounds: newViewModel.bounds)
            return
        }

        self.setOveraysMapView(overlays: oldViewModel.polygons, mapView: nil)

        self.markerChangeAnimation(
            oldMarkers: oldViewModel.markers,
            newMarkers: newViewModel.markers,
            bounds: newViewModel.bounds,
            completion: {
                self.setOveraysMapView(overlays: newViewModel.polygons, mapView: self.mapView)
            })
    }
}

private extension MainViewController {
    func configureFirstMarkers(newMarkers: [NMFMarker], bounds: [NMGLatLngBounds]) {
        self.setOveraysMapView(overlays: newMarkers, mapView: mapView)
        self.setMarkersBounds(markers: newMarkers, bounds: bounds)
    }
    
    func setOveraysMapView(overlays: [NMFOverlay], mapView: NMFMapView?) {
        return overlays.forEach { $0.mapView = mapView }
    }
    
    func setMarkersBounds(markers: [NMFMarker], bounds: [NMGLatLngBounds]) {
        zip(markers, bounds).forEach { marker, bound in
            marker.touchHandler = { _ in
                self.touchedMarker(bounds: bound, insets: 0)
                return true
            }
        }
    }
    
    func touchedMarker(bounds: NMGLatLngBounds, insets: CGFloat) {
        let edgeInsets = UIEdgeInsets(top: insets, left: insets, bottom: insets, right: insets)
        let cameraUpdate = NMFCameraUpdate(fit: bounds, paddingInsets: edgeInsets)
        cameraUpdate.animation = .easeIn
        cameraUpdate.animationDuration = 0.8
        mapView.moveCamera(cameraUpdate)
    }
    
    func markerChangeAnimation(oldMarkers: [NMFMarker],
                               newMarkers: [NMFMarker],
                               bounds: [NMGLatLngBounds],
                               completion: (() -> Void)?) {
        self.setOveraysMapView(overlays: oldMarkers, mapView: nil)

        self.markerAnimationController.clusteringAnimation(
            old: oldMarkers.map { $0.position },
            new: newMarkers.map { $0.position },
            isMerge: oldMarkers.count > newMarkers.count,
            completion: {
                self.setOveraysMapView(overlays: newMarkers, mapView: self.mapView)
                self.setMarkersBounds(markers: newMarkers, bounds: bounds)
                completion?()
            })
    }
}

extension MainViewController: NMFMapViewCameraDelegate {
    func mapViewCameraIdle(_ mapView: NMFMapView) {
        let boundsLatLngs = mapView.coveringBounds.boundsLatLngs
        let southWest = LatLng(boundsLatLngs[0])
        let northEast = LatLng(boundsLatLngs[1])
        interactor?.fetchPOI(southWest: southWest, northEast: northEast)
    }
}

extension MainViewController: ClusteringTool {
    func convertLatLngToPoint(latLng: LatLng) -> CGPoint {
        return projection.point(from: NMGLatLng(lat: latLng.lat, lng: latLng.lng))
    }
}

extension MainViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange sectionInfo: NSFetchedResultsSectionInfo,
                    atSectionIndex sectionIndex: Int,
                    for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            collectionView.insertSections(IndexSet(integer: sectionIndex))
        case .delete:
            collectionView.deleteSections(IndexSet(integer: sectionIndex))
        case .move:
            break
        case .update:
            break
        @unknown default:
            fatalError()
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            collectionView.insertItems(at: [newIndexPath!])
        case .delete:
            collectionView.deleteItems(at: [indexPath!])
        case .update:
            collectionView.reloadItems(at: [indexPath!])
        case .move:
            collectionView.moveItem(at: indexPath!, to: newIndexPath!)
        @unknown default:
            fatalError()
        }
    }

}

extension MainViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: self.view.bounds.width - 20, height: 110)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let fetchedResultsController = fetchedResultsController,
              let sections = fetchedResultsController.sections
        else { return 0 }
        
        return sections[section].numberOfObjects
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell",
                                                            for: indexPath)
                as? DetailCollectionViewCell,
              let object = fetchedResultsController?.object(at: indexPath)
        else {
            return UICollectionViewCell()
        }
        cell.configure(poi: object)
        cell.layer.borderWidth = 1
        cell.layer.cornerRadius = 10

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                           withReuseIdentifier: "header",
                                                                           for: indexPath)
                as? DetailCollectionReusableView
        else { return UICollectionReusableView() }
        header.poiNumberLabel.text = "\(displayedData.count)개"
        return header
    }
}
