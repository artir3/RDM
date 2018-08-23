//
//  ViewController.swift
//  RDM-2
//
//  Created by гык-sse2 on 21/08/2018.
//  Copyright © 2018 гык-sse2. All rights reserved.
//

import Cocoa

@objc class Resolution : NSObject {
	@objc var width : UInt32
	@objc var height : UInt32
	@objc var hiDPI : Bool
	
	init(width : UInt32, height : UInt32, hiDPI : Bool) {
		self.width = width
		self.height = height
		self.hiDPI = hiDPI
		super.init()
	}
}

@objc class ViewController: NSViewController {
	@IBOutlet var arrayController: NSArrayController!
	@IBOutlet weak var displayName: NSTextField!
	
	@objc var displayProductName : String {
		get {
			return displayName.stringValue
		}
		set(value) {
			displayName.stringValue = value
		}
	}
	
	var fileName : String {
		get {
			return String(format:"\(dir)/DisplayProductID-%x", productID)
		}
	}
	
	var dir : String {
		get {
			return String(format:"/System/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-%x", vendorID)
		}
	}

	var plist = NSMutableDictionary()
	var resolutions : [Resolution] = []
	@objc var vendorID : UInt32 = 0
	@objc var productID : UInt32 = 0
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		plist = NSMutableDictionary.init(contentsOf: URL.init(fileURLWithPath: fileName)) ?? NSMutableDictionary()
		
		resolutions = [Resolution]()
		
		if let a = plist["scale-resolutions"] {
			if let b = a as? NSArray {
				let c = b as Array
				resolutions = c.map { (data : AnyObject) -> Resolution in
					if let d = data as? NSData {
						let e = swapUInt32Data(data: d as Data)
						let count = e.count / MemoryLayout<UInt32>.size
						var array = [UInt32](repeating: 0, count: count)
						(e as NSData).getBytes(&array, length: count * MemoryLayout<UInt32>.size)
						return Resolution(width: array[0], height: array[1], hiDPI: array.count >= 4 && array[2] != 0 && array[3] != 0)
					}
					return Resolution(width: 0, height: 0, hiDPI: false)
				}
			}
		}
		
		if let a = plist[kDisplayProductName] as? String {
			displayProductName = a
		}
		
		DispatchQueue.main.async {
			self.arrayController.content = self.resolutions
		}
	}
	
	func swapUInt32Data(data : Data) -> Data {
		var mdata = data // make a mutable copy
		let count = data.count / MemoryLayout<UInt32>.size
		mdata.withUnsafeMutableBytes { (i32ptr: UnsafeMutablePointer<UInt32>) in
			for i in 0..<count {
				i32ptr[i] = i32ptr[i].byteSwapped
			}
		}
		return mdata
	}
	
	@IBAction func add(_ sender: Any) {
		resolutions.append(Resolution(width: 0, height: 0, hiDPI: false))
		arrayController.content = resolutions
		arrayController.rearrangeObjects()
	}
	
	@IBAction func remove(_ sender: Any) {
		if arrayController.selectionIndex >= 0 {
			resolutions.remove(at: arrayController.selectionIndex)
			arrayController.content = resolutions
			arrayController.rearrangeObjects()
		}
	}
	
	@IBAction func save(_ sender: Any) {
		let resArray = resolutions.map { (r : Resolution) -> NSData in
			var d = Data()
			d.append(UnsafeBufferPointer(start: &r.width, count: 1))
			d.append(UnsafeBufferPointer(start: &r.height, count: 1))
			if r.hiDPI {
				var hiDPIFlag = [0x1, 0x200000]
				d.append(UnsafeBufferPointer(start: &hiDPIFlag, count: 1))
			}
			return swapUInt32Data(data: d) as NSData
		} as NSArray
		
		plist.setValue(NSNumber.init(value: vendorID), forKey: kDisplayVendorID)
		plist.setValue(NSNumber.init(value: productID), forKey: kDisplayProductID)
		plist.setValue(displayProductName as NSString, forKey: kDisplayProductName)
		plist.setValue(resArray, forKey: "scale-resolutions")
		let tmpFile = NSTemporaryDirectory() + "tmp"
		plist.write(toFile: tmpFile, atomically: false)

		let myAppleScript = "do shell script \"mkdir -p \(dir) && cp \(tmpFile) \(fileName)\" with administrator privileges"
		
		var error: NSDictionary?
		if let scriptObject = NSAppleScript(source: myAppleScript) {
			scriptObject.executeAndReturnError(
				&error)
			if let e = error {
				print("error: \(e)")
			}
		}
		try? FileManager.default.removeItem(atPath: tmpFile)
		view.window!.close()
	}
	
	override var representedObject: Any? {
		didSet {
		// Update the view, if already loaded.
		}
	}


}

