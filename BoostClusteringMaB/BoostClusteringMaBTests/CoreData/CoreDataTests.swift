//
//  CoreDataTests.swift
//  BoostClusteringMaBTests
//
//  Created by 현기엽 on 2020/11/23.
//

import XCTest
import CoreData
@testable import BoostClusteringMaB

class CoreDataTests: XCTestCase {
    let newPlace = Place(id: "123321",
                         name: "Mab",
                         x: "124.323412",
                         y: "35.55532",
                         imageURL: nil,
                         category: "부스트캠프")

    class AddressAPIMock: AddressAPIService {
        func address(lat: Double, lng: Double, completion: ((Result<Data, Error>) -> Void)?) {
            completion?(.success(.init()))
        }
    }

    class JSONParserMock: JsonParserService {
        func parse(fileName: String, completion handler: @escaping (Result<[Place], Error>) -> Void) {
            handler(.success([]))
        }

        func parse(address: Data) -> String? {
            return ""
        }
    }

    func testAddPOI() throws {
        // Given
        let layer = CoreDataLayer()
        layer.addressAPI = AddressAPIMock()
        layer.jsonParser = JSONParserMock()

        timeout(10) { expectation in
            // When
            layer.add(place: newPlace) { _ in
                let poi = layer.fetch()?.first
                // Then
                XCTAssertEqual(poi?.id, "123321")
                XCTAssertEqual(poi?.category, "부스트캠프")
                XCTAssertEqual(poi?.imageURL, nil)
                XCTAssertEqual(poi?.name, "Mab")
                XCTAssertEqual(poi?.latitude, 35.55532)
                XCTAssertEqual(poi?.longitude, 124.323412)
                expectation.fulfill()
            }
        }
    }
    
    func test_add_잘못된좌표를입력_invalidCoordinate() throws {
        // Given
        let layer = CoreDataLayer()
        let wrongCoordinatePlace = Place(id: "아이디",
                                         name: "이름",
                                         x: "경도",
                                         y: "위도",
                                         imageURL: nil,
                                         category: "카테고리")
        
        timeout(1) { expectation in
            // When
            layer.add(place: wrongCoordinatePlace) { result in
                // Then
                XCTAssertNil(try? result.get())
                expectation.fulfill()
            }
        }
    }
    
    func testFetchPOI() throws {
        // Given
        let layer = CoreDataLayer()
        
        // When
        let pois = layer.fetch()
        
        // Then
        XCTAssertNotNil(pois)
    }
    
    func testFetchPOIBetweenY30_45X120_135_All() throws {
        // Given
        let layer = CoreDataLayer()
        
        // When
        let pois = layer.fetch(southWest: LatLng(lat: 30, lng: 120),
                               northEast: LatLng(lat: 45, lng: 135))
        let all = layer.fetch()
        let poisCount = pois?.count
        let allCount = all?.count
        
        // Then
        XCTAssertEqual(poisCount, allCount)
        XCTAssertNotNil(poisCount)
    }
    
    func testFetchPOIBetweenY30_45X135_145_Empty() throws {
        // Given
        let layer = CoreDataLayer()
        
        // When
        let pois = layer.fetch(southWest: LatLng(lat: 30, lng: 135), northEast: LatLng(lat: 45, lng: 145))
        
        // Then
        guard let bool = pois?.isEmpty else {
            XCTFail("Try failure")
            return
        }
        XCTAssertTrue(bool)
    }
    
    func testFetchPOIBetweenY45_30X120_135_invalidCoordinate() throws {
        // Given
        let layer = CoreDataLayer()
        
        // When
        let pois = layer.fetch(southWest: LatLng(lat: 45, lng: 120), northEast: LatLng(lat: 30, lng: 135))
        
        // Then
        XCTAssertNil(pois)
    }
    
    func test_CoreDataManager_fetchByClassification() {
        // Given
        let layer = CoreDataLayer()
        
        // When
        guard let pois = layer.fetch(by: "부스트캠프") else {
            XCTFail("test_CoreDataManager_fetchByClassification")
            return
        }
        
        // Then
        XCTAssertTrue( pois.allSatisfy({ poi -> Bool in poi.category == "부스트캠프" }) )
    }
    
//    func testAdd10000POI() throws {
//        timeout(40) { expectation in
//            // Given
//            let numberOfRepeats = 10000
//            let layer = CoreDataLayer()
//            let places = (0..<numberOfRepeats).map { _ in newPlace }
//            let beforeCount = layer.fetch()?.count
//
//            // When
//            layer.add(places: places) { _ in
//                let afterCount = layer.fetch()?.count
//
//                // Then
//                XCTAssertNotNil(beforeCount)
//                XCTAssertEqual(beforeCount! + numberOfRepeats, afterCount)
//                expectation.fulfill()
//            }
//        }
//    }
    
    func testRemove() throws {
        // Given
        let layer = CoreDataLayer()
        layer.addressAPI = AddressAPIMock()
        layer.jsonParser = JSONParserMock()
        
        timeout(20) { expectation in
            layer.add(place: newPlace) { _ in
                let pois = layer.fetch()
                guard let poi = pois?.first(where: { poi -> Bool in
                    poi.id == self.newPlace.id
                }),
                let beforeCount = pois?.count else {
                    XCTFail("data add fail")
                    return
                }

                // When
                layer.remove(poi: poi) { _ in }

                // Then
                let afterCount = layer.fetch()?.count
                XCTAssertEqual(beforeCount - 1, afterCount)
                expectation.fulfill()
            }
        }
    }
    
    func testRemoveAll() throws {
        // Given
        let layer = CoreDataLayer()
        
        // When
        timeout(1) { expectation in
            layer.removeAll { _ in
                // Then
                guard let pois = layer.fetch() else {
                    XCTFail("testRemoveAll")
                    return
                }
                XCTAssertTrue(pois.isEmpty)
                expectation.fulfill()
            }
            
        }
    }
}
