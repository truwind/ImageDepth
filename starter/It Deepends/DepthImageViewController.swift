/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import AVFoundation
import UIKit

class DepthImageViewController: UIViewController {
  
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var imageModeControl: UISegmentedControl!
  @IBOutlet weak var filterControl: UISegmentedControl!
  @IBOutlet weak var depthSlider: UISlider!
  @IBOutlet weak var filterControlView: UIView!
  
  var origImage: UIImage?
  var depthDataMapImage: UIImage?
  
  var filterImage: CIImage?
  
  var bundledJPGs = [String]()
  var current = 0
  
  let context = CIContext()
  
  var depthFilters: DepthImageFilters?

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    
    depthFilters = DepthImageFilters(context: context)

    // Figure out which images are bundled in the app
    bundledJPGs = getAvailableImages()
    
    // Load current image
    loadCurrent(image: bundledJPGs[current], withExtension: "jpg")
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

// MARK: Depth Data Methods

extension DepthImageViewController {
  
}

// MARK: Helper Methods

extension DepthImageViewController {
  
  func getAvailableImages() -> [String] {
    
    var availableImages = [String]()
    
    var base = "test"
    var name = "\(base)00"
    
    var num = 0 {
      didSet {
        name = "\(base)\(String(format: "%02d", num))"
      }
    }
    
    while Bundle.main.url(forResource: name, withExtension: "jpg") != nil {
      availableImages.append(name)
      num += 1
    }
    
    return availableImages
  }
  
  func loadCurrent(image name: String, withExtension ext: String) {
#if true
  // swift type
    // 1 You create a DepthReader entity using the current image.
    let depthReader = DepthReader(name: name, ext: ext)
    // 2 Using your new depthDataMap method, you read the depth data into a CVPixelBuffer.
    let depthDataMap = depthReader.depthDataMap()
#else
    // Bridging Swift Types to Objective-C
    /*
    * DepthReaderObj * depthReader = [DepthReaderObj alloc] initWithName:name ext:ext];
    */
 
    let depthReader = DepthReaderObj(name: name, ext: ext)
    let depthDataMap = depthReader.depthDataMap()
#endif
    
    // 3 You then normalize the depth data using a provided extension to CVPixelBuffer.
    // This makes sure all the pixels are between 0.0 and 1.0, where 0.0 are the furthest pixels
    // and 1.0 are the nearest pixels.
    depthDataMap?.normalize()
    
    // 4 You then convert the depth data to a CIImage and then a UIImage and save it to a property.
    let ciImage = CIImage(cvPixelBuffer: depthDataMap)
    depthDataMapImage = UIImage(ciImage: ciImage)
    
    // Create the original unmodified image
    origImage = UIImage(named: "\(name).\(ext)")
    filterImage = CIImage(image: origImage)

    // Set the segmented control to point to the original image
    imageModeControl.selectedSegmentIndex = ImageMode.original.rawValue
    
    // Update the image view
    updateImageView()
  }
  
  func updateImageView() {
    
    depthSlider.isHidden = true
    filterControlView.isHidden = true
    
    imageView.image = nil
    
    let selectedImageMode = ImageMode(rawValue: imageModeControl.selectedSegmentIndex) ?? .original
    
    switch selectedImageMode {
      
    case .original:
      // Original
      imageView.image = origImage
      
    case .depth:
      // Depth
      #if IOS_SIMULATOR
        guard let orientation = origImage?.imageOrientation,
          let ciImage = depthDataMapImage?.ciImage,
          let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        imageView.image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
      #else
        imageView.image = depthDataMapImage
      #endif
      
    case .mask:
      // Mask
      depthSlider.isHidden = false

      guard let depthImage = depthDataMapImage?.ciImage else {
        return
      }

      let maxToDim = max((origImage?.size.width ?? 1.0), (origImage?.size.height ?? 1.0))
      let maxFromDim = max((depthDataMapImage?.size.width ?? 1.0), (depthDataMapImage?.size.height ?? 1.0))
      
      let scale = maxToDim / maxFromDim
      
      guard let mask = depthFilters?.createMask(for: depthImage, withFocus: CGFloat(depthSlider.value), andScale: scale) else {
        return
      }
      
      #if IOS_SIMULATOR
        guard let cgImage = context.createCGImage(mask, from: mask.extent),
          let origImage = origImage else {
            return
        }
        
        imageView.image = UIImage(cgImage: cgImage, scale: 1.0, orientation: origImage.imageOrientation)
      #else
        imageView.image = UIImage(ciImage: mask)
      #endif
      
    case .filtered:
      // Filtered
      depthSlider.isHidden = false
      filterControlView.isHidden = false

      guard let depthImage = depthDataMapImage?.ciImage else {
        return
      }
      
      let maxToDim = max((origImage?.size.width ?? 1.0), (origImage?.size.height ?? 1.0))
      let maxFromDim = max((depthDataMapImage?.size.width ?? 1.0), (depthDataMapImage?.size.height ?? 1.0))
      
      let scale = maxToDim / maxFromDim

      guard let mask = depthFilters?.createMask(for: depthImage, withFocus: CGFloat(depthSlider.value), andScale: scale),
        let filterImage = filterImage,
        let orientation = origImage?.imageOrientation else {
          return
      }
      
      let finalImage: UIImage?
      
      let selectedFilter = FilterType(rawValue: filterControl.selectedSegmentIndex) ?? .spotlight
      
      switch selectedFilter {
      case .spotlight:
        finalImage = depthFilters?.spotlightHighlight(image: filterImage, mask: mask, orientation: orientation)
      case .color:
        finalImage = depthFilters?.colorHighlight(image: filterImage, mask: mask, orientation: orientation)
      case .blur:
        finalImage = depthFilters?.blur(image: filterImage, mask: mask, orientation: orientation)
      }
      
      imageView.image = finalImage
    }
  }
}

// MARK: Slider Methods

extension DepthImageViewController {
  
  @IBAction func sliderValueChanged(_ sender: UISlider) {
    updateImageView()
  }
}

// MARK: Segmented Control Methods

extension DepthImageViewController {
  
  @IBAction func segementedControlValueChanged(_ sender: UISegmentedControl) {
    updateImageView()
  }
  
  @IBAction func filterTypeChanged(_ sender: UISegmentedControl) {
    updateImageView()
  }
}

// MARK: Gesture Recognizor Methods

extension DepthImageViewController {
  
  @IBAction func imageTapped(_ sender: UITapGestureRecognizer) {
    current = (current + 1) % bundledJPGs.count
    loadCurrent(image: bundledJPGs[current], withExtension: "jpg")
  }
}