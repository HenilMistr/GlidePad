import Cocoa
import CoreBluetooth
import Carbon.HIToolbox

class TrackPadDaemon: NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    var peripheralManager: CBPeripheralManager!
    var centralManager: CBCentralManager!
    var connectedCentral: CBCentral?
    let serviceUUID = CBUUID(string: "A5F20000-DEAD-BEEF-ABCD-0123456789AB")
    let characteristicUUID = CBUUID(string: "A5F20001-DEAD-BEEF-ABCD-0123456789AB")

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            let service = CBMutableService(type: serviceUUID, primary: true)
            let characteristic = CBMutableCharacteristic(
                type: characteristicUUID,
                properties: [.read, .notify, .write],
                value: nil,
                permissions: [.readable, .writeable]
            )
            service.characteristics = [characteristic]
            peripheralManager.add(service)
            peripheralManager.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
                CBAdvertisementDataLocalNameKey: "TrackPadHost_Mac"
            ])
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        for request in requests {
            if request.characteristic.uuid == characteristicUUID {
                if let data = request.value, let str = String(data: data, encoding: .utf8) {
                    handleCommand(json: str)
                }
                peripheral.respond(to: request, withResult: .success)
            }
        }
    }

    func sendProfileToPhone() {
        let profile: [String: Any] = [
            "os": "macos",
            "naturalScroll": getMacSetting(key: "com.apple.swipescrolldirection", defaultBool: true),
            "tapToClick": getMacSetting(key: "com.apple.driver.AppleBluetoothMultitouch.trackpad", subkey: "Clicking", defaultBool: false),
            "hasPrecisionTouchpad": true
        ]

        let json = ["profile": profile]
        if let data = try? JSONSerialization.data(withJSONObject: json) {
            peripheralManager.updateValue(data, for: /* your char */, onSubscribedCentrals: [connectedCentral!])
        }
    }

    func getMacSetting(key: String, subkey: String? = nil, defaultBool: Bool) -> Bool {
        let defaults = UserDefaults.standard
        if let subkey = subkey {
            if let dict = defaults.dictionary(forKey: key) {
                return dict[subkey] as? Bool ?? defaultBool
            }
        } else {
            return defaults.bool(forKey: key)
        }
        return defaultBool
    }

    func handleCommand(json: String) {
        do {
            if let dict = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as? [String: Any] {
                switch dict["cmd"] as? String {
                case "move":
                    if let dx = dict["dx"] as? Int, let dy = dict["dy"] as? Int {
                        moveCursor(dx: dx, dy: dy)
                    }
                case "tap":
                    click()
                case "scroll":
                    if let dy = dict["dy"] as? Int {
                        scroll(dy: dy)
                    }
                case "request_profile":
                    sendProfileToPhone()
                default: break
                }
            }
        } catch {
            print("JSON Error: KATEX_INLINE_OPENerror)")
        }
    }

    func moveCursor(dx: Int, dy: Int) {
        let currentPos = CGEvent(source: nil)?.location
        let newPos = CGPoint(x: currentPos!.x + CGFloat(dx), y: currentPos!.y - CGFloat(dy))
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, 
                                mouseCursorPosition: newPos, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
    }

    func click() {
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, 
                           mouseCursorPosition: CGEvent(source: nil)!.location, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, 
                         mouseCursorPosition: CGEvent(source: nil)!.location, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    func scroll(dy: Int) {
        let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, 
                                  wheel1: Int32(-dy), wheel2: 0, wheel3: 0)
        scrollEvent?.post(tap: .cghidEventTap)
    }
}

// In AppDelegate.swift — launch at login, show menu bar icon