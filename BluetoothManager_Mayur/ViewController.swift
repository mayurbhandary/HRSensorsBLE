//
//  ViewController.swift
//  BluetoothManager_Mayur
//
//  Created by Mayur Bhandary on 6/5/19.
//  Copyright © 2019 Mayur Bhandary. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController,CBCentralManagerDelegate,CBPeripheralDelegate {

    // MARK: - Core Bluetooth service IDs
    //let BLE_Heart_Rate_Service_CBUUID = CBUUID(string: "0x180D")
    
    let BLE_Heart_Rate_Service_CBUUID = CBUUID(string: "61353090-8231-49cc-b57a-886370740041")
    // MARK: - Core Bluetooth characteristic IDs
    let BLE_Heart_Rate_Measurement_Characteristic_CBUUID = CBUUID(string: "0x2A37")
    let BLE_Body_Sensor_Location_Characteristic_CBUUID = CBUUID(string: "0x2A38")

    var centralManager: CBCentralManager?
    var peripheralHeartRateMonitor: CBPeripheral?
    
    @IBOutlet weak var connectingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var heartRateLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Create a DispatchQueue to instantiate a CBCentralManager Object. This allows us to search for Bluetooth devices in the on a separate thread
        let centralQueue: DispatchQueue = DispatchQueue(label: "tools.sunyata.zendo", attributes: .concurrent)
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
        heartRateLabel.alpha=0.0
    }

    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            
            case .unknown:
                print("Bluetooth status is UNKNOWN")
            
            case .resetting:
                print("Bluetooth status is RESETTING")
            
            case .unsupported:
                print("Bluetooth status is UNSUPPORTED")
            
            case .unauthorized:
                print("Bluetooth status is UNAUTHORIZED")
            
            case .poweredOff:
                print("Bluetooth status is POWERED OFF")
            
            case .poweredOn:
                print("Bluetooth status is POWERED ON")
                
                DispatchQueue.main.async { () -> Void in
                    self.connectingIndicator.startAnimating()
                }
                
                
                centralManager?.scanForPeripherals(withServices: [BLE_Heart_Rate_Service_CBUUID])
        }
    }
    
    //Called when a peripheral device is discovered
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        peripheralHeartRateMonitor = peripheral
        //View Controller adopts the CBPeripheralDelegate Protocol so self is the delegate of the peripheral heart rate monitor
        peripheralHeartRateMonitor?.delegate = self
        //Stop scanning to save battery
        centralManager?.stopScan()
        //Attempt to connect the central to the peripheral
        centralManager?.connect(peripheralHeartRateMonitor!)
    }
    
    //Called when the central device successfully connects to a peripheral device
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        DispatchQueue.main.async { () -> Void in
            self.connectingIndicator.stopAnimating()
            self.connectingIndicator.alpha=0.0
            self.heartRateLabel.alpha=1.1
        }
        //Search for the heart rate service
        peripheralHeartRateMonitor?.discoverServices([BLE_Heart_Rate_Service_CBUUID])
        
    }
    //Called when the peripheral device disconnects from the central device
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        DispatchQueue.main.async { () -> Void in
            self.heartRateLabel.alpha=0.0
            self.connectingIndicator.alpha=1.0
            self.connectingIndicator.startAnimating()
            
            
        }
        
        //Try to reconnect
        centralManager?.scanForPeripherals(withServices: [BLE_Heart_Rate_Service_CBUUID])
        
    }
    //Called when the heart rate service is found
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            
            if service.uuid == BLE_Heart_Rate_Service_CBUUID {
                //Find the characteristics within the heart rate service
                peripheral.discoverCharacteristics(nil, for: service)
                
            }
            
        }
    }
    // Called when the characteristics are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        for characteristic in service.characteristics! {
            if characteristic.uuid == BLE_Heart_Rate_Measurement_Characteristic_CBUUID {
                //Tells the peripheral device that we want to subscribe to the heart rate measurement characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    //Called when the heart rate characteristic is updated.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if characteristic.uuid == BLE_Heart_Rate_Measurement_Characteristic_CBUUID {
            
            // STEP 13: we generally have to decode BLE
            // data into human readable format
            let heartRate = deriveBeatsPerMinute(using: characteristic)
            
            DispatchQueue.main.async { () -> Void in
                self.heartRateLabel.text=String(heartRate)
                
            } // END DispatchQueue.main.async...
            
        } // END if characteristic.uuid ==...
    } // END func peripheral(... didUpdateValueFor characteristic
    
    func deriveBeatsPerMinute(using heartRateMeasurementCharacteristic: CBCharacteristic) -> Int {
        
        let heartRateValue = heartRateMeasurementCharacteristic.value!
        // convert to an array of unsigned 8-bit integers
        let buffer = [UInt8](heartRateValue)
        
        // UInt8: "An 8-bit unsigned integer value type."
        
        // the first byte (8 bits) in the buffer is flags
        // (meta data governing the rest of the packet);
        // if the least significant bit (LSB) is 0,
        // the heart rate (bpm) is UInt8, if LSB is 1, BPM is UInt16
        if ((buffer[0] & 0x01) == 0) {
            // second byte: "Heart Rate Value Format is set to UINT8."
            print("BPM is UInt8")
            // write heart rate to HKHealthStore
            // healthKitInterface.writeHeartRateData(heartRate: Int(buffer[1]))
            return Int(buffer[1])
        } else { // I've never seen this use case, so I'll
            // leave it to theoroticians to argue
            // 2nd and 3rd bytes: "Heart Rate Value Format is set to UINT16."
            print("BPM is UInt16")
            return -1
        }
        
    } // END func deriveBeatsPerMinute
}
